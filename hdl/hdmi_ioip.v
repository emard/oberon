`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 	Nicolae Dumitrache
// 
// Create Date:    17:40:52 10/28/2015  
// Design Name:    HDMI OUT interface
// Module Name:    HDMI_OUT 
// Project Name: 
// Target Devices: ECP5U
// Tool versions: 
// Description:  Minimal HDMI compliant source, sending null data islands when VSYNC=1 and negedge HSYNC 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module HDMI_OUT
	(
		input clk,
		input clk5x,
		input [7:0]R,
		input [7:0]G,
		input [7:0]B,
		input hsync,
		input vsync,
		input de,
		output [3:0]TMDS
	);
	
	wire [9:0]tmds_r;
	wire [9:0]tmds_g;
	wire [9:0]tmds_b;
	wire [7:0]d10R;
	wire [7:0]d10G;
	wire [7:0]d10B;
	wire d11de;
	wire [9:0]rcode;
	wire [9:0]gcode;
	wire [9:0]bcode;
	reg [5:0]STATE = 6'b000000;
	wire nextstate;
	reg dhsync = 1'b0;
	reg dde = 1'b0;
	wire [7:0]itmds;
	
	
	always @(posedge clk) begin
		dhsync <= hsync;
		dde <= de;
		
		if(vsync && dhsync && !hsync) STATE <= 6'd12; // data island preamble + guard band + null packet + guard band (all with VSYNC and not HSYNC)
		else 
			if(de && !dde) STATE <= 6'd1;		// video preamble + guard band
			else STATE <= STATE + nextstate;
	end
	
	hdmiCode hdmiCode_inst(
		.state(STATE),
		.vsync(vsync), 
		.hsync(hsync),
		.sync(!nextstate),
		.nextstate(nextstate),
		.rcode(rcode),
		.gcode(gcode),
		.bcode(bcode)
	);
	
	delay10 delay10_inst(
		.clk(clk),
		.inData({dde, B, G, R}),
		.outData({d11de, d10B, d10G, d10R})
	);

	TMDS_encoder TMDS_RED(
		.clk(clk),
		.VD(d10R),
		.CD(rcode),
		.VDE(d11de),
		.TMDS(tmds_r)
	);

	TMDS_encoder TMDS_GREEN(
		.clk(clk),
		.VD(d10G),
		.CD(gcode),
		.VDE(d11de),
		.TMDS(tmds_g)
	);
	
	TMDS_encoder TMDS_BLUE(
		.clk(clk),
		.VD(d10B),
		.CD(bcode),
		.VDE(d11de),
		.TMDS(tmds_b)
	);

	c40to8 c40to8_inst(
		.clk(clk),
		.clk5x(clk5x),
		.din({10'b1111100000, tmds_r, tmds_g, tmds_b}),
		.dout(itmds)
	);

	ioip ioip_inst(
		.refclk(clk5x),
		.reset(1'b0),
		.data(itmds),
		.clkout(),
		.dout(TMDS)
	);

endmodule


module TMDS_encoder(
		input clk,
		input [7:0]VD,  // video data (red, green or blue)
		input [9:0]CD,  // control data
		input VDE,  	 // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
		output reg [9:0]TMDS = 10'b0000000000
	);

	wire [3:0]Nb1s = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
	wire XNOR = (Nb1s > 4'd4) || (Nb1s == 4'd4 && VD[0] == 1'b0);
	wire [8:0]iq_m = {~XNOR, iq_m[6:0] ^ VD[7:1] ^ {7{XNOR}}, VD[0]};
	reg [8:0]q_m;
	reg [3:0]balance_acc = 0;
	wire [3:0]balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
	wire balance_sign_eq = (balance[3] == balance_acc[3]);
	wire invert_q_m = (balance == 4'b0000 || balance_acc == 4'b0000) ? ~q_m[8] : balance_sign_eq;
	wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance == 4'b0000 || balance_acc == 4'b0000));
	wire [3:0] balance_acc_new = invert_q_m ? (balance_acc - balance_acc_inc) : (balance_acc + balance_acc_inc);
	wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};

	always @(posedge clk) begin
		q_m <= iq_m;
		TMDS <= VDE ? TMDS_data : CD;
		balance_acc <= VDE ? balance_acc_new : 4'h0;
	end
	
endmodule


module delay10 (
		input clk,
		input [24:0]inData,
		output reg [24:0]outData
	);
	
	reg [24:0]mem[15:0];
	reg [3:0]addr;
	
	always @(posedge clk) begin
		addr <= addr + 1'b1;
		mem[addr + 4'd9] <= inData;
		outData <= mem[addr];
	end
	
endmodule


module hdmiCode(
		input [5:0]state,
		input vsync,
		input hsync,
		input sync,
		output nextstate,
		output [9:0]rcode,
		output [9:0]gcode,
		output [9:0]bcode
	);

	reg [2:0]idx;
	wire [7:0]rgbctlidx = FIDX(idx); // 3,2,3 bits
	assign rcode = RGCODES(sync ? 3'b000 : rgbctlidx[7:5]);
	assign gcode = RGCODES({1'b0, sync ? 2'b00 : rgbctlidx[4:3]});
	assign bcode = BCODES(sync ? {1'b0, vsync, hsync} : rgbctlidx[2:0]);
	assign nextstate = ~&idx;
	
	always @(state) begin
		case(state)
			1,2,3,4,5,6,7,8: 			idx = 3'b000;		// 354_0ab_354 : Video Preamble 5.2.1.1			
			9,10:							idx = 3'b001;		// 2cc_133_2cc : Video Guard Band 5.2.2.1
			12,13,14,15,16,17,18,19:idx = 3'b010; 		// 0ab_0ab_154 : Data Island Preamble with VSYNC 5.2.1.1
			20,21: 						idx = 3'b011; 		// 133_133_163 : Data Island GuardBand with VSYNC 5.2.3.3
			22: 							idx = 3'b100;		// 29c_29c_2e4 : Data Island 0 - Null packet
			23,24,25,26,27,28,29,30,
			31,32,33,34,35,36,37,38,
			39,40,41,42,43,44,45,46,
			47,48,49,50,51,52,53: 	idx = 3'b101;		// 29c_29c_19c : Data Island 1..31
			54,55: 						idx = 3'b011; 		// 133_133_163 : Data Island GuardBand with VSYNC 5.2.3.3
			0,11,56:						idx = 3'b111;		// end sequence
			default:						idx = 3'bxxx;
		endcase
	end

	function [9:0]RGCODES;
		input [2:0]index;
		begin
			case(index)
				0: RGCODES = 10'h354;
				1: RGCODES = 10'h29c;
				2: RGCODES = 10'h0ab;
				3: RGCODES = 10'h133;
				4: RGCODES = 10'h2cc;
				default: RGCODES = 10'hxxx;
			endcase
		end
	endfunction

	function [9:0]BCODES;
		input [2:0]index;
		begin
			case(index)
				0: BCODES = 10'h354;
				1: BCODES = 10'h0ab;
				2: BCODES = 10'h154;
				3: BCODES = 10'h2ab;
				4: BCODES = 10'h163;
				5: BCODES = 10'h2cc;
				6: BCODES = 10'h2e4;
				7: BCODES = 10'h19c;
			endcase
		end
	endfunction

	function [7:0]FIDX;
		input [2:0]index;
		begin
			case(index)
				0: FIDX = 8'b000_10_000; // R_G_B
				1: FIDX = 8'b100_11_101;
				2: FIDX = 8'b010_10_010;
				3: FIDX = 8'b011_11_100;
				4: FIDX = 8'b001_01_110;
				5: FIDX = 8'b001_01_111;
				default: FIDX = 8'bxxx_xx_xxx;
			endcase
		end
	endfunction

endmodule


module c40to8(
	input clk,
	input clk5x,	// clk*5
	input [39:0]din,
	output [7:0]dout
	);
	
	reg start = 1'b0;
	reg [39:0]mem;
	reg [2:0]state = 3'b000;
	assign dout = {mem[31], mem[21], mem[11], mem[1], mem[30], mem[20], mem[10], mem[0]};
	
	always @(negedge clk) start <= 1'b1;
	
	always @(posedge clk5x) if(start) begin
		state <= state + (state[2] ? 3'b100 : 1'b1);
		mem <= |state ? (mem >> 2) : din;
	end
	
endmodule
