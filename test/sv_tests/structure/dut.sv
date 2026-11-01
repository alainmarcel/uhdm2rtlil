// Converted from chipsalliance/sv-tests (structure).
// Upstream assigns the struct three ways inside an `initial` block -- positional, `default:`, and `int:` type-keyed patterns -- and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] a_pos,
           output logic signed [31:0] b_pos, output logic signed [31:0] a_def,
           output logic signed [31:0] b_def, output logic signed [31:0] a_typ,
           output logic signed [31:0] b_typ);
  typedef struct {
    int a;
    int b;
  } ms_t;
  ms_t p, d, t;
  // Each of upstream's three assignment-pattern forms fills its own struct, so
  // which members each form reached is a value.
  always_comb begin
    p = '{ x, 1};
    d = '{ default:1, int:1};
    t = '{ int:0, int:1};
  end
  assign a_pos = p.a; assign b_pos = p.b;
  assign a_def = d.a; assign b_def = d.b;
  assign a_typ = t.a; assign b_typ = t.b;
endmodule
