// Converted from chipsalliance/sv-tests (attributes-variable).
// Upstream attaches three `fsm_state` spellings to declarations that nothing drives or reads, so the attribute is never carried through to anything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] x, output logic [7:0] ao, output logic [7:0] bo,
           output logic [7:0] co);
  (* fsm_state *)   logic [7:0] a;
  (* fsm_state=1 *) logic [7:0] b;
  (* fsm_state=0 *) logic [7:0] c;
  // Each attributed variable is driven and read, so an attribute that cost the
  // declaration its width or its driver is visible.
  assign a  = x;
  assign b  = x + 8'd1;
  assign c  = x + 8'd2;
  assign ao = a;
  assign bo = b;
  assign co = c;
endmodule
