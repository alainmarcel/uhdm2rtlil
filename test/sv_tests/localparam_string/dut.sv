// Converted from chipsalliance/sv-tests (localparam_string).
// Upstream declares an untyped and a `string`-typed localparam and never reads either.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic s1_ok, output logic s2_ok);
  localparam s1 = "foo";
  localparam string s2 = "bar";
  // A string localparam's value is observable by COMPARISON, which is the only form
  // a netlist can carry.
  assign s1_ok = (s1 == "foo");
  assign s2_ok = (s2 == "bar");
endmodule
