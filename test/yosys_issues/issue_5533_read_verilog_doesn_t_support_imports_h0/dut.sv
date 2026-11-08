// YosysHQ/yosys#5533 (open): read_verilog doesn't support imports in packages
// https://github.com/YosysHQ/yosys/issues/5533
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): empty body -> `assign q = d` through the imported/exported package type

// ---- b0.sv
package misc_types;
typedef logic yn_t;
endpackage

package types;
  import misc_types::yn_t;
  export misc_types::yn_t;
endpackage

module top (input types::yn_t d, output types::yn_t q);
  assign q = d;
endmodule

