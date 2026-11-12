// povik/sv-elab#266 (closed): read_slang $mul output width is too small (MSB dropped)
// https://github.com/povik/sv-elab/issues/266
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
`default_nettype none
module t(
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] y
);
    wire [15:0] m = a * b;
    assign y = m[15:8];
endmodule

