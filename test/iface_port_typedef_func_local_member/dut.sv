// A typedef taken THROUGH an interface port (`typedef t.hdr_t hdr_t;`) on a
// FUNCTION LOCAL: `h = hdr_t'(v); return h.a;` -- the struct-member site looked
// the staged local up as a module wire and read X (tnoc's AXI write/read
// demux select_route).  The module-level `m.b` read already worked.
interface types;
  typedef struct packed { logic [2:0] a; logic [4:0] b; } hdr_t;
  typedef logic [3:0] nib_t;
endinterface

module child (types t, input logic [7:0] in1, input logic [7:0] in2, output logic [2:0] y1, output logic [4:0] y2, output logic [3:0] y3);
  typedef t.hdr_t hdr_t;
  typedef t.nib_t nib_t;
  function automatic logic [2:0] pick(logic [7:0] v);
    hdr_t h;
    h = hdr_t'(v);
    return h.a;
  endfunction
  hdr_t m;
  nib_t n;
  always_comb begin
    m  = hdr_t'(in2);
    y2 = m.b;
    n  = nib_t'(in2[3:0]);
    y3 = n + 1;
  end
  assign y1 = pick(in1);
endmodule

module top (input logic [7:0] in1, input logic [7:0] in2, output logic [2:0] y1, output logic [4:0] y2, output logic [3:0] y3);
  types t();
  child c (.t(t), .in1(in1), .in2(in2), .y1(y1), .y2(y2), .y3(y3));
endmodule
