// The typedef taken through the interface port is itself an ALIAS inside
// the interface (`typedef hdr_fields_t hdr_t;` -- tnoc_types spells every
// header that way): Surelog hands the module a bare logic_typespec carrying
// only the NAME, so the local measured one bit and `.a` / `.b` were
// unresolvable.  Resolved against the port interface's own typedefs.
interface types;
  typedef struct packed { logic [2:0] a; logic [4:0] b; } hdr_fields_t;
  typedef hdr_fields_t hdr_t;
  typedef logic [3:0] nib_t;
endinterface

module child (types t, input logic [7:0] in1, input logic [7:0] in2, output logic [2:0] y1, output logic [4:0] y2, output logic [3:0] y3);
  typedef t.hdr_t hdr_t;
  typedef t.nib_t nib_t;
  hdr_t m;
  nib_t n;
  always_comb begin
    m  = hdr_t'(in2);
    y2 = m.b;
    n  = nib_t'(in2[3:0]);
    y3 = n + 1;
  end
  assign y1 = m.a;
endmodule

module top (input logic [7:0] in1, input logic [7:0] in2, output logic [2:0] y1, output logic [4:0] y2, output logic [3:0] y3);
  types t();
  child c (.t(t), .in1(in1), .in2(in2), .y1(y1), .y2(y2), .y3(y3));
endmodule
