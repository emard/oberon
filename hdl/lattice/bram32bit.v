// AUTHOR=EMARD
// LICENSE=BSD

module bram32bit
#(
	parameter addr_width = 12
)
(
	input			clk_a,
	input			clken_a,
	input  [addr_width-1:0]	addr_a,
	input  [3:0]		we_a,
	input  [31:0]		data_in_a,
	output [31:0]		data_out_a,

	input			clk_b,
	input			clken_b,
	input  [addr_width-1:0]	addr_b,
	input  [3:0]		we_b,
	input  [31:0]		data_in_b,
	output [31:0]		data_out_b
);
        wire wr_a = |we_a;
        wire wr_b = |we_b;

	wire [31:0] doa[0:3], dob[0:3];
	assign data_out_a = doa[addr_a[11:10]];
	assign data_out_b = dob[addr_b[11:10]];

	generate
	  genvar i, j;
	  for(i = 0; i < 4; i = i + 1) // 4*1024 addr
	    for(j = 0; j < 2; j = j + 1) // 2*16 data
	      DP16KD
	      #(
		.DATA_WIDTH_A(18),
		.DATA_WIDTH_B(18),
		.CSDECODE_A(i==0 ? "0b000" : i==1 ? "0b001" : i==2 ? "0b010" : "0b011"),
		.CSDECODE_B(i==0 ? "0b000" : i==1 ? "0b001" : i==2 ? "0b010" : "0b011"),
		// WRITEMODE and REGMODE can be commented out and it still works
		//.WRITEMODE_A("WRITETHROUGH"),
		//.WRITEMODE_B("WRITETHROUGH"),
		//.REGMODE_A("NOREG"),
		//.REGMODE_B("NOREG"),
		.RESETMODE("ASYNC"),
		.GSR("DISABLED")
	      )
	      dp16kd_inst
	      (
		.CLKA(clk_a), .CLKB(clk_b),
		.ADA0(we_a[0+j*2]), .ADA1(we_a[1+j*2]), // byte select
		.ADA2(1'b0), .ADA3(1'b0), // always 0
		.ADA4(addr_a[0]), .ADA5(addr_a[1]), .ADA6(addr_a[2]), .ADA7(addr_a[3]), .ADA8(addr_a[4]), .ADA9(addr_a[5]), .ADA10(addr_a[6]), .ADA11(addr_a[7]), .ADA12(addr_a[8]), .ADA13(addr_a[9]), // 10-bit address
		.ADB0(we_b[0+j*2]), .ADB1(we_b[1+j*2]), // byte select
		.ADB2(1'b0), .ADB3(1'b0), // always 0
		.ADB4(addr_b[0]), .ADB5(addr_b[1]), .ADB6(addr_b[2]), .ADB7(addr_b[3]), .ADB8(addr_b[4]), .ADB9(addr_b[5]), .ADB10(addr_b[6]), .ADB11(addr_b[7]), .ADB12(addr_b[8]), .ADB13(addr_b[9]), // 10-bit address
		.DIA0(data_in_a[0+j*16]),  .DIA1(data_in_a[ 1+j*16]),  .DIA2(data_in_a[ 2+j*16]),  .DIA3(data_in_a[ 3+j*16]),  .DIA4(data_in_a[ 4+j*16]),  .DIA5(data_in_a[ 5+j*16]),  .DIA6(data_in_a[ 6+j*16]),  .DIA7(data_in_a[ 7+j*16]),  .DIA8(1'b0),
		.DIA9(data_in_a[8+j*16]), .DIA10(data_in_a[ 9+j*16]), .DIA11(data_in_a[10+j*16]), .DIA12(data_in_a[11+j*16]), .DIA13(data_in_a[12+j*16]), .DIA14(data_in_a[13+j*16]), .DIA15(data_in_a[14+j*16]), .DIA16(data_in_a[15+j*16]), .DIA17(1'b0),
		.DIB0(data_in_b[0+j*16]),  .DIB1(data_in_b[ 1+j*16]),  .DIB2(data_in_b[ 2+j*16]),  .DIB3(data_in_b[ 3+j*16]),  .DIB4(data_in_b[ 4+j*16]),  .DIB5(data_in_b[ 5+j*16]),  .DIB6(data_in_b[ 6+j*16]),  .DIB7(data_in_b[ 7+j*16]),  .DIB8(1'b0),
		.DIB9(data_in_b[8+j*16]), .DIB10(data_in_b[ 9+j*16]), .DIB11(data_in_b[10+j*16]), .DIB12(data_in_b[11+j*16]), .DIB13(data_in_b[12+j*16]), .DIB14(data_in_b[13+j*16]), .DIB15(data_in_b[14+j*16]), .DIB16(data_in_b[15+j*16]), .DIB17(1'b0),
		.DOA0(doa[i][0+j*16]),  .DOA1(doa[i][ 1+j*16]),  .DOA2(doa[i][ 2+j*16]),  .DOA3(doa[i][ 3+j*16]),  .DOA4(doa[i][ 4+j*16]),  .DOA5(doa[i][ 5+j*16]),  .DOA6(doa[i][ 6+j*16]),  .DOA7(doa[i][ 7+j*16]), .DOA8(),
		.DOA9(doa[i][8+j*16]), .DOA10(doa[i][ 9+j*16]), .DOA11(doa[i][10+j*16]), .DOA12(doa[i][11+j*16]), .DOA13(doa[i][12+j*16]), .DOA14(doa[i][13+j*16]), .DOA15(doa[i][14+j*16]), .DOA16(doa[i][15+j*16]), .DOA17(),
		.DOB0(dob[i][0+j*16]),  .DOB1(dob[i][ 1+j*16]),  .DOB2(dob[i][ 2+j*16]),  .DOB3(dob[i][ 3+j*16]),  .DOB4(dob[i][ 4+j*16]),  .DOB5(dob[i][ 5+j*16]),  .DOB6(dob[i][ 6+j*16]),  .DOB7(dob[i][ 7+j*16]), .DOB8(),
		.DOB9(dob[i][8+j*16]), .DOB10(dob[i][ 9+j*16]), .DOB11(dob[i][10+j*16]), .DOB12(dob[i][11+j*16]), .DOB13(dob[i][12+j*16]), .DOB14(dob[i][13+j*16]), .DOB15(dob[i][14+j*16]), .DOB16(dob[i][15+j*16]), .DOB17(),
		.WEA(wr_a), .CEA(clken_a), .OCEA(clken_a),
		.WEB(wr_b), .CEB(clken_b), .OCEB(clken_b),
		.CSA2(1'b0), .CSA1(addr_a[11]), .CSA0(addr_a[10]),
		.CSB2(1'b0), .CSB1(addr_b[11]), .CSB0(addr_b[10]),
		.RSTA(1'b0), .RSTB(1'b0)
	      );
	endgenerate
endmodule
