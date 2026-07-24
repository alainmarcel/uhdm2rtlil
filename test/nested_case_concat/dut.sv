// Reproduces compressed_decoder.sv: a signal (illegal_o) is conditionally set
// inside a nested unique-case, then read by a TRAILING `if (illegal_o) ...`
// that overrides a wide output.  The frontend threads illegal_o's in-progress
// comb value into the trailing `if` via a mux tree (thread_comb_case) that
// must exactly mirror the nested case — if it yields the wrong value, the
// override wrongly fires and clobbers the decoded output.
module nested_case_concat (
    input  logic [31:0] instr_i,
    output logic [31:0] instr_o,
    output logic        illegal_o
);
    always_comb begin
        illegal_o = 1'b0;
        instr_o   = instr_i;            // default passthrough
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
            default: illegal_o = 1'b1;
        endcase

        // Trailing read of the case-accumulated illegal_o (the crux).
        if (illegal_o) begin
            instr_o = instr_i;
        end
    end
endmodule
