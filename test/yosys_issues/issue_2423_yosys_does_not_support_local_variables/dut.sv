// YosysHQ/yosys#2423 (closed): yosys does not support local variables as loop iterator
// https://github.com/YosysHQ/yosys/issues/2423
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): loop bound i < DEPTH -> i <= DEPTH: out reads flipflop[DEPTH], which the original loop never wrote (out was X); the always_ff-local 'integer i' the issue is about is unchanged

// ---- b0.sv
`timescale 1us/1us

module test(aclk, in, out);
    input bit aclk;
    input bit in;
    output bit out;
    parameter DEPTH = 3;

    bit flipflop[DEPTH:0];

    assign flipflop[0] = in;
    assign out = flipflop[DEPTH];

    always_ff @(posedge aclk) begin
        integer i;
        for (i = 1; i <= DEPTH; i++) begin
            flipflop[i] <= flipflop[i -1];
        end
    end
endmodule

