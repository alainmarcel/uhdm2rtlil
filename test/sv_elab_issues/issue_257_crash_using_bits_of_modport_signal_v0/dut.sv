// povik/sv-elab#257 (closed): Crash using `$bits` of modport signal
// https://github.com/povik/sv-elab/issues/257
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(output logic [10:0] signal);
    assign signal = $bits(signal);
endmodule

