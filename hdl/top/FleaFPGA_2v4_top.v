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

	wire [2:0] clocks_video;
	clk_25_325_65_25
	clk_25_325_65_25_inst
	(
	  .clkin(sys_clock),
	  .clkout(clocks_video)
	);
        wire clk_pixel, clk_shift;
        assign clk_pixel = clocks_video[1]; //  65 MHz
        assign clk_shift = clocks_video[0]; // 325 MHz

	wire [2:0] clocks_system;
	clk_25_100_100p_25
	clk_25_100_100p_25_inst
	(
	  .clkin(sys_clock),
	  .clkout(clocks_system)
	);
	wire clk_cpu, clk_sdram;
	assign clk_sdram = clocks_system[0]; // 100 MHz sdram controller
	assign Dram_Clk = clocks_system[1]; // 100 MHz 225 deg sdram chip
	assign clk_cpu = clocks_system[2]; // 25 MHz

	assign Dram_CKE = 1'b1; 	// -- DRAM clock enable
	assign PS2_enable1 = 1'b1; 	// pull both USB ports D+ and D- to +3.3vcc through 15K resistors
	wire [3:0]LED;
	wire [3:0]exled;
	assign n_led1 = LED[0];

        wire vga_hsync, vga_vsync, vga_blank;
        wire [1:0] vga_r, vga_g, vga_b;

	RISC5Top sys_inst
	(
		.CLK_CPU(clk_cpu),
		.CLK_SDRAM(clk_sdram),
                .CLK_PIXEL(clk_pixel),
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

		.VGA_HSYNC(vga_hsync),
		.VGA_VSYNC(vga_vsync),
		.VGA_BLANK(vga_blank),
		.VGA_R(vga_r),
		.VGA_G(vga_g),
		.VGA_B(vga_b),

		.PS2CLKA(PS2_clk1), 
		.PS2DATA(PS2_data1), // keyboard
		.PS2CLKB(PS2_clk2), 
		.PS2DATB(PS2_data2),
		.gpio(GPIO[9:2]),

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
 

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_ddr(1'b1),
      .C_depth(2)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(vga_r),
      .in_green(vga_g),
      .in_blue(vga_b),
      .in_hsync(vga_hsync),
      .in_vsync(vga_vsync),
      .in_blank(vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0])
    );

    wire [3:0] gpdi_dp, gpdi_dn;
    // output TMDS SDR/DDR data to fake differential lanes
    fake_differential
    #(
      .C_ddr(1'b1)
    )
    fake_differential_instance
    (
      .clk_shift(clk_shift),
      .in_clock(tmds[3]),
      .in_red(tmds[2]),
      .in_green(tmds[1]),
      .in_blue(tmds[0]),
      .out_p(gpdi_dp),
      .out_n(gpdi_dn)
    );
    assign LVDS_ck = gpdi_dp[3];
    assign LVDS_Red = gpdi_dp[2];
    assign LVDS_Green = gpdi_dp[1];
    assign LVDS_Blue = gpdi_dp[0];

endmodule
