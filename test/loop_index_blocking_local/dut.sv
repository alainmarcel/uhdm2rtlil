// An array index that is a BLOCKING-ASSIGNED local, constant per unrolled
// iteration, was not resolved -- so every write took the dynamic per-element
// path and the cost went QUADRATIC in the array length.
//
//     for (a = 0; a < 8; a++)
//       for (w = 0; w < 16; w++) begin
//         i = a*16 + w;          // constant per iteration
//         tab[i] = ...;          // ... but imported as a VARIABLE index
//       end
//
// One such write emits a compare and a mux for each of N elements, N times
// over.  Writing `tab[a*16+w]` inline was always cheap; only the intermediate
// variable hit it, so the two halves of this test are semantically identical
// and used to differ by 129x in cell count (33024 vs 256 at N=128).
//
// In the wild: CORE-V Wally's fdivsqrtuslc4 is 113 lines that declare
// `logic [3:0] USel4[1023:0]` and fill it from a nested loop exactly this way.
// read_uhdm peaked at 10.5 GB on it and died with
// `UHDM: Exception in process import: std::bad_alloc`; with --jobs 2 on a
// 16 GB CI runner that took the whole runner down, and the external-IP
// nightly had been red for six nights straight because of it.  After the fix
// the same module peaks at 0.37 GB.
//
// The fix resolves a bit-select's INDEX against the in-flight blocking values,
// which is what the semantics call for anyway: a blocking assignment is
// visible immediately.
module loop_index_blocking_local (
  input  logic [6:0] idx_i,
  output logic [3:0] o_via,      // index through an intermediate variable
  output logic [3:0] o_inline    // the same index written inline
);
  logic [3:0] tab_via[127:0];
  logic [3:0] tab_inline[127:0];

  always_comb begin
    integer a, w, i;
    for (a = 0; a < 8; a++)
      for (w = 0; w < 16; w++) begin
        i = a*16 + w;
        tab_via[i] = 4'(a) ^ 4'(w);
      end
  end

  always_comb begin
    integer a, w;
    for (a = 0; a < 8; a++)
      for (w = 0; w < 16; w++)
        tab_inline[a*16 + w] = 4'(a) ^ 4'(w);
  end

  assign o_via    = tab_via[idx_i];
  assign o_inline = tab_inline[idx_i];
endmodule
