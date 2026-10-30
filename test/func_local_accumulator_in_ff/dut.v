// A function-local `reg` ACCUMULATED into by successive blocking assignments
//
//     result = input_0 & {9{sel[0]}};
//     result = result | (input_1 & {9{sel[1]}});   // <- reads itself
//     result = result | (input_2 & {9{sel[2]}});
//
// called from a CLOCKED process.
//
// `scan_for_return_variables` treats a local assigned to the function name
// (`MUX1HOT = result;`) as a RETURN VARIABLE and ALIASES it onto the
// function's single result staging wire, so the `MUX1HOT = result` copy costs
// nothing.  That is sound for a write-once local and wrong for an
// accumulator: every statement then writes that one wire and the statement's
// own `$or` cell reads it back.  A comb call site hides it, because the
// current_comb_values threading rewrites each read onto the previous value;
// inside a clocked process that threading is deliberately suppressed
// (`in_always_ff_body_mode`, so a register read observes its pre-edge value)
// and what is left is a COMBINATIONAL LOOP -- 9 of them here, against
// read_slang's 0.
//
// Catapult writes every MUX1HOT_* helper this way, so NVDLA paid for it:
// NV_NVDLA_SDP_CORE_Y_cvt diverged on 16 co-simulated cycles and
// NV_NVDLA_SDP_CORE_Y_cvt_core on 7 (with 120 logic loops), both read_slang
// clean.  Aliasing is now skipped for a self-accumulated return variable, so
// the ordinary SSA renaming applies and the explicit return assignment
// copies the final value onto the result chain.
//
// GATES: `test_structural.ys` runs `check -assert`, which fails on the loop;
// the value is gated by this test's ordinary read_verilog equivalence check.
//
// THREE earlier fix attempts were reverted after measuring no change (the
// loop count stayed at 9 every time): threading tf locals in
// `emit_comb_assign` / `remap_inflight_read` keyed on the unmapped name, the
// same re-keyed on the mapped `$0\...$func$...` spelling, and recording the
// value in `import_assignment_comb` with a relaxed `mapped_inflight()`
// prefix.  None of those sites carries these writes.  What found it was
// instrumenting the ONE emitter that does -- `process_stmt_to_case`'s
// assignment case -- and printing the LHS name beside its mapped wire:
//     SSAENTER lhs='result' mapped=$1\MUX1HOT$func$dut.v:63$3.$result$10
//     SSAPROBE lhs=result   excluded=1
// which showed the local was bound to the RESULT wire and that SSA renaming
// was then declined by the `.$result` NAME test.  Probe the emitter, do not
// patch the candidates.
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
