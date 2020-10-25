`timescale 1ps/1ps

`default_nettype none
module Ulx3s_Top (
  input         clk_25mhz,       // h/w clock

  output        wifi_en,         // enable ESP32
  output        wifi_gpio0,      // quiet ESP32

  input   [6:0] btn,             // user buttons
  output  [7:0] led,             // user leds

  output        ftdi_rxd,        // Oberon TX
  input         ftdi_txd,        // Oberon RX

  inout         sd_clk,          // SD_CK
  inout         sd_cmd,          // SD_DI
  inout   [3:0] sd_d,            // [0] = SD_DO, [3] = SD_nCS

  output        usb_fpga_pu_dp,  // US2 PS/2 pull-ups
  output        usb_fpga_pu_dn,
  inout         usb_fpga_dp,     // US2 PS/2 clk+dat
  inout         usb_fpga_dn,

  inout  [27:0] gp,              // GPIO Header pins
  inout  [27:0] gn,
  
  output        sdram_clk,       // SDRAM
  output        sdram_cke,
  output        sdram_csn, 
  output        sdram_rasn,
  output        sdram_casn,
  output        sdram_wen,
  output [12:0] sdram_a,
  output  [1:0] sdram_ba,
  output  [1:0] sdram_dqm,
  inout  [15:0] sdram_d,
  
  output  [3:0] gpdi_dp         // DVID Video
);

  wire clk = clk_25mhz;

  // ULX3S specific things
  //
  assign wifi_gpio0     = btn[0];   // disable ESP32 monitor
  assign wifi_en        = 1'b0;     // disable ESP32
  assign usb_fpga_pu_dp = 1'b1; 	  // US1 D+ pull to +3.3V through 1.5K resistor
  assign usb_fpga_pu_dn = 1'b1; 	  // US1 D- pull as above
  assign gp[22]         = 1'b1;     // US3 D+ pull as above
  assign gn[22]         = 1'b1;     // US3 D- pull as above
  assign sd_d[2:1]      = 2'bzz;    // force inout to input

`ifdef __ICARUS__
  reg sdrclk = 0;
  always #4000 sdrclk = !sdrclk;
  reg pixclk = 0;
  always #1538 pixclk = !pixclk;
  reg pix5clk = 0;
  always #308 pix5clk = !pix5clk;
`else
  wire sdrclk, pixclk, pix5clk;
  /*
  PLL pll(
    .clkin(clk_25mhz),
    .pll125(sdrclk),
    .pll65(pixclk),
    .pll325(pix5clk)
  );
  */
  parameter pixel_clock_MHz = 65; // 65 for 12F, 75 for 85F
  wire [3:0] clocks_sdram, clocks_video;
  ecp5pll
  #(
      .in_hz(               25*1000000),
    .out0_hz(              125*1000000)
  )
  ecp5pll_sdram_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks_sdram)
  );

  ecp5pll
  #(
      .in_hz(               25*1000000),
    .out0_hz(  pixel_clock_MHz*1000000),
    .out1_hz(5*pixel_clock_MHz*1000000)
  )
  ecp5pll_video_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks_video)
  );
  assign sdrclk  = clocks_sdram[0];
  assign pixclk  = clocks_video[0];
  assign pix5clk = clocks_video[1];
