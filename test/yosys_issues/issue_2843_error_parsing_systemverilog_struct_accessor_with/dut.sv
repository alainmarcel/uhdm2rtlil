// YosysHQ/yosys#2843 (closed): Error parsing SystemVerilog struct accessor within case statements
// https://github.com/YosysHQ/yosys/issues/2843
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
typedef struct packed {
    logic a;
} mystruct;

module top();
    mystruct s;
    always @(*) case(s.a)
        default: begin end
    endcase
endmodule

