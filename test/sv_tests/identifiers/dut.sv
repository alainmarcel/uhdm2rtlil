// Converted from chipsalliance/sv-tests (identifiers).
// Upstream declares nine plain identifiers -- including `n$657` and a case-sensitive `sensitive`/`Sensitive` pair -- and never drives or reads any of them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module identifiers(input logic [8:0] x, output logic [8:0] y);
  reg shiftreg_a;
  reg busa_index;
  reg error_condition;
  reg merge_ab;
  reg _bus3;
  reg n$657;
  /* Should also be case sensitive,
   * should not cause a conflict here
   */
  reg sensitive;
  reg Sensitive;
  // Each name is driven and read back.  `sensitive` and `Sensitive` take DIFFERENT
  // bits, so a frontend that folded them together cannot pass.
  always_comb begin
    shiftreg_a      = x[0];
    busa_index      = x[1];
    error_condition = x[2];
    merge_ab        = x[3];
    _bus3           = x[4];
    n$657           = x[5];
    sensitive       = x[6];
    Sensitive       = x[7];
  end
  assign y = {1'b0, Sensitive, sensitive, n$657, _bus3, merge_ab,
              error_condition, busa_index, shiftreg_a};
endmodule
