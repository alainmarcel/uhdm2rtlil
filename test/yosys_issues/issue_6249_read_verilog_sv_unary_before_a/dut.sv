// YosysHQ/yosys#6249 (closed): read_verilog -sv: unary -/~/! before a size cast binds to the cast width; with a constant operand the operator is silently dropped
// https://github.com/YosysHQ/yosys/issues/6249
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// min.sv
module t (output logic [7:0] y);
    assign y = -8'(16);
endmodule

