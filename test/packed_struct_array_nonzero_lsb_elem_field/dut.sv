// A packed array of structs declared with a NON-ZERO low bound (black-parrot's
// `bp_mem_ready_and_link_s [E:W] link`, [2:1]): `p[k].field` must rebase k by
// the declared bounds.  Taken as zero-based, `p_i[1].v` read element 2's
// slot and `p_i[2].v` fell off the end (X).  Whole-element reads already
// rebased; the field reads and the dynamic element are what this gates.
typedef struct packed { logic v; logic [3:0] d; } s_t;
module top (input s_t [2:1] p_i, input s_t [1:2] q_i, input logic [1:0] sel,
            output logic y1, y2, output logic [3:0] y3, y4, output s_t y5, y6, output logic y7, y8, output logic [3:0] y9);
  assign y1 = p_i[1].v;
  assign y2 = p_i[2].v;
  assign y3 = p_i[1].d;
  assign y4 = p_i[2].d;
  assign y5 = p_i[1];
  assign y6 = p_i[sel];
  assign y7 = p_i[sel].v;
  assign y8 = q_i[1].v;
  assign y9 = q_i[2].d;
endmodule
