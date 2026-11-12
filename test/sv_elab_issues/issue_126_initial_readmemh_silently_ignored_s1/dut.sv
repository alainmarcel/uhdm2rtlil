// povik/sv-elab#126 (closed): `initial $readmemh` silently ignored
// https://github.com/povik/sv-elab/issues/126
// Code block(s) from the issue (variant s1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test;
    logic [9:0] sram[3];
    initial $readmemb("mem.hex", sram);
endmodule

