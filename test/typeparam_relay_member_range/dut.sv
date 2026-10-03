// PULP axi_id_remap_intf, reduced.  The intf module declares
// `typedef logic [ID_W-1:0] id_t` over its OWN parameter, builds the response
// struct over it and relays the struct as a TYPE PARAMETER into `mid`, which
// hands `r_i.b.id[IdxWidth-1:0]` to a child as a port actual.  The struct
// arrives in `mid` as a clone whose member ranges resolve in the RECEIVING
// scope, where ID_W sits at its default 0: the field's declared range read
// `[-1:0]` -- ASCENDING with high 0 -- and `[1:0]` was rebased to bit -1, so
// the child saw {id[0], resp[1]} instead of id[1:0] (axi_id_remap's table was
// fed the wrong master id in 276 of 301 co-simulated cycles).  The field's
// MEASURED width (4) is right; a declared range that disagrees with it is
// not trusted for rebasing.
module leaf #(parameter int unsigned IW = 2) (input logic [IW-1:0] pop, output logic [IW-1:0] o);
  assign o = ~pop;
endmodule
module mid #(parameter type resp_t = logic) (input resp_t r_i, output logic [1:0] oa, output logic [1:0] ob);
  localparam int unsigned IdxWidth = 2;
  leaf #(.IW(2)) ua (.pop(r_i.b.id[IdxWidth-1:0]), .o(oa));
  logic [1:0] sel;
  assign sel = r_i.b.id[IdxWidth-1:0];
  leaf #(.IW(2)) ub (.pop(sel), .o(ob));
endmodule
module intf #(parameter int unsigned ID_W = 32'd0, parameter int unsigned USER_W = 32'd0)
             (input logic [ID_W-1:0] id_i, input logic [1:0] resp_i, input logic [USER_W-1:0] user_i, output logic [1:0] oa, output logic [1:0] ob);
  typedef logic [ID_W-1:0]   id_t;
  typedef logic [USER_W-1:0] user_t;
  typedef struct packed { id_t id; logic [1:0] resp; user_t user; } b_t;
  typedef struct packed { b_t b; logic b_valid; } resp_t;
  resp_t r;
  assign r = '{b: '{id: id_i, resp: resp_i, user: user_i}, b_valid: 1'b1};
  mid #(.resp_t(resp_t)) u (.r_i(r), .oa(oa), .ob(ob));
endmodule
module dut (input logic [3:0] id_i, input logic [1:0] resp_i, input logic [1:0] user_i, output logic [1:0] oa, output logic [1:0] ob);
  intf #(.ID_W(4), .USER_W(2)) t (.id_i(id_i), .resp_i(resp_i), .user_i(user_i), .oa(oa), .ob(ob));
endmodule
