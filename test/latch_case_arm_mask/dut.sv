// Repro of CVA6 csr_regfile `mask` latches: a module-level comb temp written
// then read inside SOME case arms (write-before-read), never defaulted and
// never read elsewhere.  slang SSAs it (0 latches); the UHDM frontend must
// thread the in-flight value into the same-arm reads so no raw-wire read
// remains and the self-hold default is droppable.
module latch_case_arm_mask (
    input  logic [2:0]  addr_i,
    input  logic [15:0] wdata_i,
    input  logic [15:0] q0_i,
    input  logic [15:0] q1_i,
    input  logic        en_i,
    output logic [15:0] d_o
);
  logic [15:0] mask;

  always_comb begin
    d_o = '0;
    unique case (addr_i)
      3'd0: begin
        mask = 16'h00FF;
        d_o  = (q0_i & ~mask) | (wdata_i & mask);
      end
      3'd1: begin
        mask = wdata_i & 16'h0F0F;
        d_o  = (q1_i & ~mask) | (wdata_i & mask);
      end
      3'd2: begin
        if (en_i) begin
          mask = 16'hF000;
          d_o  = (q0_i & ~mask) | (wdata_i & mask);
        end
      end
      default: d_o = q1_i;
    endcase
  end
endmodule
