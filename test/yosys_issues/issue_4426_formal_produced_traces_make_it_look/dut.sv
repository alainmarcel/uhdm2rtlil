// YosysHQ/yosys#4426 (open): formal: Produced traces make it look like asserts trigger a clock step too late
// https://github.com/YosysHQ/yosys/issues/4426
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module foo (
  input wire clk
);

  (* anyseq *) wire a;

  initial begin
    assume(a == 1'b1);
  end

  always @(posedge clk) begin
    assert(a == 1'b1);
  end

endmodule

