// A NET-declared packed array of a named struct typedef, indexed by a
// CONSTANT: `info_q[0]` must select the whole 8-bit element, not one bit.
package p;
  typedef struct packed {
    logic is_normal;
    logic is_subnormal;
    logic is_zero;
    logic is_inf;
    logic is_nan;
    logic is_signalling;
    logic is_quiet;
    logic is_boxed;
  } fp_info_t;
endpackage

module dut (
    input  logic [15:0] w_i,
    input  logic        sel_i,
    output logic [7:0]  a_o,       // element 0, constant index
    output logic [7:0]  b_o,       // element 1, constant index
    output logic [7:0]  dyn_o,     // dynamic index
    output logic        field_o    // a field of a constant-indexed element
);
  p::fp_info_t [1:0] info_q;       // a NET: packed_array_net, not _var
  p::fp_info_t a, b;

  assign info_q = w_i;
  assign a      = info_q[0];
  assign b      = info_q[1];
  assign a_o    = a;
  assign b_o    = b;
  assign dyn_o  = info_q[sel_i];
  assign field_o = a.is_boxed;
endmodule
