// One-hot legalisation for the two `unique case (1'b1)` selects that build
// `mod_intg_d` (otbn_alu_bignum.sv:477 and :490).  The RTL states the
// precondition itself, ten lines below them:
//
//     `ASSERT(ModWrSelOneHot, $onehot0({ispr_init_i, ispr_base_wr_en_i[i_word]}))
//
// Unconstrained random stimulus violates it, and `unique case (1'b1)` has no
// defined meaning multi-hot: the behavioural sim takes the FIRST matching arm,
// the synthesised netlist does not.  Both frontends diverge identically
// (uhdm=slang=217), so this is a stimulus artefact, not a reader bug — the
// same class as ibex_alu / ibex_ex_block.
//
// NOT an X / 4-state problem: every input here is fully DEFINED, just illegal.
// Verified — re-running with `--x-assign unique --x-initial unique` gives the
// identical 217/217, so no X handling changes it.  (Verilator has no 4-state
// mode at all, and iverilog cannot parse this design: OpenTitan's `inside`.)
if (ispr_init_i)         ispr_base_wr_en_i = '0;
if (sec_wipe_mod_urnd_i) begin ispr_init_i = 1'b0; ispr_base_wr_en_i = '0; end