`endif

  // System timer (@ I/O addr 0) and reset
  //
  wire        limit = (cnt0 == 24999);
  reg         rst = 0;
  reg  [15:0] cnt0 = 0;
  reg  [31:0] cnt1 = 0; // milliseconds

  always @(posedge clk) begin
    cnt0 <= limit ? 0 : cnt0 + 1;
    cnt1 <= cnt1 + limit;
    //rst     <= ((cnt1[4:0] == 0) & limit) ? ~(btns[3]) : rst;
    rst  <= (cnt0 > 100) | rst;
  end

  // CPU
  //
  wire [23:0] adr;
  wire [31:0] inbus, inbus0;  // data to RISC core
  wire [31:0] outbus;         // data from RISC core
  wire        rd, wr, ben, mrdy;

  RISC5 cpu (
    .clk(clk),
    .rst(rst),
    .stallX(~mrdy),
    .adr(adr),
    .codebus(inbus0),
    .inbus(inbus),
    .outbus(outbus),
    .rd(rd),
    .wr(wr),
    .ben(ben)
  );

  // LEDs @ I/O addr 1
  // 1 r/w = buttons+switches / LEDs
  //
  reg   [7:0] Lreg;
  wire  [3:0] btns = { ~btn[0], btn[3], btn[5], btn[4] };
  wire  [7:0] swi = 8'b0000_0000;
  
  always @(posedge clk) begin
    if (wr & ioenb & (iowadr == 1)) Lreg <= outbus[7:0];
    if (wr & ioenb & (iowadr == 1)) $display("leds=%h", outbus);
    if (~rst)                       Lreg <= 0;
  end
  
  assign led = Lreg;
  
  // Serial @ I/O addr 2, 3
  // 2 r/w = RS-232 data   / RS-232 data (start)
  // 3 r/w = RS-232 status / RS-232 control

  //
  wire  [7:0] dataRx;
  wire  [7:0] dataTx   = outbus[7:0];
  wire        startTx  = wr & ioenb & (iowadr == 2);
  wire        doneRx   = rd & ioenb & (iowadr == 2);
  wire        rdyRx, rdyTx;
  reg         bitrate;

  always @(posedge clk) begin
    if (wr & ioenb & (iowadr == 3)) bitrate <= outbus[0];
    if (~rst)                       bitrate <= 0;
  end

  RS232R receiver (
    .clk(clk),
    .rst(rst),
    .RxD(ftdi_txd),
    .fsel(bitrate),
    .done(doneRx),
    .data(dataRx),
    .rdy(rdyRx)
  );
  RS232T transmitter (
    .clk(clk),
    .rst(rst),
    .start(startTx),
    .fsel(bitrate),
    .data(dataTx),
    .TxD(ftdi_rxd),
    .rdy(rdyTx)
  );

  // SDCard @ I/O addr 4,5
  // 4 r/w = SPI data / SPI data (start)
  // 5 r/w = SPI status / SPI control
  //
  wire [31:0] spiRx;
  wire        spiRdy;
  reg   [3:0] spiCtrl;
  wire        spiStart = wr & ioenb & (iowadr == 4);

  assign sd_d[3]  = ~spiCtrl[0];

  always @(posedge clk) begin
    if (wr & ioenb & (iowadr == 5)) spiCtrl <= outbus[3:0];
    if (~rst)                       spiCtrl <= 0;
    //if (spiStart) $display("SD<-%h", outbus);
  end

  SPI spi(
    .clk(clk),
    .rst(rst),
    .start(spiStart),
    .dataTx(outbus),
    .fast(spiCtrl[2]),
    .dataRx(spiRx),
    .rdy(spiRdy),
    .SCLK(sd_clk),
    .MOSI(sd_cmd),
    .MISO(sd_d[0])
  );

  // Keyboard / Mouse interface @ I/O addr 6,7
  // 6 r/w = PS2 keyboard / --
  // 7 r/w = mouse / --
  //
  wire  [7:0] dataKbd;
  wire        rdyKbd;
  wire        doneKbd  = rd & ioenb & (iowadr == 7);

  PS2 kbd(
    .clk(clk),
    .rst(rst),
    .done(doneKbd),
    .rdy(rdyKbd),
    .shift(),
    .data(dataKbd),
    .PS2C(usb_fpga_dp),
    .PS2D(usb_fpga_dn)
  );

  wire [27:0] dataMs;
  wire  [2:0] mousebtn;

  MouseM #(.c_x_bits(10), .c_y_bits(10), .c_y_neg(1), .c_z_ena(0), .c_hotplug(1)) Mse (
    .clk(clk),
    .clk_ena(1'b1),
    .ps2m_reset(~rst),
    .ps2m_clk(gp[21]),      // = CLK for U3 (on PMOD)
    .ps2m_dat(gn[21]),      // = DAT for U3 (on PMOD)
    .x(dataMs[9:0]),
    .y(dataMs[21:12]),
    .btn(mousebtn)
  );
  assign dataMs[24] = mousebtn[1]; // left
  assign dataMs[25] = mousebtn[2]; // middle
  assign dataMs[26] = mousebtn[0]; // right
  assign dataMs[27] = 1'b1;

  // GP I/O @ I/O addr 8,9
  // 8 r/w = general-purpose I/O data
  // 9 r/w = general-purpose I/O tri-state control
  //
  reg   [7:0] gpout, gpoc;
  wire  [7:0] gpin;
  
  always @(posedge clk)
  begin
    if (wr & ioenb & (iowadr == 8)) gpout <= outbus[7:0];
    if (wr & ioenb & (iowadr == 9)) gpoc  <= outbus[7:0];
    if (~rst)                       gpoc  <= 0;
  end

  assign gp[9:2] = gpoc ? gpout : 8'hzz;
  assign gpin = gp[9:2];

  // IO addresses for input / output
  // 0  milliseconds / --
  // 1  switches / LEDs
  // 2  RS-232 data / RS-232 data (start)
  // 3  RS-232 status / RS-232 control
  // 4  SPI data / SPI data (start)
  // 5  SPI status / SPI control
  // 6  PS2 keyboard / --
  // 7  mouse / --
  // 8  general-purpose I/O data
  // 9  general-purpose I/O tri-state control

  // Databus CPU input mux
  //
  wire [3:0] iowadr = adr[5:2];
  wire       ioenb  = (adr[23:6] == 18'h3FFFF);

  assign inbus = ~ioenb ? inbus0 :
                          ((iowadr == 0) ? cnt1 :
                           (iowadr == 1) ? {20'b0, btns, swi} :
                           (iowadr == 2) ? {24'b0, dataRx} :
                           (iowadr == 3) ? {30'b0, rdyTx, rdyRx} :
                           (iowadr == 4) ? spiRx :
                           (iowadr == 5) ? {31'b0, spiRdy} :
                           (iowadr == 6) ? { 3'b0, rdyKbd, dataMs} :
                           (iowadr == 7) ? {24'b0, dataKbd} :
                           (iowadr == 8) ? {24'b0, gpin} :
                           (iowadr == 9) ? {24'b0, gpoc} :
                           0);

  // CACHE + SDRAM
  //
  wire [15:0] sdr_din, sdr_dout;
  wire [11:0] sdr_addr;
  wire sdr_get, sdr_put, sdr_rd, sdr_wr;
  
  // generate byte write mask (all 4 for regular writes)
  wire [3:0] wmask = ({4{!ben}} | (1'b1 << adr[1:0])) & {4{wr}};
  
  wire memsel = !ioenb & !(&adr[23:14]); // &(rd|wr)
  
`ifdef __ICARUS__
  wire [31:0] test;

  RAM ram (
    .CLK(~clk),
    .ADDR(adr[19:2]),
    .DI(outbus),
    .DO(test),
    .nWE(~wmask),
    .nCS(!memsel)
  );

  always @(posedge clk) begin
    if (memsel && rd && mrdy && test!=inbus0) begin
      $display("memory bug!");
      $writememh("sdram.txt", sdram.mem);
      $writememh("cram.txt",  tut.cache.cram.mem);
      $finish;
    end
  end
