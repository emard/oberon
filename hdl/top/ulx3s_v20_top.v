`default_nettype none
module ulx3s_v20(
//      -- System clock and reset
	input clk_25mhz, // main clock input from external clock source
	output wifi_en, wifi_gpio0,
	inout wifi_gpio16, wifi_gpio17,

//      -- On-board user buttons and status LEDs
	input [6:0] btn,
	output [7:0] led,

//      -- User GPIO (56 I/O pins) Header
	inout [27:0] gp, gn,  // GPIO Header pins available as one data block

//      -- USB Slave (FT231x) interface 
	output ftdi_rxd,
	input ftdi_txd,
	 
//	-- SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
	output sdram_csn, 
	output sdram_clk,	// clock to SDRAM
	output sdram_cke,	// clock enable to SDRAM	
	output sdram_rasn,      // SDRAM RAS
	output sdram_casn,	// SDRAM CAS
	output sdram_wen,	// SDRAM write-enable
	output [12:0] sdram_a,	// SDRAM address bus
	output [1:0] sdram_ba,	// SDRAM bank-address
	output [1:0] sdram_dqm,
	inout [15:0] sdram_d,	// data bus to/from SDRAM	
	  
//	-- DVI interface
	// output [3:0] gpdi_dp, gpdi_dn,
	output [3:0] gpdi_dp,
	 
//	-- SD/MMC Interface (Support either SPI or nibble-mode)
        inout sd_clk, sd_cmd,
        inout [3:0] sd_d,

//	-- PS2 interface
        output usb_fpga_pu_dp, usb_fpga_pu_dn,
        inout usb_fpga_dp, usb_fpga_dn // enable internal pullups at constraints file
    );
	assign wifi_gpio0 = btn[0];
	// assign wifi_en = 1'b0;

	assign sdram_cke = 1'b1; // -- SDRAM clock enable
	// assign sd_d[2:1] = 2'bzz; // set as inputs with pullups enabled at constraints file

	assign usb_fpga_pu_dp = 1'b1; 	// pull USB D+ to +3.3V through 1.5K resistor
	assign usb_fpga_pu_dn = 1'b1; 	// pull USB D- to +3.3V through 1.5K resistor

        // if picture "rolls" (sync problem), try another pixel clock
	parameter pixel_clock_MHz = 75; // 65 for 12F, 75 for 85F
	wire [3:0] clocks_video;
        ecp5pll
        #(
            .in_hz(               25*1000000),
          .out0_hz(5*pixel_clock_MHz*1000000),
          .out1_hz(  pixel_clock_MHz*1000000)
        )
        ecp5pll_video_inst
        (
          .clk_i(clk_25mhz),
          .clk_o(clocks_video)
        );
        wire clk_pixel, clk_shift;
        assign clk_shift = clocks_video[0]; // 325 or 375 MHz
        assign clk_pixel = clocks_video[1]; //  65 or  75 MHz

	wire [3:0] clocks_system;
	wire pll_locked;
        ecp5pll
        #(
            .in_hz( 25*1000000),
          .out0_hz(100*1000000),
          .out1_hz(100*1000000), .out1_deg(225),
          .out2_hz( 25*1000000)
        )
        ecp5pll_system_inst
        (
          .clk_i(clk_25mhz),
          .clk_o(clocks_system)
        );
	wire clk_cpu, clk_sdram;
	assign clk_sdram = clocks_system[0]; // 100 MHz sdram controller
	assign sdram_clk = clocks_system[1]; // 100 MHz 225 deg SDRAM chip
	assign clk_cpu = clocks_system[2]; // 25 MHz

        wire vga_hsync, vga_vsync, vga_blank;
        wire [1:0] vga_r, vga_g, vga_b;

	RISC5Top sys_inst
	(
		.CLK_CPU(clk_cpu),
		.CLK_SDRAM(clk_sdram),
                .CLK_PIXEL(clk_pixel),
		.BTN_NORTH(btn[3]), // up
		.BTN_SOUTH(btn[4]), // down
		.BTN_WEST(btn[5]), // left
		.BTN_EAST(~btn[0]), // right (power btn, inverted signal)
		.RX(ftdi_txd),   // RS-232
		.TX(ftdi_rxd),
		.LED(led),

		.SD_DO(sd_d[0]),          // SPI - SD card & network
		.SD_DI(sd_cmd),
		.SD_CK(sd_clk),
		.SD_nCS(sd_d[3]),

		.VGA_HSYNC(vga_hsync),
		.VGA_VSYNC(vga_vsync),
		.VGA_BLANK(vga_blank),
		.VGA_R(vga_r),
		.VGA_G(vga_g),
		.VGA_B(vga_b),

		.PS2CLKA(gp[11]),      // ESP32 keyboard clock wifi_gpio26
		.PS2DATA(gn[11]),      // ESP32 keyboard data wifi_gpio25
		//.PS2CLKB(wifi_gpio17), // ESP32 mouse clock
		//.PS2DATB(wifi_gpio16), // ESP32 mouse data

		//.PS2CLKA(gp[21]), // keyboard clock US3, flat cable on pins down
		//.PS2DATA(gn[21]), // keyboard data US3, flat cable on pins down
		.PS2CLKB(usb_fpga_dp), // mouse clock US2
		.PS2DATB(usb_fpga_dn), // mouse data US2

		.gpio(gp[9:2]),

		.SDRAM_nCAS(sdram_casn),
		.SDRAM_nRAS(sdram_rasn),
		.SDRAM_nCS(sdram_csn),
		.SDRAM_nWE(sdram_wen),
		.SDRAM_BA(sdram_ba),
		.SDRAM_ADDR(sdram_a),
		.SDRAM_DATA(sdram_d),
		.SDRAM_DQML(sdram_dqm[0]),
		.SDRAM_DQMH(sdram_dqm[1])
	);
    assign gp[22] = 1'b1; // US3 PULLUP
    assign gn[22] = 1'b1; // US3 PULLUP

/*
    wire [7:0] vga_r8, vga_g8, vga_b8;
    vga
    #(
      .C_resolution_x(1024),
      .C_hsync_front_porch(16),
      .C_hsync_pulse(96),
      .C_hsync_back_porch(44),
      .C_resolution_y(768),
      .C_vsync_front_porch(10),
      .C_vsync_pulse(2),
      .C_vsync_back_porch(31),
      .C_bits_x(11),
      .C_bits_y(11)
    )
    vga_instance
    (
      .clk_pixel(clk_pixel),
      .test_picture(1'b1), // enable test picture generation
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .vga_hsync(vga_hsync),
      .vga_vsync(vga_vsync),
      .vga_blank(vga_blank)
    );
    assign vga_r = vga_r8[7:6];
    assign vga_g = vga_g8[7:6];
    assign vga_b = vga_b8[7:6];
*/

    // OSD overlay
    localparam C_display_bits = 64;
    wire [C_display_bits-1:0] OSD_display = 64'hC01DCAFE600DBABE;

    // oberon video signal from oberon, expanded to 8-bit
    wire [7:0] vga_r8 = {vga_r,{6{vga_r[0]}}};
    wire [7:0] vga_g8 = {vga_g,{6{vga_g[0]}}}; 
    wire [7:0] vga_b8 = {vga_b,{6{vga_b[0]}}};
    
    // OSD HEX signal
    parameter C_color_bits = 16; 
    wire [9:0] osd_x;
    wire [9:0] osd_y;
    // for reverse screen:
    wire [9:0] osd_rx = 2*6/4*C_display_bits-osd_x;
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
      .clk(clk_pixel),
      .data(OSD_display),
      .x(osd_rx[8:1]),
      .y(osd_y[4:1]),
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
      .C_x_start(128),
      .C_x_stop (128+2*6/4*C_display_bits+2),
      .C_y_start(128),
      .C_y_stop (128+2*8-1)
    )
    osd_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .i_r(vga_r8),
      .i_g(vga_g8),
      .i_b(vga_b8),
      .i_hsync(~vga_hsync),
      .i_vsync(vga_vsync),
      .i_blank(vga_blank),
      .i_osd_en(1'b1), // btn[1] can be used here
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

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_ddr(1'b1),
      .C_depth(8)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(osd_vga_r),
      .in_green(osd_vga_g),
      .in_blue(osd_vga_b),
      .in_hsync(osd_vga_hsync),
      .in_vsync(osd_vga_vsync),
      .in_blank(osd_vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0])
    );

    // vendor specific DDR modules
    // convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
    ODDRX1F ddr_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gpdi_dp[3]), .SCLK(clk_shift), .RST(0));
    ODDRX1F ddr_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gpdi_dp[2]), .SCLK(clk_shift), .RST(0));
    ODDRX1F ddr_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gpdi_dp[1]), .SCLK(clk_shift), .RST(0));
    ODDRX1F ddr_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gpdi_dp[0]), .SCLK(clk_shift), .RST(0));

endmodule
