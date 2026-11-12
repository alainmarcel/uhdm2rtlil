// povik/sv-elab#93 (open): References to constants from packages not resolved
// https://github.com/povik/sv-elab/issues/93
// Code block(s) from the issue (variant s0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
package pkg;
    const int value = 3;
endpackage

import pkg::*;

module top(output logic [3:0] out);
    assign out = value;
endmodule

