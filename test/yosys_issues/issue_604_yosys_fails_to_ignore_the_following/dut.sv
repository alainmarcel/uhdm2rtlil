// YosysHQ/yosys#604 (closed): Yosys fails to ignore the following `specify` block
// https://github.com/YosysHQ/yosys/issues/604
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): co-sim top module lut_top instantiates LUT_K with a non-zero LUT_MASK (the default all-zero mask made out constant); the specify block is unchanged

// ---- b0.sv
//K-input Look-Up Table
module LUT_K #(
    //The Look-up Table size (number of inputs)
    parameter K=2, 

    //The lut mask.  
    //Left-most (MSB) bit corresponds to all inputs logic one. 
    //Defaults to always false.
    parameter LUT_MASK={2**K{1'b0}} 
) (
    input [K-1:0] in,
    output out
);

    specify
        (in *> out) = "";
    endspecify

    assign out = LUT_MASK[in];

endmodule

// co-sim top: the LUT with a NON-zero mask (the default mask is all zeros,
// so `out` was constant)
module lut_top (input [1:0] in, output out);
  LUT_K #(.K(2), .LUT_MASK(4'b0110)) u (.in(in), .out(out));
endmodule
