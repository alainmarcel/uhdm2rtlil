// A nested member read `st1_req.req.addr_tag` where `st1_req` is a LOCAL
// struct whose `req` member is typed by the module's `parameter type req_t`
// (HPDcache ctrl's `hpdcache_req_x_t { hpdcache_req_t req; ... }`), used as a
// PORT ACTUAL (`.dir_match_tag_i(st1_req.req.addr_tag)` into memctrl).  The
// read was X: the base struct is not in wire_map (a struct_net over a local
// typedef), the `req` member kept its `logic` default instead of the bound
// struct, and both were measured while the CHILD instance was current, where
// ctrl's parameter is not bound.  The directory match tag was therefore
// constant and the cache never hit (cva6_hpdcache_wrapper / _subsystem rows).
package pkg;
  typedef struct packed { logic [43:0] addr_tag; logic [7:0] addr_offset; logic [1:0] size; logic need_rsp; } req_t;
endpackage
module memctrl #(parameter type tag_t = logic) (input tag_t match_tag_i, input tag_t stored_tag_i, output logic hit_o);
  assign hit_o = (match_tag_i == stored_tag_i);
endmodule
module ctrl #(parameter type req_t = logic, parameter type tag_t = logic) (
    input logic clk, input req_t core_req_i, input logic core_req_valid_i, input tag_t stored_tag_i,
    output logic hit_o, output logic [1:0] size_o, output logic need_rsp_o);
  typedef struct packed { req_t req; logic valid; logic cacheable; } req_x_t;
  req_x_t st1_req, st1_req_q;
  always_ff @(posedge clk) st1_req_q <= '{req: core_req_i, valid: core_req_valid_i, cacheable: 1'b1};
  always_comb begin
    st1_req = st1_req_q;
    if (!st1_req_q.cacheable) st1_req.req.addr_tag = '0;
  end
  memctrl #(.tag_t(tag_t)) u_mem (.match_tag_i(st1_req.req.addr_tag), .stored_tag_i(stored_tag_i), .hit_o(hit_o));
  assign size_o = st1_req.req.size;
  assign need_rsp_o = st1_req.req.need_rsp;
endmodule
module dut (input logic clk, input pkg::req_t core_req_i, input logic core_req_valid_i, input logic [43:0] stored_tag_i,
            output logic hit_o, output logic [1:0] size_o, output logic need_rsp_o);
  typedef logic [43:0] my_tag_t;
  ctrl #(.req_t(pkg::req_t), .tag_t(my_tag_t)) u (.*);
endmodule
