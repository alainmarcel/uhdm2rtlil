// Converted from chipsalliance/sv-tests (debug-directives).
// Upstream prints `__FILE__` and `__LINE__` with $display, so neither value reaches anything synthesis can check.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module directives(output logic signed [31:0] lineno, output logic file_ok);
  // `__LINE__ is a number, so it can simply be read: it must be the line the macro
  // appears on.  `__FILE__ is compared against this file's own name.
  // `__FILE__ expands to the path the tool was given, which is not portable, so
  // the claim is on its last six characters -- a string literal is right-aligned
  // in a wider vector, so those are the LOW 48 bits.
  logic [8*256-1:0] fname;
  assign fname   = `__FILE__;
  assign lineno  = `__LINE__;
  assign file_ok = (fname[47:0] == "dut.sv");
endmodule
