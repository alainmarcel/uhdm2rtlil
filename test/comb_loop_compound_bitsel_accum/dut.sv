// A compound assignment (`|=`) onto a BIT-SELECT of a packed vector, indexed
// by an unrolled loop variable, accumulating over an inner loop:
//
//     for (int entry ...) begin
//       we[entry] = '0;
//       for (int client ...)
//         we[entry] |= (entry_i[client] == entry) & en_i[client];
//     end
//
// This is the AND-OR write-enable mux of caliptra-rtl's key vault
// (`key_entry_ctrl_we[entry] |= ...` over KV_NUM_WRITE clients).
//
// import_assignment_comb() has several fast paths for select-shaped LHS that
// emit and return BEFORE the generic compound-operator handling; the one for a
// packed-vector select with a (loop-)constant index imported the bare RHS, so
// `we[entry] |= t_k` became `we[entry] = t_k` and only the LAST client's term
// survived.  In the key vault four of five clients' writes were never
// enabled.  The same defect sat in the expanded-array element-write fast paths
// and the dynamic-index per-element mux; all now fold the target's current
// in-flight value with the operator, as the generic path already did.
//
// `we2` is the 2-D form: a two-index packed select goes through a different
// fast path (emit_dynamic_packed_select_write), which took only the RHS node
// and so could not see the operator at all.
//
// Every accumulator (|=, &=, ^=) is observable at the output.  Localparams
// (not module parameters) and plain packed vectors keep the top
// synthesisable by the Yosys Verilog frontend too, so the check is a real
// formal equivalence rather than a constant comparison.
module dut (
  input  logic [2:0]          en_i,
  input  logic [2:0][2:0]     entry_i,
  input  logic [2:0][3:0]     data_i,
  input  logic [7:0]          lock,
  output logic [7:0]          we,        // |= accumulate
  output logic [7:0]          all_hit,   // &= accumulate
  output logic [7:0][3:0]     par,       // ^= accumulate on an element slice
  output logic [7:0][1:0]     we2        // |= accumulate on a 2-D packed select
);
  localparam int N_ENT = 8;
  localparam int N_CLI = 3;
  always_comb begin
    for (int entry = 0; entry < N_ENT; entry++) begin
      we[entry]      = '0;
      all_hit[entry] = 1'b1;
      par[entry]     = '0;
      for (int dword = 0; dword < 2; dword++)
        we2[entry][dword] = '0;
      for (int client = 0; client < N_CLI; client++) begin
        we[entry]      |= (entry_i[client] == entry) & en_i[client] & ~lock[entry];
        all_hit[entry] &= (entry_i[client] == entry);
        par[entry]     ^= (entry_i[client] == entry) ? data_i[client] : 4'h0;
        // 2-D packed select target: caliptra's
        //   key_entry_we[entry][dword] |= (...write_entry == entry) & (...write_offset == dword) & ...
        for (int dword = 0; dword < 2; dword++)
          we2[entry][dword] |= (entry_i[client] == entry) & (data_i[client][0] == dword) & en_i[client];
      end
    end
  end
endmodule
