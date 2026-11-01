// Converted from chipsalliance/sv-tests (enum_anon).
// Upstream declares an anonymous enum variable and never drives or reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [1:0] x, output logic [1:0] val_o, output logic is_b);
  enum {a, b, c} val;
  // The anonymous enum's members must carry their implicit values 0,1,2, which a
  // comparison against one of them reads back.  The members themselves are the
  // only way to drive an ANONYMOUS enum: it has no type name to cast to, and
  // read_slang rightly refuses an implicit conversion from logic[1:0].
  always_comb
    case (x)
      2'd0:    val = a;
      2'd1:    val = b;
      default: val = c;
    endcase
  assign val_o = val;
  assign is_b  = (val == b);
endmodule
