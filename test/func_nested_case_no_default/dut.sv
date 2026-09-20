// A function whose case arm contains a NESTED case with no default arm left
// its inlined $result wire UNDRIVEN on every path the inner case does not
// cover.
//
//     function automatic cause_t cause_f (lvl_e level);
//       unique casez (typ)
//         T_A: cause_f = C_BRK;
//         T_B: unique case (level)      // <-- no default arm
//           L_U: cause_f = C_UC;
//           ...
//         endcase
//         default: cause_f = C_BRK;
//       endcase
//     endfunction
//
// When a case ARM contains a nested case, the inliner creates an intermediate
// "value this arm falls back to" wire and seeds the result from it.  With no
// default arm in the nested case nothing ever drove that wire, so the
// uncovered paths read a wire with no driver at all.
//
// A function's return variable starts at X per the LRM, so the intermediate is
// now driven with X; any nested arm that does assign overrides it.  The VALUES
// are unchanged -- read_uhdm already agreed with read_slang on every path,
// which is why this only ever showed up as an undriven-net count.
//
// rp32_r5p_csr's `cause_f` is this exact shape and left a 32-bit $result
// undriven at each of three call sites: 96 undriven nets, the whole of that
// module's opt-check column.
//
// o_flat is the control: the same function WITHOUT nesting was always fine.
// o_withdef covers a nested case that HAS a default and must stay correct.
//
// The OUTER default arms return a concrete constant rather than 'x, and the
// stimulus is constrained to legal enum values, so the design has no X path at
// runtime: an `'x` arm reads as 0 in Verilator but is a don't-care the
// synthesised netlist folds into a neighbouring value, which diverges on every
// output -- including the controls -- and says nothing about this bug.  The
// undriven net under test is structural and present either way.
package p;
  typedef enum logic [1:0] { T_A = 2'd0, T_B = 2'd1, T_C = 2'd2 } typ_e;
  typedef enum logic [1:0] { L_U = 2'd0, L_S = 2'd1, L_M = 2'd3 } lvl_e;
  typedef logic [31:0] cause_t;
  localparam cause_t C_BRK = 32'hAA, C_UC = 32'h11, C_SC = 32'h22, C_MC = 32'h33;
endpackage

module func_nested_case_no_default import p::*; (
  input  logic [1:0] typ_i,
  input  logic [1:0] lvl_i,
  output cause_t     o_nested,    // nested case, NO default  <- the bug
  output cause_t     o_withdef,   // nested case, WITH default (control)
  output cause_t     o_flat       // no nesting               (control)
);
  function automatic cause_t cause_f (lvl_e level, typ_e t);
    unique casez (t)
      T_A: cause_f = C_BRK;
      T_B: unique case (level)
        L_U: cause_f = C_UC;
        L_S: cause_f = C_SC;
        L_M: cause_f = C_MC;
      endcase
      default: cause_f = C_BRK;
    endcase
  endfunction

  function automatic cause_t cause_def_f (lvl_e level, typ_e t);
    unique casez (t)
      T_A: cause_def_f = C_BRK;
      T_B: unique case (level)
        L_U: cause_def_f = C_UC;
        L_S: cause_def_f = C_SC;
        default: cause_def_f = C_MC;
      endcase
      default: cause_def_f = C_BRK;
    endcase
  endfunction

  function automatic cause_t cause_flat_f (typ_e t);
    unique casez (t)
      T_A: cause_flat_f = C_BRK;
      T_B: cause_flat_f = C_UC;
      default: cause_flat_f = C_BRK;
    endcase
  endfunction

  // Constrain the random stimulus to LEGAL enum values.  `unique casez` on an
  // out-of-range value is undefined behaviour -- Verilator resolves it
  // differently from synthesis, which shows up as a co-sim divergence on every
  // output including the controls, and would say nothing about this bug.  The
  // undriven net is STRUCTURAL (the nested case has no default arm) and is
  // present regardless of stimulus, so constraining the inputs costs no
  // coverage of the thing under test.
  typ_e t_q;
  lvl_e l_q;
  always_comb begin
    unique case (typ_i)
      2'd0:    t_q = T_A;
      2'd1:    t_q = T_B;
      default: t_q = T_C;
    endcase
    unique case (lvl_i)
      2'd0:    l_q = L_U;
      2'd1:    l_q = L_S;
      default: l_q = L_M;
    endcase
  end

  assign o_nested  = cause_f(l_q, t_q);
  assign o_withdef = cause_def_f(l_q, t_q);
  assign o_flat    = cause_flat_f(t_q);
endmodule
