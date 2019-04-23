module FleaFPGA_2v4(
//    -- System clock and reset
	input sys_clock, // main clock input from external clock source
	input sys_reset, // main clock input from external RC reset circuit

//    -- On-board user buttons and status LEDs
	output n_led1,

//    -- User GPIO (18 I/O pins) Header
	inout [27:2]GPIO,  // GPIO Header pins available as one data block
	inout GPIO_IDSD,
	inout GPIO_IDSC,
	
	output [3:0]AD_EOUT,
	input [3:0]AD_FB,

//    -- USB Slave (FT230x) interface 
	output slave_tx_o,
	input slave_rx_i,
	 
//	-- SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
	output Dram_Clk,	// clock to SDRAM
	output Dram_CKE,	// clock to SDRAM	
	output Dram_n_Ras,  // SDRAM RAS
	output Dram_n_Cas,	// SDRAM CAS
	output Dram_n_We,	// SDRAM write-enable
	output [1:0]Dram_BA,	// SDRAM bank-address
	output [12:0]Dram_Addr,	// SDRAM address bus
	inout [15:0]Dram_Data,	// data bus to/from SDRAM	
	output Dram_n_cs, 
	output Dram_DQMH,
	output Dram_DQML,
	  
//	-- DVI interface
	output [0:0]LVDS_Red,
	output [0:0]LVDS_Green,
	output [0:0]LVDS_Blue,
	output [0:0]LVDS_ck,
	
	 
//	-- SD/MMC Interface (Support either SPI or nibble-mode)
	input mmc_dat1,
	input mmc_dat2,
	output mmc_n_cs,
	output mmc_clk,
	output mmc_mosi,
	input mmc_miso,

//	-- PS2 interface (Both ports accessible via Y-splitter cable)
	output PS2_enable1,
	inout PS2_clk1,
	inout PS2_data1,
	inout PS2_clk2,
	inout PS2_data2 
    );
	
	assign Dram_CKE = 1'b1; 	// -- DRAM clock enable
	assign PS2_enable1 = 1'b1; 	// pull both USB ports D+ and D- to +3.3vcc through 15K resistors
	wire [3:0]LED;
	wire [3:0]exled;
	assign n_led1 = LED[0];
	
	
	RISC5Top sys_inst
	(
		.CLK_25MHZ(sys_clock),
		.BTN_EAST(!sys_reset),
		.BTN_NORTH(1'b0),
		.BTN_WEST(1'b0),
		.BTN_SOUTH(1'b0),
		.RX(slave_rx_i),   // RS-232
		.TX(slave_tx_o),
		.LED({exled, LED}),
		.SD_DO(mmc_miso),          // SPI - SD card & network
		.SD_DI(mmc_mosi),
		.SD_CK(mmc_clk),
		.SD_nCS(mmc_n_cs),
		//.VGA_HSYNC(vga_hs), 
		//.VGA_VSYNC(vga_vs), // video controller
		//.VGA_R(vga_red),
		//.VGA_G(vga_green),
		//.VGA_B(vga_blue),
		
		.TMDS({LVDS_ck, LVDS_Red, LVDS_Green, LVDS_Blue}),
		
		.PS2CLKA(PS2_clk1), 
		.PS2DATA(PS2_data1), // keyboard
		.PS2CLKB(PS2_clk2), 
		.PS2DATB(PS2_data2),
		.gpio(GPIO[9:2]),

		.SDRAM_CLK(Dram_Clk),
		.SDRAM_nCAS(Dram_n_Cas),
		.SDRAM_nRAS(Dram_n_Ras),
		.SDRAM_nCS(Dram_n_cs),
		.SDRAM_nWE(Dram_n_We),
		.SDRAM_BA(Dram_BA),
		.SDRAM_ADDR(Dram_Addr),
		.SDRAM_DATA(Dram_Data),
		.SDRAM_DQML(Dram_DQML),
		.SDRAM_DQMH(Dram_DQMH)
	);
 
endmodule