`endif  

  CACHE cache (
    .clk(clk),            // CPU side
    .addr(adr[19:0]),
    .din(outbus),
    .dout(inbus0),
    .wmask(wmask),
    .mreq(memsel),
    .mrdy(mrdy),
  
    .sdr_clk(sdrclk),      // SDRAM controller side
    .sdr_addr(sdr_addr),
    .sdr_din(sdr_din),
    .sdr_dout(sdr_dout),
    .sdr_rd(sdr_rd),
    .sdr_wr(sdr_wr),
    .sdr_get(sdr_get),
    .sdr_put(sdr_put)
  );
  
  SDRAM controller (
    .clk_in(sdrclk),      // cache side
    .rst(~rst),
    .ad(sdr_addr),
    .dout(sdr_din),
    .din(sdr_dout),
    .rd(sdr_rd),
    .wr(sdr_wr),
    .get(sdr_get),
    .put(sdr_put),
    
    .sd_data(sdram_d),    // SDRAM chip side
    .sd_addr(sdram_a),
    .sd_dqm(sdram_dqm),
    .sd_ba(sdram_ba),
    .sd_cs(sdram_csn),
    .sd_we(sdram_wen),
    .sd_ras(sdram_rasn),
    .sd_cas(sdram_casn),
    .sd_cke(sdram_cke),
    .sd_clk(sdram_clk)
  );

  // Video circuit: XGA over DVID
  //
  wire hs, vs, rgb, vde;
  wire [7:0] vid = {8{rgb}};

  VIDEO video (
    .clk(clk),
    .pclk(pixclk),
    .inv(1'b0),
    .cpudata(outbus),
    .cpuadr(adr),
    .wmask(wmask),
    
    .hsync(hs),
    .vsync(vs),
    .rgb(rgb),
    .vde(vde)
  );

  // OSD overlay
  localparam C_display_bits = 64;
  reg [C_display_bits-1:0] OSD_display = 64'hC01DCAFE600DBABE;
  /*
  always @(posedge pixclk)
  begin
    if(vs)
    begin
      OSD_display[63:56] <= led;
      //OSD_display[31:16] <= sdram_a; // refused routing to IFS
      //OSD_display[15:0]  <= sdram_d; // refused routing to IFS
    end
  end
  */

  // OSD HEX signal
  localparam C_HEX_width  = 6*4*(C_display_bits/4);
  localparam C_HEX_height = 8*4;
  localparam C_color_bits = 16;
  wire [9:0] osd_x;
  wire [9:0] osd_y;
  // for reverse screen:
  wire [9:0] osd_rx = C_HEX_width-2-osd_x;
  wire [C_color_bits-1:0] color;
  hex_decoder
  #(
    .c_data_len(C_display_bits),
    .c_row_bits(5), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256 
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_x_bits(8),
    .c_y_bits(4),
    .c_color_bits(C_color_bits)
  )
  hex_decoder_inst
  (
    .clk(pixclk),
    .data(OSD_display),
    .x(osd_rx[9:2]),
    .y(osd_y[5:2]),
    .color(color)
  );
  // rgb565->rgb888
  wire [7:0] osd_r = {color[15:11],{3{color[11]}}};
  wire [7:0] osd_g = {color[10:5],{3{color[5]}}};
  wire [7:0] osd_b = {color[4:0],{3{color[0]}}};

  // mix oberon video and HEX
  wire [7:0] osd_vga_r, osd_vga_g, osd_vga_b;
  wire osd_vga_hsync, osd_vga_vsync, osd_vga_blank;
  osd
  #(
    .C_x_start(96),
    .C_x_stop (96+C_HEX_width+2),
    .C_y_start(96),
    .C_y_stop (96+C_HEX_height-1)
  )
  osd_instance
  (
    .clk_pixel(pixclk),
    .clk_pixel_ena(1'b1),
    .i_r(vid),
    .i_g(vid),
    .i_b(vid),
    .i_hsync(hs),
    .i_vsync(vs),
    .i_blank(~vde),
    .i_osd_en(btn[1]), // hold btn[1] to see HEX OSD
    .o_osd_x(osd_x),
    .o_osd_y(osd_y),
    .i_osd_r(osd_r),
    .i_osd_g(osd_g),
    .i_osd_b(osd_b),
    .o_r(osd_vga_r),
    .o_g(osd_vga_g),
    .o_b(osd_vga_b),
    .o_hsync(osd_vga_hsync),
    .o_vsync(osd_vga_vsync),
    .o_blank(osd_vga_blank)
  );

  DVID tdms (
    .pixclk(pixclk),
    .pixclk_x5(pix5clk),
    
    .red(osd_vga_r), .green(osd_vga_g), .blue(osd_vga_b),
    .vde(~osd_vga_blank), .hSync(osd_vga_hsync), .vSync(osd_vga_vsync),
    //.red(vid), .green(vid), .blue(vid),
    //.vde(vde), .hSync(hs), .vSync(vs),
    
    .gpdi_dp(gpdi_dp)
  );

endmodule
