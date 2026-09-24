// One-hot legalisation, same class and same design as the OpenTitan twin
// (opentitan_equiv/wrappers/cosim_constr_otbn_alu_bignum.sv).  This module
// declares the precondition FIVE times:
//
//   `ASSERT(ModWrSelOneHot,     $onehot0({ispr_init_i, ispr_base_wr_en_i[i_word]}))
//   `ASSERT(KmacCfgWrSelOneHot, …)  KmacPWWrSelOneHot / KmacMsg0/1WrSelOneHot
//
// Unconstrained random stimulus violates it, and the `unique case (1'b1)`
// selects it guards then have no defined meaning: behavioural sim takes the
// FIRST matching arm, the synthesised netlist does not.  Both frontends
// diverge (uhdm=161, slang=166) — a stimulus artefact, not a reader bug.
if (ispr_init_i)         ispr_base_wr_en_i = '0;
if (sec_wipe_mod_urnd_i) begin ispr_init_i = 1'b0; ispr_base_wr_en_i = '0; end
