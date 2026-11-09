// YosysHQ/yosys#5465 (closed): SystemVerilog unsized literal '1 incorrectly evaluated as 1-bit value instead of filling all bits
// https://github.com/YosysHQ/yosys/issues/5465
// Code block(s) from the issue (variant h1); harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): ports added: oo = o ^ t over a new input t (top had no ports; o is the '1 parameter value under test)

// ---- b0.sv
module set_param #(
    parameter [3:0] VALUE
) (
    output logic [3:0] out
);
    assign out = VALUE;
endmodule

module top (input logic [3:0] t, output logic [3:0] oo);
   assign oo = o ^ t;
   localparam logic [3:0] L1 = '1;
   logic [3:0] o;
   set_param #('1) sp (o);
   always_comb assert(L1 == 4'b1111);
   always_comb assert(o == 4'b1111);
endmodule

