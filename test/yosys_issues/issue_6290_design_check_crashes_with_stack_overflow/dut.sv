// YosysHQ/yosys#6290 (closed): Design::check() crashes with stack overflow instead of printing the error it found
// https://github.com/YosysHQ/yosys/issues/6290
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module main (
    output logic [1:0] y
);
  always_comb begin
  end
endmodule

