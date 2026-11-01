// Converted from chipsalliance/sv-tests (22.4--include_via_define, :type: preprocessing).
// Upstream is the directive alone plus an EMPTY `module top ();`, so nothing about it is observable.
// The directive is kept VERBATIM below and now brackets real logic: if it
// perturbed compilation the proven adder/subtractor would not survive.
// The whole directive group shares this body on purpose -- the directive form is
// the only variable, so a failure localises to it.  Upstream kept as orig.sv.
`define DO_INCLUDE(FN) `include FN
// Check that multiple define references don't throw a multiple `include-on-line error
`DO_INCLUDE("dummy_include.sv") `DO_INCLUDE("dummy_include.sv")
// Check that ifdefs
`ifdef NEVER
 `DO_INCLUDE("SHOULD_NOT_BE_INCLUDED")
`endif
module top(input logic [7:0] a, input logic [7:0] b, input logic sel,
           output logic [8:0] y);
  // One observable body for the whole directive group: the directive above is
  // the only variable, so a failure localises to it.
  assign y = sel ? (a + b) : (a - b);
endmodule
