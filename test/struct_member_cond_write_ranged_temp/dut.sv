// A struct MEMBER written both unconditionally (the default) and conditionally
// (inside an unrolled loop) by the same always_comb.
//
// The unconditional write creates a per-process temp registered under a key
// that carries the RANGE (`out_o[1:1]`), and the sync rule updates the real
// wire from it.  The conditional write looked the temp up by the BARE name,
// missed it, and landed on the full-width `$0\out_o` (or on the real wire) --
// so every conditional write was dropped and the member stayed at its
// default.  `out_o.y` here was the constant 0 regardless of `sel_i`.
//
// Reduced from PULP axi_demux_simple's
//   slv_resp_o.w_ready = 1'b0;
//   for (i..) if (w_select_valid && (w_select == i))
//               slv_resp_o.w_ready = mst_resps_i[i].w_ready;
// which stuck the demux's W-channel ready at 0 for every master port, and was
// the last divergence between read_uhdm and read_slang on axi_id_serialize.
typedef struct packed { logic x; logic y; logic z; } s_t;

module struct_member_cond_write_ranged_temp #(
  parameter int unsigned N = 4
) (
  input  logic [1:0]   sel_i,
  input  logic [N-1:0] in_i,
  input  logic         other_i,
  output s_t           out_o
);
  // writes ONE member: constant default + loop-unrolled conditional write
  always_comb begin
    out_o.y = 1'b0;
    for (int unsigned i = 0; i < N; i++) begin
      if (sel_i == i) begin
        out_o.y = in_i[i];
      end
    end
  end

  // a second process writes the OTHER members of the same struct, so the
  // signal is only ever partially owned by each process
  always_comb begin
    out_o.x = other_i;
    out_o.z = ~other_i;
  end
endmodule
