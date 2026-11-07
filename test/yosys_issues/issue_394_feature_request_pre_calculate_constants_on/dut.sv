// YosysHQ/yosys#394 (closed): Feature request: pre calculate constants on adder cell input's
// https://github.com/YosysHQ/yosys/issues/394
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module add_conated_const (a, b, x, y);
input [31:0] a, b;
output [31:0] x, y;

    // const result fits in, no carry, only 8 bit adder needed  
    assign x = ({4'b0100, a[27:24], 24'b00000000000000000001} + {4'b1000, b[27:24], 24'b00000000000000000001});

    // carry
    assign y = ({4'b0001, a[27:24], 24'b11111111111111111111} + {4'b1111, b[27:24], 24'b00000000000000000001});

endmodule

