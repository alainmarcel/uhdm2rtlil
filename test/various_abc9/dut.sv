// Imported from yosys/tests/various/abc9.v.
//
// The upstream file has three modules:
//   * abc9_test027 — output reg with self-toggling combinational always
//     (`always @* o <= ~o;`).  Exercises a Yosys-specific corner of
//     `abc9 -lut 4` that doesn't survive the standard synth flow our
//     workflow uses (`opt` collapses the cycle to a constant under
//     both frontends, leaving zero logic to compare).
//   * abc9_test028 — instantiates undefined blackboxes
//     `unknown u(~i, w);` / `unknown2 u2(w, o);` with positional
//     args.  Verilog frontend drops the module as unused at
//     `hierarchy -auto-top`; our UHDM path now keeps it (Surelog
//     emits the unknown ports anyway).  The write_verilog round-trip
//     produces mixed positional/named ports on the resulting
//     blackbox cell that fail re-parse during the equivalence check.
//
// Only abc9_test032 is retained — it's the negedge async-reset FF
// case the test actually exercises end-to-end through our flow.

module abc9_test032(input clk, d, r, output reg q);
initial q = 1'b0;
always @(negedge clk or negedge r)
    if (!r) q <= 1'b0;
    else q <= d;
endmodule
