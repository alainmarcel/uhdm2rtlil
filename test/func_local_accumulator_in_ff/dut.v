// EXPECTED FAIL -- a tracked reproducer, not a passing test.
//
// A function-local `reg` ACCUMULATED into by successive blocking assignments
//
//     result = input_0 & {9{sel[0]}};
//     result = result | (input_1 & {9{sel[1]}});   // <- reads itself
//     result = result | (input_2 & {9{sel[2]}});
//
// is bound by the function-call inliner to ONE staging wire with no SSA
// staging between the statements.  In a COMB context the current_comb_values
// threading hides that -- each read is rewritten onto the previously computed
// value -- but inside a CLOCKED process that threading is deliberately
// suppressed (`in_always_ff_body_mode`, so a register read observes its
// pre-edge value), and with nothing rewriting the read the wire's own `$or`
// cell reads the wire being written: a combinational loop.
//
// MEASURED:
//   * read_uhdm emits 9 logic loops here; read_slang emits 0.
//   * NVDLA's NV_NVDLA_SDP_CORE_Y_cvt_core has 120 of them against
//     read_slang's 0, and co-simulates wrong from cycle 14 on
//     `chn_out_rsc_z`.  Catapult writes every MUX1HOT_* helper this way, so
//     NV_NVDLA_SDP_CORE_Y_cvt (16 diverging cycles), _cvt_core (7) and
//     NV_NVDLA_SDP_MRDMA_EG_dout are the three NVDLA leads that the
//     function-declaration-section parameter fix did NOT close.
//
// WHAT NARROWS IT (all measured, so the next attempt need not re-derive it):
//   * a continuous `assign z = MUX1HOT(...)` call site is CLEAN (0 loops) --
//     the clocked / non-blocking context is required;
//   * the async-reset arm is NOT required: `always @(posedge clk)` with a
//     plain `if (en)` still gives 9 loops;
//   * rewriting the body to use DISTINCT locals (`r2 = result | ...;
//     r3 = r2 | ...`) gives 0 loops, which pins the defect to the read of a
//     local on the RHS of its OWN re-assignment.
//
// WHERE IT IS NOT.  THREE fixes were tried and all three REVERTED after
// measuring no change -- the loop count stayed at 9 every time:
//
//   1. thread tf locals in `emit_comb_assign` and stop suppressing them in
//      `remap_inflight_read` (keyed on the unmapped `\<fn>.result` name);
//   2. same, re-keyed on the MAPPED `$0\...$func$...` spelling that
//      `mapped_inflight()` consults;
//   3. record the value in `import_assignment_comb` right after the RHS is
//      size-matched (keyed on the LHS wire's own `$func$` name) AND relax
//      `mapped_inflight()` to accept the inliner's `$1\` prefix as well as
//      `$0\`.
//
// So neither `emit_comb_assign` nor `import_assignment_comb` carries these
// writes, and the read is not reaching `mapped_inflight()` either.  The next
// attempt should stop patching candidate sites and first PROVE which emitter
// produces the three `assign $1\<call>.$result$<n> ...` actions -- the
// staging wires are allocated by the function-call inliner at
// functions.cpp:2395, so instrument there and follow the body statements down.
// That is the same mistake-shape as the documented FP32PipelinedOther concat
// fix, which also took three wrong sites before the real one.
module dut(clk, rst_n, en, i0, i1, i2, sel, q);
   input clk, rst_n, en;
   input  [8:0] i0, i1, i2;
   input  [2:0] sel;
   output reg [8:0] q;

   always @(posedge clk or negedge rst_n) begin
     if (!rst_n)      q <= 9'b0;
     else if (en)     q <= MUX1HOT(i2, i1, i0, sel);
   end

   function [8:0] MUX1HOT;
     input [8:0] input_2;
     input [8:0] input_1;
     input [8:0] input_0;
     input [2:0] sel;
     reg   [8:0] result;
   begin
     result = input_0 & {9{sel[0]}};
     result = result | ( input_1 & {9{sel[1]}});
     result = result | ( input_2 & {9{sel[2]}});
     MUX1HOT = result;
   end
   endfunction
endmodule
