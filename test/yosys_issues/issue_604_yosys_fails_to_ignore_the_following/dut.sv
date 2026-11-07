// YosysHQ/yosys#604 (closed): Yosys fails to ignore the following `specify` block
// https://github.com/YosysHQ/yosys/issues/604
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

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

