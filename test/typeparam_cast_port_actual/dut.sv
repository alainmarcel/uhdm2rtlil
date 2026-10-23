// A cast to a TYPE PARAMETER used as a PORT ACTUAL -- HPDcache tags each
// requester with `hpdcache_req_sid_t'(...)` on the instance connection, under
// `parameter type hpdcache_req_sid_t = logic` bound by the wrapper to a wider
// type.  The reader measures the cast type against current_instance, which
// while the connection is imported is the CHILD instance; the parent's
// `sid_t` default matched nothing there and the operand was truncated to one
// bit (o_dyn read 0 instead of in4+1).  The same cast on a module-level
// assign (o_dyn2) was right all along, and is kept here as the contrast.
module leaf #(parameter type sid_t = logic) (input sid_t sid_i, output logic [3:0] o);
  assign o = {1'b0, sid_i};
endmodule
module mid #(parameter type sid_t = logic) (
    input  logic [3:0] in4, output logic [3:0] o_dyn, output logic [3:0] o_dyn2);
  leaf #(.sid_t(sid_t)) u_dyn (.sid_i(sid_t'(in4 + 4'd1)), .o(o_dyn));
  assign o_dyn2 = {1'b0, sid_t'(in4 + 4'd1)};
endmodule
module dut (input logic [3:0] in4, output logic [3:0] o_dyn, output logic [3:0] o_dyn2);
  typedef logic [2:0] my_sid_t;
  mid #(.sid_t(my_sid_t)) u (.in4, .o_dyn, .o_dyn2);
endmodule
