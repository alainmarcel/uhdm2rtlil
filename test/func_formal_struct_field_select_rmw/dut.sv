// A struct FORMAL's field read-modify-written inside a function:
//   req.mem_req_id = {1'b0, req.mem_req_id[0 +: Cfg.u.memIdWidth-1]}; return req;
// (HPDcache's hpdcache_req_write_sel_id / hpdcache_resp_write_sel_id, which
// re-tag the memory request / response ids; the HPDcache flavour of CVA6
// diverged on cva6_hpdcache_wrapper and cva6_hpdcache_subsystem).  Three
// gaps, each enough on its own: the formal's member read with a `[b +: w]`
// / `[k]` tail was never resolved on the staged value (constant X, "Could
// not resolve struct member access"); the field WRITE found no typespec for
// an io_decl actual and was dropped, so `return req` handed back the
// argument; and from a continuous-assign call site the write landed in
// place on the formal's temp -- a combinational loop, read by the return
// before the arm ran.  Both call sites are covered.
package p;
  typedef struct packed { int unsigned memIdWidth; int unsigned other; } user_cfg_t;
  typedef struct packed { user_cfg_t u; int unsigned derived; } cfg_t;
endpackage
module dut #(parameter p::cfg_t Cfg = '{u: '{memIdWidth: 4, other: 7}, derived: 9}) (
  input  logic [Cfg.u.memIdWidth-1:0] id_i,
  input  logic [7:0] addr_i,
  input  logic [1:0] kind_i,
  output logic [Cfg.u.memIdWidth-1:0] id_o,
  output logic [7:0] addr_o,
  output logic [Cfg.u.memIdWidth-1:0] id_a_o
);
  typedef struct packed { logic [Cfg.u.memIdWidth-1:0] mem_req_id; logic [7:0] mem_req_addr; } req_t;
  function automatic req_t sel_id(req_t req, int kind);
    if (kind == 0) begin
      req.mem_req_id = {1'b0, req.mem_req_id[0 +: Cfg.u.memIdWidth-1]};
    end else if (kind == 1) begin
      req.mem_req_id = {1'b1, req.mem_req_id[0 +: Cfg.u.memIdWidth-1]};
    end else if (kind == 2) begin
      req.mem_req_id = '1;
    end
    return req;
  endfunction
  req_t r_i, r_o, r_a;
  assign r_i = '{mem_req_id: id_i, mem_req_addr: addr_i};
  always_comb r_o = sel_id(r_i, int'(kind_i));   // always_comb call site
  assign r_a = sel_id(r_i, int'(kind_i));        // continuous-assign call site
  assign id_o = r_o.mem_req_id;
  assign addr_o = r_o.mem_req_addr;
  assign id_a_o = r_a.mem_req_id;
endmodule
