// A replication `{N{v}}` inside a constant function.  The compile-time
// evaluator had no vpiMultiConcatOp case: the replication came back EMPTY
// and the enclosing concat silently swallowed it, so
// `{1'b1, {DATA_WIDTH-1{1'b0}}}` folded to 1 instead of 8'b1000.
// verilog-ethernet lfsr seeds `for (data_mask = {1'b1, {DATA_WIDTH-1{1'b0}}};
// data_mask != 0; data_mask = data_mask >> 1)` with it, so the loop ran ONCE
// with the wrong mask and every CRC matrix entry was wrong (axis_gmii_tx /
// eth_mac_1g co-sim divergences that a seq-4 bounded proof cannot see).
module func_replication_const_eval #(
  parameter DATA_WIDTH = 4
) (
  input  logic [7:0] x,
  output logic [7:0] y,
  output logic [7:0] z
);
  // y = {iterations, mask} = {4'd4, 4'b1000}
  function [7:0] f(input [31:0] index);
    reg [DATA_WIDTH-1:0] data_mask;
    integer cnt;
    begin
      cnt = 0;
      for (data_mask = {1'b1, {DATA_WIDTH-1{1'b0}}}; data_mask != 0; data_mask = data_mask >> 1)
        cnt = cnt + 1;
      f = {cnt[3:0], {1'b1, {DATA_WIDTH-1{1'b0}}}};
    end
  endfunction
  // z = {4'd0, 4'b1000}
  function [7:0] g(input [31:0] index);
    reg [DATA_WIDTH-1:0] m;
    begin
      m = {1'b1, {DATA_WIDTH-1{1'b0}}};
      g = {4'd0, m};
    end
  endfunction
  assign y = f(0) ^ x;
  assign z = g(0) ^ x;
endmodule
