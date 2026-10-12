// A function FORMAL whose name matches a MODULE SIGNAL ARRAY, where the call's
// result is assigned to that very array.
//
// A bit-select of the formal inside the function body fell through to the
// expanded-array path and asked the MODULE array for the element at the
// formal's bit index.  That element does not exist (the array has 2 entries,
// the index was 18), so the select returned X: the MSB of every result was X,
// the array went X, and the later read of it diverged.
//
// Reduced from RSD: `ToAddrFromPC(PC_Path pc)` (MemoryMapTypes.sv:55-62) reads
// `pc[PC_WIDTH-1]` in its body, while IntegerExecutionStage declares
// `AddrPath pc [INT_ISSUE_WIDTH]` and assigns the call's result to `pc[i]`
// (IntegerExecutionStage.sv:92,153).  The branch-target else arm then read
// `pc[i]` and came out X, so the row diverged on all 301 co-simulated cycles
// while read_slang was clean.
//
// Both ingredients are needed: with the result assigned to a different signal,
// or with no call at all, the reader is already correct.  The part-select of
// the formal (`pc[PW-2:0]`) always worked -- only the bit-select was wrong, so
// a test must keep a BIT-select of the formal.
// The function lives in a PACKAGE, as RSD's does: the formal's VpiFullName is
// then `PipelineTypes::ToAddrFromPC::pc` with `::` separators, not
// `ToAddrFromPC.pc`.  A file-scope version of this test passes even when the
// scope test only understands '.', so the package form is the one that gates.
package PipelineTypes;
    localparam AW = 32, PW = 19;
    function automatic [AW-1:0] ToAddrFromPC (input [PW-1:0] pc);
        ToAddrFromPC = { pc[PW-1], {(AW-PW){1'b0}}, pc[PW-2:0] };
    endfunction
endpackage

import PipelineTypes::*;

module func_formal_shadowed_by_array (
    input  logic [PW-1:0] src0, src1,
    output logic [AW-1:0] o0, o1
);
    logic [PW-1:0] src [2];
    logic [AW-1:0] pc  [2];         // SAME NAME as ToAddrFromPC's formal
    always_comb begin
        src[0] = src0;
        src[1] = src1;
        for (int i = 0; i < 2; i++) begin
            pc[i] = ToAddrFromPC(src[i]);
        end
        o0 = pc[0];
        o1 = pc[1];
    end
endmodule
