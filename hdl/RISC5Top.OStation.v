/*Project Oberon, Revised Edition 2013

Book copyright (C)2013 Niklaus Wirth and Juerg Gutknecht;
software copyright (C)2013 Niklaus Wirth (NW), Juerg Gutknecht (JG), Paul
Reed (PR/PDR).

Permission to use, copy, modify, and/or distribute this software and its
accompanying documentation (the "Software") for any purpose with or
without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
WITH REGARD TO THE SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY, FITNESS AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES OR LIABILITY WHATSOEVER, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE DEALINGS IN OR USE OR PERFORMANCE OF THE SOFTWARE.*/

// NW 22.9.2015 / OberonStation ver 3.10.15 PDR
// with SRAM, byte access, flt.-pt., and gpio
// PS/2 mouse and network 7.1.2014 PDR
// Modified for SDRAM - Nicolae Dumitrache 2016: +cache (16KB, 4-way 8-set), +SDRAM interface (100Mhz)

module RISC5Top(
	input CLK_CPU, CLK_SDRAM,
	input CLK_PIXEL,
	input BTN_EAST,
	input BTN_NORTH,
	input BTN_WEST,
	input BTN_SOUTH,
	input  RX,   // RS-232
	output TX,
	output [7:0]LED,
	input SD_DO,          // SPI - SD card & network
	output SD_DI,
	output SD_CK,
	output SD_nCS,
	// VGA video
	output VGA_HSYNC, VGA_VSYNC, VGA_BLANK,
	output [1:0] VGA_R, VGA_G, VGA_B,
	input PS2CLKA, PS2DATA, // keyboard
	inout PS2CLKB, PS2DATB,
	inout [7:0]gpio,

	output SDRAM_nCAS,
	output SDRAM_nRAS,
	output SDRAM_nCS,
	output SDRAM_nWE,
	output [1:0]SDRAM_BA,
	output [12:0]SDRAM_ADDR,
	inout [15:0]SDRAM_DATA,
	output SDRAM_DQML,
	output SDRAM_DQMH
  );

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
 
reg rst;
wire clk, clk_sdr;
wire pclk;
wire vga_hsync, vga_vsync;

