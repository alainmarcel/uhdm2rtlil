// Reproduces compressed_decoder.sv on two fronts:
//
// (1) thread_comb_case/if: a signal (illegal_o) set inside a nested case/if is
//     read by a TRAILING `if (illegal_o) instr_o = instr_i;`.  The frontend
//     threads illegal_o's in-progress comb value into that `if`; if the thread
//     mux is wrong the override wrongly fires and clobbers the decoded output.
//
// (2) emit_full_case_default: the OUTER `unique case` has an explicit
//     `default:` that sets is_comp_o = 0 (the "uncompressed" arm) but does NOT
//     assign instr_o — so instr_o must HOLD its block default `instr_o =
//     instr_i` (passthrough).  X-ing it in the full_case default made every
//     uncompressed input decode to X (masked before by a buggy always-true
//     trailing `if`).  Here illegal_o stays 0 for that arm, so nothing masks a
//     wrong passthrough — the miter catches it.
module nested_case_concat (
    input  logic [31:0] instr_i,
    output logic [31:0] instr_o,
    output logic        illegal_o,
    output logic        is_comp_o
);
    always_comb begin
        illegal_o = 1'b0;
        is_comp_o = 1'b1;
        instr_o   = instr_i;            // block default: passthrough
        unique case (instr_i[1:0])
            2'b00: begin
                unique case (instr_i[15:13])
                    3'b000: begin
                        instr_o = {2'b0, instr_i[10:7], instr_i[12:11], instr_i[5],
                                   instr_i[6], 12'h041, instr_i[4:2], 7'h13};
                        if (instr_i[12:5] == 8'b0) illegal_o = 1'b1;
                    end
                    3'b010: begin
                        instr_o = {5'b0, instr_i[5], instr_i[12:10], instr_i[6],
                                   4'b0001, instr_i[9:7], 5'b01001, instr_i[4:2], 7'h03};
                    end
                    default: illegal_o = 1'b1;
                endcase
            end
            2'b01: instr_o = {instr_i[15:0], 16'h0001};
            2'b10: instr_o = {16'h0002, instr_i[15:0]};
            // Uncompressed: does NOT touch instr_o (must hold instr_i) nor illegal_o.
            default: is_comp_o = 1'b0;
        endcase

        // Trailing read of the case-accumulated illegal_o (the crux of (1)).
        if (illegal_o) begin
            instr_o = instr_i;
        end
    end
endmodule
