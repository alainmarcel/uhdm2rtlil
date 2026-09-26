// A dynamic bit-select WRITE into a NESTED struct member,
// `mst_req.w.strb[b + mo - so] = slv_w.strb[b]` -- PULP axi_dw_downsizer's
// W-channel lane steering.  The dynamic struct-field write lowering
// (mask/shift/or on the FIELD slice) accepted only a two-element path
// (`s.field[idx]`); the three-element path fell through to the generic LHS
// import, which ignored the index and wrote the RHS bit over the WHOLE strb
// field (`$0\mst_req [12:5] = {7'0, slv_w[3]}`), so the master strobe carried
// a single lane per beat (co-sim: mst_req_o.w.strb / w_valid from cycle 31).
// The handler now walks the intermediate members, accumulating the offset.
// The slang miter fails without the fix.
typedef struct packed {
  logic [63:0] data;
  logic [7:0]  strb;
  logic        last;
  logic [1:0]  user;
} w_t;
typedef struct packed {
  logic [3:0]  id;
  logic [7:0]  be;
} inner_t;
typedef struct packed {
  inner_t      in;
  logic        ok;
} mid_t;
typedef struct packed {
  w_t   w;
  mid_t m;
  logic w_valid;
  logic b_ready;
} req_t;

module nested_struct_member_dyn_bit_write (
  input  w_t          slv_w,
  input  logic        w_valid_i,
  input  logic [31:0] addr,
  input  logic [2:0]  size,
  input  logic [2:0]  sel,
  output req_t        mst_req_o
);
  req_t mst_req;
  always_comb begin
    mst_req = '0;
    if (w_valid_i) begin
      automatic logic [2:0] mo;
      automatic logic [2:0] so;
      mo = addr[2:0];
      so = addr[5:3];
      mst_req.w_valid = 1'b1;
      mst_req.w.last  = 1'b1;
      mst_req.w.user  = slv_w.user;
      mst_req.w.data  = slv_w.data;
      // Two-level member, loop-variable + locals index.
      for (int b = 0; b < 8; b++) begin
        if ((b >= so) && (b - so < (1 << size)) && (b + mo - so < 8)) begin
          mst_req.w.strb[b + mo - so] = slv_w.strb[b];
        end
      end
      // Three-level member, plain dynamic index.
      mst_req.m.in.be[sel] = 1'b1;
      mst_req.m.ok = 1'b1;
    end
  end
  assign mst_req_o = mst_req;
endmodule