wire [3:0]btn = {BTN_EAST, BTN_NORTH, BTN_WEST, BTN_SOUTH};
wire [7:0]swi = 8'b11111111;
wire [1:0]MISO = {1'b1, SD_DO};          // SPI - SD card & network
wire [1:0] SCLK, MOSI;
wire [1:0] SS;
wire NEN;  // network enable
wire [5:0]RGB;
wire CE; 
wire empty;
reg qready = 1'b0;
reg rGo = 1'b0; // 1T delay for memory read



assign SD_DI = MOSI[0];
assign SD_CK = SCLK[0];
assign SD_nCS = SS[0];

assign VGA_R = RGB[5:4];
assign VGA_G = RGB[3:2];
assign VGA_B = RGB[1:0];
assign VGA_HSYNC = vga_hsync;
assign VGA_VSYNC = vga_vsync;
assign VGA_BLANK = ~de;
assign pclk = CLK_PIXEL;

wire[23:0] adr;
wire [3:0] iowadr; // word address
wire [31:0] inbus, inbus0;  // data to RISC core
wire [31:0]inbusvid;
wire [31:0] outbus;  // data from RISC core
wire rd, wr, ben, ioenb, dspreq;

wire [7:0] dataTx, dataRx, dataKbd;
wire rdyRx, doneRx, startTx, rdyTx, rdyKbd, doneKbd;
wire [27:0] dataMs;
reg bitrate;  // for RS232
wire limit;  // of cnt0

reg [7:0] Lreg;
reg [15:0] cnt0 = 0;
reg [31:0] cnt1 = 0; // milliseconds

wire [31:0] spiRx;
wire spiStart, spiRdy;
reg [3:0] spiCtrl;
reg [11:0] vidadr = 0;
reg [7:0] gpout, gpoc;
//wire [7:0] gpin;

assign iowadr = adr[5:2];
assign ioenb = (adr[23:6] == 18'h3FFFF);
wire mreq = !ioenb;

RISC5 riscx(.clk(clk), .ce(CE/* & (!mreq | wr | rGo)*/), .rst(rst), .rd(rd), .wr(wr), .ben(ben), .stallX(1'b0),
   .adr(adr), .codebus(inbus0), .inbus(inbus), .outbus(outbus));
RS232R receiver(.clk(clk), .rst(rst), .RxD(RX), .fsel(bitrate), .done(doneRx),
   .data(dataRx), .rdy(rdyRx));
RS232T transmitter(.clk(clk), .rst(rst), .start(startTx), .fsel(bitrate),
   .data(dataTx), .TxD(TX), .rdy(rdyTx));
SPI spi(.clk(clk), .rst(rst), .start(spiStart), .dataTx(outbus),
   .fast(spiCtrl[2]), .dataRx(spiRx), .rdy(spiRdy),
 	.SCLK(SCLK[0]), .MOSI(MOSI[0]), .MISO(MISO[0] & MISO[1]));
VID vid(.clk(clk), .ce(qready), .pclk(pclk), .req(dspreq), .inv(~swi[7]),
   .viddata(inbusvid), .de(de), .RGB(RGB), .hsync(vga_hsync), .vsync(vga_vsync));
PS2 kbd(.clk(clk), .rst(rst), .done(doneKbd), .rdy(rdyKbd), .shift(),
   .data(dataKbd), .PS2C(PS2CLKA), .PS2D(PS2DATA));
// MouseM Ms(.clk(clk), .rst(rst), .msclk(PS2CLKB), .msdat(PS2DATB), .out(dataMs));
mousem
#(.c_x_bits(10), .c_y_bits(10))
Ms
(
.clk(clk), .clk_ena(1'b1), .ps2m_reset(~rst), .ps2m_clk(PS2CLKB), .ps2m_dat(PS2DATB),
.x(dataMs[9:0]), .y(dataMs[21:12]), .btn(dataMs[26:24])
);
assign dataMs[27] = 1'b1;


assign inbus = ~ioenb ? inbus0 :
   ((iowadr == 0) ? cnt1 :
    (iowadr == 1) ? {20'b0, btn, ~swi} :  //btn (AUX) pulldowns, swi (JP) pullups
    (iowadr == 2) ? {24'b0, dataRx} :
    (iowadr == 3) ? {30'b0, rdyTx, rdyRx} :
    (iowadr == 4) ? spiRx :
    (iowadr == 5) ? {31'b0, spiRdy} :
    (iowadr == 6) ? {3'b0, rdyKbd, dataMs} :
    (iowadr == 7) ? {24'b0, dataKbd} :
    (iowadr == 8) ? {24'b0, gpio} :
	 (iowadr == 9) ? {24'b0, gpoc} : 0);

/*
assign SRce0 = ben & adr[1];
assign SRce1 = ben & ~adr[1];
assign SRbe0 = ben & adr[0];
assign SRbe1 = ben & ~adr[0];
assign SRwe0 = ~wr | clk, SRwe1 = SRwe0;
assign SRoe0 = wr, SRoe1 = SRoe0;
assign SRbe = {SRbe1, SRbe0, SRbe1, SRbe0};

genvar i;
generate // tri-state buffer for SRAM
  for (i = 0; i < 32; i = i+1)
  begin: bufblock
    IOBUF SRbuf (.I(outbus[i]), .O(inbus0[i]), .IO(SRdat[i]), .T(~wr));
  end
endgenerate
*/

genvar i;
generate // tri-state buffer for gpio port
  for (i = 0; i < 8; i = i+1)
  begin: gpioblock
//    IOBUF gpiobuf (.I(gpout[i]), .O(gpin[i]), .IO(gpio[i]), .T(~gpoc[i]));
	assign gpio[i] = gpoc[i] ? gpout[i] : 1'bz;
  end
endgenerate


assign dataTx = outbus[7:0];
assign startTx = wr & ioenb & (iowadr == 2);
assign doneRx = rd & ioenb & (iowadr == 2);
assign limit = (cnt0 == 24999);
assign LED = Lreg;
assign spiStart = wr & ioenb & (iowadr == 4);
assign SS = ~spiCtrl[1:0];  //active low slave select
assign MOSI[1] = MOSI[0], SCLK[1] = SCLK[0], NEN = spiCtrl[3];
assign doneKbd = rd & ioenb & (iowadr == 7);

always @(posedge clk) begin
	rst <= ((cnt1[4:0] == 0) & limit) ? ~btn[3] : rst;
	cnt0 <= limit ? 0 : cnt0 + 1;
	cnt1 <= cnt1 + limit;
	if(CE) begin
		Lreg <= ~rst ? 0 : (wr & ioenb & (iowadr == 1)) ? outbus[7:0] : Lreg;
		spiCtrl <= ~rst ? 0 : (wr & ioenb & (iowadr == 5)) ? outbus[3:0] : spiCtrl;
		bitrate <= ~rst ? 0 : (wr & ioenb & (iowadr == 3)) ? outbus[0] : bitrate;
		gpout <= (wr & ioenb & (iowadr == 8)) ? outbus[7:0] : gpout;
		gpoc <= ~rst ? 0 : (wr & ioenb & (iowadr == 9)) ? outbus[7:0] : gpoc;
	end
end


	reg [1:0]cntrl0_user_command_register;
	wire [15:0]cntrl0_user_input_data;
	wire [15:0]sys_DOUT;
	wire sys_rd_data_valid;
	wire sys_wr_data_valid;
	wire [1:0]sys_cmd_ack;
	reg crw = 1'b0;
	wire [12:0]waddr;

	assign clk = CLK_CPU;
	assign clk_sdr = CLK_SDRAM;
	
	
	reg [17:0]sys_addr;
	always @(*)begin
		sys_addr = 18'hxxxxx;
		case(cntrl0_user_command_register)
			2'b01: sys_addr = {waddr[11:0], 6'b000000}; // write 256bytes
			2'b10: sys_addr = {15'h6ff8 + {3'b000, ~vidadr[11:2], vidadr[1:0]}, 3'b000}; // read 32bytes video
			2'b11: sys_addr = {adr[19:8], 6'b000000}; // read 256bytes	
		endcase
	end

	SDRAM_16bit SDR
	(
		.sys_CLK(clk_sdr),				// clock
		.sys_CMD(cntrl0_user_command_register),					// 00=nop, 01 = write 256 bytes, 10=read 32 bytes, 11=read 256 bytes
		.sys_ADDR({5'b00000, sys_addr}),	// word address
		.sys_DIN(cntrl0_user_input_data),		// data input
		.sys_DOUT(sys_DOUT),					// data output
		.sys_rd_data_valid(sys_rd_data_valid),	// data valid read
		.sys_wr_data_valid(sys_wr_data_valid),	// data valid write
		.sys_cmd_ack(sys_cmd_ack),			// command acknowledged
		
		.sdr_n_CS_WE_RAS_CAS({SDRAM_nCS, SDRAM_nWE, SDRAM_nRAS, SDRAM_nCAS}),			// SDRAM #CS, #WE, #RAS, #CAS
		.sdr_BA(SDRAM_BA),					// SDRAM bank address
		.sdr_ADDR(SDRAM_ADDR),				// SDRAM address
		.sdr_DATA(SDRAM_DATA),				// SDRAM data
		.sdr_DQM({SDRAM_DQMH, SDRAM_DQML})					// SDRAM DQM
	);
	
	wire ddr_rd;
	wire ddr_wr;
	reg [1:0]auto_flush = 2'b00;
	cache_controller cache_ctl 
	(
		 .addr({1'b0, adr[19:0]}), 
		 .dout(inbus0), 
		 .din(outbus), 
		 .clk(clk),
		 .mreq(mreq), 
		 .wmask(({4{!ben}} | (1'b1 << adr[1:0])) & {4{wr}}),
		 .ce(CE), 
		 .ddr_din(sys_DOUT), 
		 .ddr_dout(cntrl0_user_input_data), 
		 .ddr_clk(clk_sdr), 
		 .ddr_rd(ddr_rd), 
		 .ddr_wr(ddr_wr),
		 .waddr(waddr),
		 .cache_write_data(crw && sys_rd_data_valid), // read DDR, write to cache
		 .cache_read_data(crw && sys_wr_data_valid),
		 .flush(auto_flush == 2'b01)
	);
	
	reg [15:0]video_din;
	reg vd1 = 1'b0;
	wire almost_empty;
	vqueue vqueue_inst
	(
	  .WrClock(clk_sdr), // input wr_clk
	  .RdClock(clk), // input rd_clk
	  .Data({sys_DOUT, video_din}), // input [31 : 0] din
	  .WrEn(vd1), // input wr_en
	  .RdEn(dspreq), // input rd_en
	  .Q(inbusvid), // output [31 : 0] dout
	  .Full(), // output full
	  .Empty(empty), // output empty
	  .AlmostFull(),
	  .AlmostEmpty(almost_empty), // output prog_empty
	  .Reset(),
	  .RPReset()
	);
	
	reg nop;
	always @(posedge clk_sdr) begin
		nop <= sys_cmd_ack == 2'b00;
		if(almost_empty) cntrl0_user_command_register <= 2'b10;		// read 32 bytes VGA
		else if(ddr_wr) cntrl0_user_command_register <= 2'b01;		// write 256 bytes cache
		else if(ddr_rd) cntrl0_user_command_register <= 2'b11;		// read 256 bytes cache
		else cntrl0_user_command_register <= 2'b00;
		
		if(nop) case(sys_cmd_ack)
			2'b10: begin
				crw <= 1'b0;	// VGA read
				if(vidadr == 12'd3071) vidadr <= 12'd0;
				else vidadr <= vidadr + 1'b1;
			end
			2'b01, 2'b11: crw <= 1'b1;	// cache read/write			
		endcase
		
		if(!crw && sys_rd_data_valid) begin
			vd1 <= !vd1;
			video_din <= sys_DOUT;
		end
	end
	
	always @(posedge clk) begin
		auto_flush <= {auto_flush[0], vga_vsync};
		qready <= !empty;
/*		if(CE)  // 1T delay for memory read
			if(rGo) rGo <= 1'b0;
			else rGo <= mreq & !wr;*/
	end

endmodule
