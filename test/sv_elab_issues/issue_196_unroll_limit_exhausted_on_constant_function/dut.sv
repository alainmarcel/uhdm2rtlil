// povik/sv-elab#196 (closed): Unroll limit exhausted on constant function bounds
// https://github.com/povik/sv-elab/issues/196
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// multioperand_accumulator.sv

module multioperand_accumulator #(
    parameter int NUM_OPERANDS = 64,
    parameter int NEXT_STAGE_FANIN = 4
) (
    output  logic [31:0] dummy_o
);

localparam int NumStages = int'($ceil($ln(1.0*NUM_OPERANDS) / $ln(1.0*NEXT_STAGE_FANIN)));

function automatic int NumOperandsPerStage(int stage);
    if (stage == 0) return NUM_OPERANDS;
    return (NEXT_STAGE_FANIN**(NumStages-stage));
endfunction

`ifndef SYNTHESIS
for (genvar stage_GEN = 0; stage_GEN < NumStages; stage_GEN++) begin
    $info("Stage %0d takes %0d operands", stage_GEN, NumOperandsPerStage(stage_GEN));
end
`endif

always_comb begin
    dummy_o = 0;
    for (int stage = 0; stage < NumStages; stage++) begin
        for (int operand = 0; operand < NumOperandsPerStage(stage); operand++) begin
            dummy_o++;
        end
    end
end

endmodule

