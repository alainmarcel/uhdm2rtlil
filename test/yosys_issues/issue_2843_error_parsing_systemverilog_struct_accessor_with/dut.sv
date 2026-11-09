// YosysHQ/yosys#2843 (closed): Error parsing SystemVerilog struct accessor within case statements
// https://github.com/YosysHQ/yosys/issues/2843
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): s is driven from a new input si and s.a is observable on o (the snippet had no ports; s was undriven); the case on s.a is unchanged

// ---- b0.sv
typedef struct packed {
    logic a;
} mystruct;

module top(input mystruct si, output logic o);
    mystruct s;
    assign s = si;
    assign o = s.a;
    always @(*) case(s.a)
        default: begin end
    endcase
endmodule

