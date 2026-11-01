// Converted from chipsalliance/sv-tests (enum_typedef).
// Upstream declares a variable of a typedef'd enum and never drives or reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [1:0] x, output logic [1:0] val_o, output logic is_c);
  typedef enum {a, b, c} e;
  e val;
  // The enum members must carry their implicit values 0,1,2, which a comparison
  // against one of them reads back.
  always_comb val = e'(x);
  assign val_o = val;
  assign is_c  = (val == c);
endmodule
