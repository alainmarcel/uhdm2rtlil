// Converted from chipsalliance/sv-tests (enum_type_checking).
// Upstream assigns an enum member to an enum variable inside an `initial` block and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [1:0] x, output logic [1:0] o, output logic is_a);
  typedef enum {a, b, c, d} e;
  e val;
  // Assigning a MEMBER (not an integer) is the construct: the variable must take
  // that member's value, and a comparison back against the member must hold.
  always_comb
    case (x)
      2'd0:    val = a;
      2'd1:    val = b;
      2'd2:    val = c;
      default: val = d;
    endcase
  assign o    = val;
  assign is_a = (val == a);
endmodule
