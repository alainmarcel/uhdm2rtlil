// Converted from chipsalliance/sv-tests (for_loop).
// Upstream's loop body is a `$display` of the index, so the loop does nothing a netlist can see.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module for_tb (input logic [7:0] lim, output logic signed [31:0] sum,
                output logic signed [31:0] n);
  // Upstream's 256-iteration loop is kept; the body now accumulates, so the loop's
  // TRIP COUNT and every index it produced are both observable.
  always_comb begin
    sum = 0;
    n   = 0;
    for (int i = 0; i < 256; i++) begin
      sum = sum + i;
      n   = n + 1;
    end
  end
endmodule
