/*
FIXME: whole picture is shifted cca 16 pixels to the left
*/

module vqueue
#(
  parameter almost_empty = 8, // when less than this numer of elements left
  parameter addr_width = 5 // queue length: 2**n elements
)
(
  input WrClock,
  input RdClock,
  input WrEn,
  input RdEn,
  input Reset, // unused
  input RPReset, // unused
  input [31:0] Data, 
  output [31:0] Q, 
  output Empty,
  output Full, // unused
  output AlmostEmpty,
  output AlmostFull // unused
);
  reg [addr_width-1:0] wraddr, rdaddr;
  wire [addr_width-1:0] rdaddr_next, addr_diff;

  always @(posedge WrClock)
  begin
    if(WrEn == 1'b1)
      wraddr <= wraddr + 1;
  end
  
  assign rdaddr_next = rdaddr + 1;
  assign addr_diff = wraddr - rdaddr;
  assign Empty = addr_diff == 0 ? 1'b1 : 1'b0;
  assign AlmostEmpty = addr_diff < almost_empty ? 1'b1 : 1'b0;

  always @(posedge RdClock)
  begin
    if(RdEn == 1'b1 && addr_diff != 0)
      rdaddr <= rdaddr_next;
  end


  bram_true2p_2clk
  #(
        .dual_port(1'b1),
        .data_width(32),
        .pass_thru_a(1'b1),
        .pass_thru_b(1'b1),
        .addr_width(addr_width)
  )
  bram_true2p_2clk_inst
  (
        .clk_a(WrClock),
        .clk_b(RdClock),
        .clken_a(1'b1),
        .clken_b(1'b1),
        .we_a(WrEn),
        .we_b(1'b0),
        .addr_a(wraddr),
        .addr_b(rdaddr),
        .data_in_a(Data),
        .data_in_b(),
        .data_out_a(),
        .data_out_b(Q)
  );

endmodule
