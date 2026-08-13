// Repro of CVA6 compressed_decoder illegal-passthrough bug: a blocking flag
// defaulted at block top, conditionally set inside NESTED case/if arms, then
// read by a TRAILING if in the same always_comb.  The trailing read must see
// the in-flight (post-case) value; UHDM read a stale value so
// `if (illegal) instr_o = instr_i` never fired (slang/LRM: it fires).
module comb_flag_after_case (
    input  logic [7:0] instr_i,
    output logic [7:0] instr_o,
    output logic       illegal_o
);
  always_comb begin
    illegal_o = 1'b0;
    instr_o   = 8'h00;
    unique case (instr_i[1:0])
      2'b00: begin
        unique case (instr_i[3:2])
          2'b00:   instr_o = 8'h11;
          2'b01: begin
            if (instr_i[7:4] == '0) illegal_o = 1'b1;
            else instr_o = 8'h22;
          end
          default: illegal_o = 1'b1;
        endcase
      end
      2'b01: instr_o = 8'h33;
      default: begin
        if (instr_i[7]) illegal_o = 1'b1;
        else instr_o = 8'h44;
      end
    endcase

    if (illegal_o) begin
      instr_o = instr_i;
    end
  end
endmodule
