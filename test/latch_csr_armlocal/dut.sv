// Repro of CVA6 csr_regfile.sv:968 arm-local latches (`index`, `DirVecOnly`,
// `$unnamed_block$N.index`): a block-local variable DECLARED INSIDE A CASE ARM
// and unconditionally assigned there before use.  Promoted to a module-level
// wire, it is written only when its arm is selected -> self-hold default
// survives on every other arm -> spurious latch (slang SSAs arm-locals; the
// variable is never read outside its arm, so the latch is dead but noisy).
module latch_csr_armlocal (
    input  logic [1:0]  addr_i,
    input  logic [11:0] waddr_i,
    input  logic [63:0] wdata_i,
    input  logic        dirveconly_cfg_i,
    output logic [63:0] r_o
);
  always_comb begin : csr_update
    r_o = '0;
    unique case (addr_i)
      2'd0: begin
        automatic logic [3:0] index;
        index = waddr_i[3:0] - 4'd2;
        r_o   = wdata_i >> index;
      end
      2'd1: begin
        automatic logic [11:0] index;
        index = waddr_i - 12'd16;
        r_o   = wdata_i << index[3:0];
      end
      2'd2: begin
        logic DirVecOnly;
        DirVecOnly = dirveconly_cfg_i ? 1'b0 : wdata_i[0];
        r_o = {wdata_i[63:2], 1'b0, DirVecOnly};
        if (DirVecOnly) r_o = {wdata_i[63:8], 7'b0, DirVecOnly};
      end
      default: r_o = wdata_i;
    endcase
  end
endmodule
