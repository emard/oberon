module ulx3s_v20(
//      -- System clock and reset
	input clk_25mhz, // main clock input from external clock source

//      -- On-board user buttons and status LEDs
	input [6:0] btn,
	output [7:0] led,

//      -- User GPIO (18 I/O pins) Header
	inout [27:0] gp, gn,  // GPIO Header pins available as one data block

//      -- USB Slave (FT231x) interface 
	output ftdi_rxd,
	input ftdi_txd,
	 
//	-- SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
	output sdram_clk,	// clock to SDRAM
	output sdram_cke,	// clock enable to SDRAM	
	output sdram_rasn,      // SDRAM RAS
	output sdram_casn,	// SDRAM CAS
	output sdram_wen,	// SDRAM write-enable
	output [1:0]sdram_ba,	// SDRAM bank-address
	output [12:0]sdram_a,	// SDRAM address bus
	inout [15:0]sdram_d,	// data bus to/from SDRAM	
	output sdram_csn, 
	output [1:0] sdram_dqm,
	  
//	-- DVI interface
	// output [3:0] gpdi_dp, gpdi_dn,
	output [3:0] gpdi_dp,
	 
//	-- SD/MMC Interface (Support either SPI or nibble-mode)
        output sd_clk, sd_cmd,
        inout [3:0] sd_d,

//	-- PS2 interface (Both ports accessible via Y-splitter cable)
        // output usb_fpga_pu_dp, usb_fpga_pu_dn,
        inout usb_fpga_dp, usb_fpga_dn // enable internal pullups at constraints file
    );
	
	assign sdram_cke = 1'b1; 	// -- DRAM clock enable
	//assign usb_fpga_pu_dp = 1'b1; 	// pull USB D+ to +3.3vcc through 1.5K resistor
	//assign usb_fpga_pu_dn = 1'b1; 	// pull USB D- to +3.3vcc through 1.5K resistor
	assign sd_d[3] = 1'bz; // set as input
	
	wire [3:0] tmds;
        
	RISC5Top sys_inst
	(
		.CLK_25MHZ(clk_25mhz),
		.BTN_EAST(!btn[6]),
		.BTN_NORTH(btn[3]),
		.BTN_WEST(btn[5]),
		.BTN_SOUTH(btn[4]),
		.RX(ftdi_txd),   // RS-232
		.TX(ftdi_rxd),
		.LED(led),

		.SD_DO(sd_d[0]),          // SPI - SD card & network
		.SD_DI(sd_cmd),
		.SD_CK(sd_clk),
		.SD_nCS(sd_d[3]),

		//.VGA_HSYNC(vga_hs),
		//.VGA_VSYNC(vga_vs), // video controller
		//.VGA_R(vga_red),
		//.VGA_G(vga_green),
		//.VGA_B(vga_blue),
		.TMDS(tmds), // {LVDS_ck, LVDS_Red, LVDS_Green, LVDS_Blue}

		.PS2CLKA(usb_fpga_dp), // keyboard clock
		.PS2DATA(usb_fpga_dn), // keyboard data
		.PS2CLKB(gn[0]), // mouse clock
		.PS2DATB(gn[1]), // mouse data

		.gpio(gp[9:2]),

		.SDRAM_CLK(sdram_clk),
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

    // fake differential
    assign gpdi_dp = tmds;
    //assign gpdi_dn = ~tmds;

endmodule
