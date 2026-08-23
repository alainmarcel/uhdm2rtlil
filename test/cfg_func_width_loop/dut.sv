// Compile-time evaluation of fpnew_pkg-style width functions with an
// INSTANCE-OVERRIDDEN format mask (Surelog cannot prefold, so the frontend's
// own evaluator must run).  Covers, in one chain (each was a real fpu_wrap /
// fpnew_fma bug):
//   - `**` (vpiPowerOp) in the compile-time evaluator;
//   - element+member select on a PACKED array of structs parameter
//     (`ENC[i].e` — fpnew's FP_ENCODINGS[fmt].exp_bits read as 0, so every
//     bias folded to -1);
//   - a bare `i++` for-loop increment statement (silently no-oped: the loop
//     spun to the iteration limit and every width folded to 0);
//   - `if (cfg[i])` — a bit-select as an if condition (evaluated as empty ->
//     false, body never ran);
//   - SV index -> bit mapping for the ASCENDING `[0:N-1]` mask type.
package q;
  localparam int unsigned NF = 3;
  typedef logic [0:NF-1] mask_t;
  typedef struct packed {
    int unsigned e;
    int unsigned m;
  } enc_t;
  localparam enc_t [0:NF-1] ENC = '{'{4, 3}, '{3, 2}, '{2, 1}};

  function automatic int unsigned fwidth(int unsigned i);
    return unsigned'(2 ** (ENC[i].e - 1) - 1) + ENC[i].m;
  endfunction

  function automatic int unsigned maxw(mask_t cfg);
    automatic int unsigned res = 0;
    for (int unsigned i = 0; i < NF; i++)
      if (cfg[i])
        if (fwidth(i) > res) res = fwidth(i);
    return res;
  endfunction
endpackage

module sub #(
    parameter q::mask_t M = '0
) (
    input  logic [q::maxw(M)-1:0] a,
    output logic [31:0]           o,
    output logic [q::maxw(M)-1:0] b
);
  assign o = q::maxw(M);
  assign b = ~a;
endmodule

module cfg_func_width_loop (
    input  logic [9:0]  a_i,
    output logic [31:0] o,
    output logic [9:0]  b_o
);
  // M = 3'b101 on [0:2]: fmt0 (w=10) and fmt2 (w=2) enabled -> maxw = 10.
  sub #(.M(3'b101)) u (.a(a_i), .o(o), .b(b_o));
endmodule
