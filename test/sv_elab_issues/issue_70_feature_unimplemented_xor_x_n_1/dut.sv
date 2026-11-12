// povik/sv-elab#70 (closed): Feature unimplemented (xor X[N-1:0] (a, b, c))
// https://github.com/povik/sv-elab/issues/70
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module bus_invert(in, out, invert);
    parameter N=8;
    input [N-1:0] in;
    input invert;
    output [N-1:0] out;
    xor X[N-1:0] (out, in, invert);
endmodule

