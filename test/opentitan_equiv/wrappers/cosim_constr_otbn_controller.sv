// One-hot legalisation for the two `unique case (1'b1)` selects over the
// decoded bignum-instruction increment flags (otbn_controller.sv:814, :901).
// A real decoder emits at most ONE of these per instruction; unconstrained
// random stimulus makes them multi-hot, where `unique case (1'b1)` has no
// defined meaning — the behavioural sim takes the first matching arm and the
// synthesised netlist does not.  Both frontends diverged identically
// (uhdm=slang=79) on rf_base_wr_addr_o / rf_base_wr_data_no_intg_o, which are
// assigned inside exactly that case.  Stimulus artefact, not a reader bug.
//
// The tb drives the port as a flat vector, so go through a typed temporary
// rather than hard-coding bit offsets into insn_dec_bignum_t.
begin
  automatic otbn_pkg::insn_dec_bignum_t _idb;
  _idb = otbn_pkg::insn_dec_bignum_t'(insn_dec_bignum_i);
  if (_idb.a_inc) begin
    _idb.b_inc = 1'b0; _idb.d_inc = 1'b0; _idb.a_wlen_word_inc = 1'b0;
  end else if (_idb.b_inc) begin
    _idb.d_inc = 1'b0; _idb.a_wlen_word_inc = 1'b0;
  end else if (_idb.d_inc) begin
    _idb.a_wlen_word_inc = 1'b0;
  end
  insn_dec_bignum_i = _idb;
end
