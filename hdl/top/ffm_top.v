// FFM LFE5 Top level for MINIMIG
module ffm_top
(
    input  clk_100mhz_p,  // core should use only positive when in differential mode
    output [3:0] vid_d_p, // core should use only positive when in differential mode
    // RS232
    output uart3_txd,
    input  uart3_rxd,
    // FFM Module IO
    inout  [7:0]   fioa,
    inout  [31:20] fiob,
    // SD card (SPI)
    output sd_m_clk, sd_m_cmd,
    inout  [3:0] sd_m_d, 
    input  sd_m_cdet,
    //  SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output dr_cs_n,       // chip select
    output dr_clk,        // clock to SDRAM
    output dr_cke,        // clock enable to SDRAM
    output dr_ras_n,      // SDRAM RAS
    output dr_cas_n,      // SDRAM CAS
    output dr_we_n,       // SDRAM write-enable
    output [12:0] dr_a,   // SDRAM address bus
    output [1:0] dr_ba,   // SDRAM bank-address
    output [3:0] dr_dqm,  // byte select
    inout  [31:0] dr_d    // data bus to/from SDRAM
);
    wire [2:0] clocks_video;
    clk_100_375_75_25
    clk_100_375_75_25_inst
    (
      .clkin(clk_100mhz_p),
      .clkout0(clocks_video[0]),
      .clkout1(clocks_video[1]),
      .clkout2(clocks_video[2])
    );
    wire clk_pixel, clk_shift;
    assign clk_pixel = clocks_video[1]; //  75 MHz
    assign clk_shift = clocks_video[0]; // 375 MHz
    //                 clocks_video[2]; //  25 MHz unused

    wire [2:0] clocks_system;
    wire pll_locked;
    clk_100_100_100p_25
    clk_100_100_100p_25_inst
    (
      .clkin(clk_100mhz_p),
      .clkout0(clocks_system[0]),
      .clkout1(clocks_system[1]),
      .clkout2(clocks_system[2]),
      .locked(pll_locked)
    );
    wire clk_cpu, clk_sdram;
    assign clk_sdram = clocks_system[0]; // 100 MHz sdram controller
    assign dr_clk = clocks_system[1]; // 100 MHz 225 deg SDRAM chip
    assign clk_cpu = clocks_system[2];   //  25 MHz
    
    wire [3:0] led;

    wire vga_hsync, vga_vsync, vga_blank;
    wire [1:0] vga_r, vga_g, vga_b;

    RISC5Top sys_inst
    (
      .CLK_CPU(clk_cpu),
      .CLK_SDRAM(clk_sdram),
      .CLK_PIXEL(clk_pixel),
      .BTN_NORTH(1'b0), // up
      .BTN_SOUTH(1'b0), // down
      .BTN_WEST(1'b0),  // left
      .BTN_EAST(1'b0),  // right (reset btn)
      .RX(uart3_rxd),   // RS-232
      .TX(uart3_txd),
      .LED(led),

      .SD_DO(sd_m_d[0]), // SPI - SD card & network
      .SD_DI(sd_m_cmd),
      .SD_CK(sd_m_clk),
      .SD_nCS(sd_m_d[3]),

      .VGA_HSYNC(vga_hsync),
      .VGA_VSYNC(vga_vsync),
      .VGA_BLANK(vga_blank),
      .VGA_R(vga_r),
      .VGA_G(vga_g),
      .VGA_B(vga_b),

      .PS2CLKA(fioa[6]), // keyboard clock
      .PS2DATA(fioa[4]), // keyboard data
      .PS2CLKB(fioa[3]), // mouse clock
      .PS2DATB(fioa[1]), // mouse data

      .gpio(),

      .SDRAM_nCAS(dr_cas_n),
      .SDRAM_nRAS(dr_ras_n),
      .SDRAM_nCS(dr_cs_n),
      .SDRAM_nWE(dr_we_n),
      .SDRAM_BA(dr_ba),
      .SDRAM_ADDR(dr_a),
      .SDRAM_DATA(dr_d[15:0]),
      .SDRAM_DQML(dr_dqm[0]),
      .SDRAM_DQMH(dr_dqm[1])
    );
    assign dr_cke = 1'b1;
    assign dr_dqm[2] = 1'b1;
    assign dr_dqm[3] = 1'b1;
    assign dr_d[31:16] = 16'hzzzz;

    assign sd_m_d[1] = 1'b1;
    assign sd_m_d[2] = 1'b1;
    
    assign fioa[5] = led[2];
    assign fioa[7] = led[3];

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
      .out_p(vid_d_p),
      .out_n()
    );
endmodule
