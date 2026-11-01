// Converted from chipsalliance/sv-tests (jump_continue).
// Upstream's loop runs inside an `initial` block and the statement the `continue` skips is a `$display`, so nothing a netlist sees changes.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module jump_tb (output logic signed [31:0] reached, output logic signed [31:0] n);
  // `continue` must skip the rest of the body for every index below 255, so the
  // statement after it runs exactly ONCE -- at upstream's 255.
  always_comb begin
    reached = 0;
    n       = 0;
    for (int i = 0; i < 256; i++) begin
      if(i < 255)
        continue;
      reached = i;
      n       = n + 1;
    end
  end
endmodule
