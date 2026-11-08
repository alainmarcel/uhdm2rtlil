// YosysHQ/yosys#2589: `always_ff @(posedge clk) seq++;`
// https://github.com/YosysHQ/yosys/issues/2589
// An increment / decrement used as a STATEMENT in always_ff is a blocking
// write of the register: it must infer a flop, two of them in one block add
// up, and a later read in the same block sees the incremented value.
module dut(input logic clk, input logic en,
           output logic [3:0] seq, output logic [3:0] two, output logic [3:0] dn,
           output logic [3:0] cnt, output logic [3:0] seen, output logic [3:0] pre);
  always_ff @(posedge clk) seq++;
  always_ff @(posedge clk) begin two++; two++; end
  always_ff @(posedge clk) --dn;
  always_ff @(posedge clk) if (en) cnt++;
  always_ff @(posedge clk) begin ++pre; seen <= pre; end
endmodule
