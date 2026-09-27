// A part-select of a nested struct member whose bound is a package function
// call, read inside a GENERATE scope:
//   mst_port_offset = r_req_q.ar.addr[idx_width(AxiMstPortStrbWidth)-1:0]
// (PULP axi_dw_downsizer's lane steering).  Surelog leaves the bound
// unevaluated and stamps the member name as `addr[ - 1:0]`; the gen-scope
// path of the nested-member resolver parsed the range from that TEXT, got
// nothing, and returned the WHOLE 32-bit address as the byte offset, so
// every lane condition `b >= offset` was false and no data byte was ever
// steered (co-sim: R data zero from the first beat).  The same read at
// module scope, or into a local narrow enough to truncate the address,
// happened to come out right.  The range is now resolved from the
// hier_path's own part_select node with its bounds folded.
// The slang miter fails without the fix.
package math_pkg;
  function automatic int unsigned idx_width (input int unsigned num_idx);
    if (num_idx > 32'd1) begin
      return unsigned'($clog2(num_idx));
    end else begin
      return 32'd1;
    end
  endfunction
endpackage

import math_pkg::idx_width;
typedef struct packed {
  logic [3:0]  id;
  logic [31:0] addr;
  logic [7:0]  len;
} ar_t;
typedef struct packed {
  ar_t  ar;
  logic ar_valid;
} req_t;

module genscope_member_partsel_func_bound #(parameter int unsigned DataW = 64) (
  input  logic        clk_i, rst_ni,
  input  req_t        r_d,
  output logic [31:0] off_o,
  output logic [31:0] hi_o
);
  localparam int unsigned StrbW = DataW / 8;
  for (genvar t = 0; t < 1; t++) begin : g
    req_t r_q;
    always_ff @(posedge clk_i or negedge rst_ni)
      if (!rst_ni) r_q <= '0; else r_q <= r_d;
    always_comb begin
      off_o = '0;
      hi_o  = '0;
      if (r_q.ar_valid) begin
        automatic logic [31:0] mo;
        automatic logic [31:0] hi;
        mo = StrbW == 1 ? '0 : r_q.ar.addr[idx_width(StrbW)-1:0];
        hi = r_q.ar.addr[31 -: idx_width(StrbW)];
        off_o = mo;
        hi_o  = hi;
      end
    end
  end
endmodule
