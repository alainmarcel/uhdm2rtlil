// An unpacked array declared INSIDE each for-generate iteration and assigned
// whole with an assignment pattern, then passed to a child through an
// unpacked-array port (OpenTitan acc_alu_bignum:
//   for (genvar i_fg ...) begin : g_flag_groups
//     flags_t flags_d_mux_in [NFlagsSrcs];
//     assign flags_d_mux_in = '{ispr_update_flags[i_fg], ..., flags_q[i_fg]};
//     prim_onehot_mux ... .in_i(flags_d_mux_in) ...
// read_uhdm connected the pattern to UNSCOPED element wires
// `\flags_d_mux_in[k]`: every iteration drove the same wires (conflicting
// drivers) while each iteration's mux input stayed undriven.
module genfor_local_unpacked_array_pattern_assign_mux #(parameter int N = 3, parameter int W = 4) (
  input  logic [W-1:0] in_i [N],
  input  logic [N-1:0] sel_i,
  output logic [W-1:0] out_o
);
  always_comb begin
    out_o = '0;
    for (int k = 0; k < N; k++) out_o |= in_i[k] & {W{sel_i[k]}};
  end
endmodule

package genfor_local_unpacked_array_pattern_assign_pkg;
  typedef struct packed { logic z; logic l; logic m; logic c; } flags_t;
endpackage

module genfor_local_unpacked_array_pattern_assign
  import genfor_local_unpacked_array_pattern_assign_pkg::*;
(
  input  logic [7:0]  a_i,
  input  logic [3:0]  b_i,
  input  logic [7:0]  c_i,
  input  logic [5:0]  sel_i,
  output logic [7:0]  out_o,
  output logic [7:0]  fout_o
);
  for (genvar g = 0; g < 2; g++) begin : g_groups
    logic [3:0] mux_in [3];
    assign mux_in = '{a_i[g*4 +: 4], b_i, c_i[g*4 +: 4]};
    genfor_local_unpacked_array_pattern_assign_mux #(.N(3), .W(4)) u_mux (
      .in_i (mux_in),
      .sel_i(sel_i[g*3 +: 3]),
      .out_o(out_o[g*4 +: 4])
    );
    // Struct-element variant (acc_alu_bignum's `flags_t flags_d_mux_in [5]`).
    flags_t fmux_in [3];
    assign fmux_in = '{flags_t'(a_i[g*4 +: 4]), flags_t'(~b_i), flags_t'(c_i[g*4 +: 4])};
    genfor_local_unpacked_array_pattern_assign_mux #(.N(3), .W(4)) u_fmux (
      .in_i (fmux_in),
      .sel_i(sel_i[g*3 +: 3]),
      .out_o(fout_o[g*4 +: 4])
    );
  end
endmodule
