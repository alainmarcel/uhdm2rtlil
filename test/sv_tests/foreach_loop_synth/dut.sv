// Converted from chipsalliance/sv-tests (foreach_loop_synth).
// Upstream is already synthesizable but has no ports: `test` is a constant and `copy` is never read, so the `foreach` copy is dead.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module test (input logic [15:0] x, output logic [15:0] c0, output logic [15:0] c1,
             output logic [15:0] c2, output logic [15:0] c3);
  logic [15:0] src [4];
  logic [15:0] copy [4];
  // One element comes from a port so the copy cannot be folded away, and every
  // element of the destination is read back.
  always_comb begin
    src[0] = 16'h1111;
    src[1] = 16'h2222;
    src[2] = x;
    src[3] = 16'h4444;
    foreach(src[i]) begin
      copy[i] = src[i];
    end
  end
  assign c0 = copy[0];
  assign c1 = copy[1];
  assign c2 = copy[2];
  assign c3 = copy[3];
endmodule
