// povik/sv-elab#212 (closed): Support for `wor` `wand` and other special nets
// https://github.com/povik/sv-elab/issues/212
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module WiredNet (
    input wire data1,
    input wire data2,
    output wire out_wired
);
    wor w_or;
    assign w_or = data1;
    assign w_or = data2;
    assign out_wired = w_or;
    
endmodule

