// YosysHQ/yosys#30 (closed): MUXOPT does not scale
// https://github.com/YosysHQ/yosys/issues/30
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): per-bit always blocks merged into one (they multiply drove `out`); same prefix-compare mux chain

// ---- b0.sv
/* Count leading zeroes by independent prefix comparison: works for non-power-of-two sizes: */
module count_leading_zeroes (in, out);
        parameter BITS = 4; /* no problem */
/* set parameter BITS = 32 or some BIG_NUMBER and watch the optimizer spinning.... */
        localparam OUT_BITS = $clog2(BITS) + 1;
        input [BITS-1:0] in;
        output reg [OUT_BITS-1:0] out;
        // HAND-EDITED: the issue's per-bit always blocks all drove `out`
        // (multiply driven); one block keeps the same priority chain.
        integer i;
        always @(*) begin
                out = 0;
                for (i=0; i<BITS; i=i+1) begin
                        if ((in >> (BITS-1-i)) == 1) begin   // == in[BITS-1:BITS-1-i] == {i'b0, 1'b1}
                                out = i;
                        end
                end
                if (in == 0) begin
                        out = { 1'b1 , { OUT_BITS - 1 { 1'b0 } } };
                end
        end
endmodule

