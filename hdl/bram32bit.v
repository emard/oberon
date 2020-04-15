// byte addressable BRAM

module bram32bit
#(
  parameter addr_width = 12
)
(
  input clk_a, clk_b,
  input clken_a, clken_b,
  input [(addr_width-1):0] addr_a, addr_b,
  input [3:0] we_a, we_b,
  input [31:0] data_in_a, data_in_b,
  output [31:0] data_out_a, data_out_b
);
  generate
    genvar i;
    for(i = 0; i < 4; i++)
    begin
      bram_true2p_2clk
      #(
        .dual_port(1'b1),
        .data_width(8),
        .pass_thru_a(1'b1),
        .pass_thru_b(1'b1),
        .addr_width(addr_width)
      )
      bram_true2p_2clk_inst
      (
        .clk_a(clk_a),
        .clk_b(clk_b),
        .clken_a(clken_a),
        .clken_b(clken_b),
        .we_a(we_a[i]),
        .we_b(we_b[i]),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .data_in_a(data_in_a[i*8+7:i*8]),
        .data_in_b(data_in_b[i*8+7:i*8]),
        .data_out_a(data_out_a[i*8+7:i*8]),
        .data_out_b(data_out_b[i*8+7:i*8])
      );
    end
  endgenerate
endmodule
