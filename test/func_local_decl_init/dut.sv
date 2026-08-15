// CVA6 store_unit data_align repros (dynamic SSA function inline):
// 1. A function-local whose ONLY assignment is its DECLARATION INITIALIZER
//    (`logic [2:0] a_tmp = {a[2], a[1:0]};`) — Surelog emits it as a body
//    assignment whose LHS is the logic_var itself (not a ref_obj); the
//    inliner skipped it and the local stayed X.
// 2. A PART/BIT-SELECT write to a function local (`d_tmp[62:0] = …`) — the
//    inliner resolved no LHS name and dropped the write silently.
typedef struct packed {
  logic        valid;
  logic [63:0] vaddr;
  logic [63:0] data;
} lsu_t;

module func_local_decl_init (
  input  logic        amo,
  input  lsu_t        lsu,
  output logic [63:0] st_data_n
);
  logic [63:0] endian_data;
  assign endian_data = lsu.data;

  function automatic [63:0] data_align(logic [2:0] a, logic [63:0] d);
    logic [2:0]  a_tmp = {a[2], a[1:0]};
    logic [63:0] d_tmp = {64{1'b0}};
    case (a_tmp)
      3'b000: d_tmp = d;
      3'b010: d_tmp = {d[47:0], d[63:48]};
      3'b011: begin
        d_tmp[62:0] = {d[38:0], d[63:40]};
        d_tmp[63]   = d[39];
      end
      default: d_tmp = {d[7:0], d[63:8]};
    endcase
    data_align = d_tmp;
  endfunction

  always_comb begin
    st_data_n = (amo ? endian_data[63:0]
                     : data_align(lsu.vaddr[2:0], {endian_data}));
  end
endmodule
