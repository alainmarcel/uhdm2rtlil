// YosysHQ/yosys#30 (closed): MUXOPT does not scale
// https://github.com/YosysHQ/yosys/issues/30
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
/* Count leading zeroes by independent prefix comparison: works for non-power-of-two sizes: */
module count_leading_zeroes (in, out);
        parameter BITS = 4; /* no problem */
/* set parameter BITS = 32 or some BIG_NUMBER and watch the optimizer spinning.... */
        localparam OUT_BITS = $clog2(BITS) + 1;
        input [BITS-1:0] in;
        output reg [OUT_BITS-1:0] out;
        generate
                genvar i;
                for (i=0; i<BITS; i=i+1) begin
                        always @(*) begin
                                if (in[BITS-1:BITS-1-i] == { { i { 1'b0 } }, 1'b1 }) begin
                                        out = i;
                                end
                        end
                end
                always @(*) begin
                        if (in == 0) begin
                                out = { 1'b1 , { OUT_BITS - 1 { 1'b0 } } };
                        end
                end
        endgenerate
endmodule

