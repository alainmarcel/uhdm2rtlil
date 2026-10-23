// A cast to a TYPE PARAMETER must take the type BOUND on the instance, not the
// parameter's declaration default.  CVA6's HPDcache tags every requester with
// `hpdcache_req_sid_t'(NumPorts - 1)` under `parameter type hpdcache_req_sid_t
// = logic`, bound by the wrapper to a 3-bit type; Surelog typed the cast with
// the 1-bit DEFAULT and folded the elaborated port actual to a 1-bit constant
// (store port id 1 instead of 3, prefetcher id 0 instead of 4), which no
// reader can recover from a folded constant -- the HPDcache flavour's
// cva6_hpdcache_wrapper / cva6_hpdcache_subsystem co-sim divergences.  Three
// shapes: the port actual (compiled per instance), the module-level assign
// (compiled once, reduced per instance) and a non-constant cast, which must
// keep its 3-bit type.
module leaf #(parameter type sid_t = logic) (input sid_t sid_i, output logic [3:0] o);
  assign o = {1'b0, sid_i};
endmodule
module mid #(parameter int NumPorts = 4, parameter type sid_t = logic) (
    input  logic [3:0] in4,
    output logic [3:0] o_store, output logic [3:0] o_pf, output sid_t sid_pf_o,
    output logic [3:0] o_dyn2);
  leaf #(.sid_t(sid_t)) u_store (.sid_i(sid_t'(NumPorts - 1)), .o(o_store));
  leaf #(.sid_t(sid_t)) u_pf    (.sid_i(sid_t'(NumPorts)),     .o(o_pf));
  assign sid_pf_o = sid_t'(NumPorts);
  assign o_dyn2 = {1'b0, sid_t'(in4 + 4'd1)};
endmodule
module dut (input logic [3:0] in4, output logic [3:0] o_store, output logic [3:0] o_pf,
            output logic [2:0] sid_pf_o, output logic [3:0] o_dyn2);
  typedef logic [2:0] my_sid_t;
  mid #(.NumPorts(4), .sid_t(my_sid_t)) u (.in4, .o_store, .o_pf, .sid_pf_o, .o_dyn2);
endmodule
