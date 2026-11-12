// povik/sv-elab#195 (closed): Support modules with import but no ports
// https://github.com/povik/sv-elab/issues/195
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// a.sv

package pkg;
endpackage

module a;
endmodule

module b import pkg::*;;
endmodule

