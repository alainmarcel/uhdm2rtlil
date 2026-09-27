// A dynamic bit-select READ of a NESTED struct member,
// `slv_req_i.w.strb[b + slv_port_offset - mst_port_offset]` -- PULP
// axi_dw_upsizer's W-channel lane steering.  The nested-member slice
// handler took only a constant index; a dynamic one fell through to the
// generic hier-path decoder, which returned the field's first bit, so the
// upsized strobe lanes were wrong (miter: mst_req_o.w.strb[7]).  A
// single-level `w.strb[idx]` already worked.  The handler now shifts the
// FIELD slice by the index, mapped through the member's declared range.
// The slang miter fails without the fix.
typedef struct packed {
  logic [63:0] data;
  logic [7:0]  strb;
  logic        last;
  logic [1:0]  user;
} w_t;
typedef struct packed {
  w_t   w;
  logic w_valid;
  logic b_ready;
} req_t;
typedef struct packed {
  logic [7:0]     lo;
  logic [8:15]    asc;     // ascending declared range
  logic [3:0][3:0] nib;    // packed-array member: one element per index
} odd_t;
typedef struct packed {
  odd_t o;
  logic v;
} outer_t;

module nested_struct_member_dyn_bit_read (
  input  req_t        slv_req_i,
  input  outer_t      x_i,
  input  logic [2:0]  so, mo,
  input  logic [2:0]  ai,
  input  logic [1:0]  ni,
  output logic [7:0]  strb_o,
  output logic        asc_o,
  output logic [3:0]  nib_o
);
  always_comb begin
    strb_o = '0;
    for (int b = 0; b < 8; b++)
      if (b + so - mo < 8)
        strb_o[b] = slv_req_i.w.strb[b + so - mo];
  end
  assign asc_o = x_i.o.asc[{1'b1, ai}];   // always in the declared [8:15] range
  assign nib_o = x_i.o.nib[ni];
endmodule
