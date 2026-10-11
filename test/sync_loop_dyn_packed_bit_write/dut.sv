// RSD Scheduler: `vec[dyn] <= bit` on a PACKED vector inside the always_ff
// LOOP path (the `if (rst) ... else for (i) if (wr[i]) ...` shape).  That path
// imported the LHS as an expression -- for a dynamic bit select that is the
// $shiftx READ -- so the update landed on an anonymous wire and the vectors
// had NO DRIVER AT ALL: isInt / isComplex / isDiv / isLoad / isStore / isFP /
// isFPDivSqrt, the 112 bits the sweep reported as "never assigned in the
// source".
module sync_loop_dyn_packed_bit_write(input logic clk, input logic rst,
  input logic [1:0] wr, input logic [3:0] ptr_f, input logic [1:0] kind,
  output logic [3:0] notIssued, output logic [3:0] isStore, output logic [3:0] isLoad);
  logic [1:0] ptr [2];
  always_comb for (int i = 0; i < 2; i++) ptr[i] = ptr_f[i*2 +: 2];
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 4; i++) begin
        notIssued[i] <= 1'b0;
      end
    end
    else begin
      for (int i = 0; i < 2; i++) begin
        if (wr[i]) begin
          notIssued[ ptr[i] ] <= 1'b1;
          if (kind[i]) begin
            isStore[ ptr[i] ] <= 1'b1;
            isLoad[ ptr[i] ] <= 1'b0;
          end
          else begin
            isStore[ ptr[i] ] <= 1'b0;
            isLoad[ ptr[i] ] <= 1'b1;
          end
        end
      end
    end
  end
endmodule
