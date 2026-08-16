// CVA6 cva6_tlb tags_q/content_q repros (anonymous packed struct array):
// 1. SURELOG: `struct packed { a; b; } [N-1:0] x;` LOST the outer [N-1:0]
//    whenever the struct has MORE THAN ONE member — compileTypespec skipped
//    only a single Struct_union_member sibling before looking for the
//    Packed_dimension, so the net collapsed to ONE element (cva6_tlb's
//    4-entry TLB became 1 entry; entries 1-3 read X → no hits).
// 2. Element WRITE `q_n[i] = {…}` wrote a SINGLE BIT instead of the full
//    element: import_bit_select's element-width detection had no branch for
//    a packed_array_typespec on a plain net (cva6_tlb's update path never
//    stored a TLB entry).
// 3. Multi-index field READ `tags_q[i].is_page[2-x][0:0]` (2D packed member
//    of the anonymous-struct element, genvar indices): the N-index hier_path
//    branch had no var_select tail and flat_struct_array_geom no
//    packed_array_typespec-on-net shape (cva6_tlb page_match read X).
// 4. Range select of the LAST dim of a plain 3D packed vector
//    `vvm[i][0][2:x]` (var_select whose last index is a part_select node):
//    the packed multi-dim branch bailed on the non-const import and the
//    read collapsed to one wrong bit (cva6_tlb vaddr_level_match).
typedef struct packed {
  logic [7:0] ppn;
  logic       g;
  logic       v;
} pte_t;

module anon_struct_packed_dim (
  input  logic [39:0] din,
  input  logic [3:0]  en,
  output logic [3:0]  o_g,
  output logic [7:0]  o_ppn,
  output logic [39:0] o_all,
  output logic [39:0] o_q,
  output logic [3:0]  o_pm,
  output logic [11:0] o_lvl
);
  struct packed {
    pte_t pte;
    pte_t gpte;
  } [1:0] content_q, q_n;

  assign content_q = din;
  assign o_all = content_q;

  always_comb begin
    o_g = '0;
    for (int unsigned i = 0; i < 2; i++) begin
      o_g[i] = content_q[i].pte.g;
    end
    o_ppn = content_q[0].gpte.ppn;
  end

  // element write (cva6_tlb tags_n[i] = {...}) + per-field else write
  always_comb begin
    q_n = '0;
    for (int unsigned i = 0; i < 2; i++) begin
      if (en[i]) begin
        q_n[i] = {din[19:12], din[11], din[10], din[9:2], din[1], din[0]};
      end else begin
        q_n[i].pte.v = 1'b0;
      end
    end
  end
  assign o_q = q_n;

  // 2D packed member + genvar indices + [0:0] part-select (page_match shape);
  // reuses the pte fields: ppn[7:0] read as ppn[x][0:0] windows via 2 dims
  struct packed {
    logic [15:0]     vpn;
    logic [1:0][0:0] is_page;
    logic            valid;
    logic            pad;
  } [1:0] tq;
  assign tq = din;
  for (genvar gi = 0; gi < 2; gi++) begin : g_i
    for (genvar gx = 1; gx < 3; gx++) begin : g_x
      assign o_pm[gi*2+gx-1] = &(tq[gi].is_page[2-gx][0:0] | (~en[0]));
    end
  end

  // plain 3D packed vector, range select of the last dim by genvar
  logic [3:0][0:0][2:0] vvm;
  assign vvm = din[11:0];
  for (genvar li = 0; li < 4; li++) begin : l_i
    for (genvar lx = 0; lx < 3; lx++) begin : l_x
      assign o_lvl[li*3+lx] = &vvm[li][0][2:lx];
    end
  end
endmodule
