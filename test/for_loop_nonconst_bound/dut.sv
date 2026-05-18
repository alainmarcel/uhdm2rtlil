// Reproducer for chipsalliance/synlig#581 — a procedural `for` loop
// whose 2nd expression (the termination condition) depends on a
// runtime signal rather than a constant.  Lifted from orv64's
// `rtl/orv64/orv64_ptw_core.sv:207` (the page-table-walker's
// superpage check):
//
//   for (int i = 0; i < rff_lvl; i++) begin // superpage
//     if (ppn_parts[i] != '0) begin
//       next_excp_valid = '1;
//       ...
//
// where `rff_lvl` is an `orv64_ptw_lvl_t` register
// (`$clog2(ORV64_NUM_PAGE_LEVELS)` bits, 2 bits when LVL_CNT=3) and
// `ppn_parts[]` is an `ORV64_NUM_PAGE_LEVELS`-element array of
// `ppn_part_t` (9-bit each).  Yosys's AST frontend rejects this with
//   "2nd expression of procedural for-loop is not constant!"
// because it can't statically unroll the loop.
//
// The fix has to unroll the loop up to the maximum value the bound
// can take (bounded by the bit width of the bound signal — at most
// 2**B - 1 iterations for a B-bit unsigned bound), wrapping each
// iteration's body in a `(i < bound)` runtime guard so iterations
// past the runtime bound are nops.
//
// This DUT mirrors the orv64 dimensions:
//
//   * `lvl` (`LVL_W` bits) is the runtime bound (`rff_lvl`)
//   * `parts` (`NUM_LVL` × `PART_W`) is the array (`ppn_parts`)
//   * `excp_valid` is observable — set high if any of
//     parts[0..lvl-1] is non-zero
//
// `excp_valid` is a function of `lvl` and `parts`, so a Verilator
// co-sim sweep catches the bound-clamp behaviour.
module for_loop_nonconst_bound #(
    parameter int NUM_LVL = 3,
    parameter int LVL_W   = $clog2(NUM_LVL + 1),
    parameter int PART_W  = 9
) (
    input  logic [LVL_W-1:0]                  lvl,
    input  logic [NUM_LVL-1:0][PART_W-1:0]    parts,
    output logic                              excp_valid
);
    always_comb begin
        excp_valid = 1'b0;
        for (int i = 0; i < lvl; i++) begin // superpage
            if (parts[i] != '0) begin
                excp_valid = 1'b1;
            end
        end
    end
endmodule
