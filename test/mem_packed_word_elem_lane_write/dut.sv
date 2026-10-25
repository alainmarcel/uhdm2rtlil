// A memory whose WORD is a packed array -- `logic [3:0][7:0] ram [15:0]` --
// written one ELEMENT (byte lane) at a time under a strobe loop:
// `ram[wa][i] <= wd[i]` (adams-bridge abr_1r1w_be_ram).  The memory-write
// partial-select parser took the trailing `[i]` with no range selector as a
// single BIT, so lane i wrote one bit at bit i and the word read back as
// 0...0100 (98 diverging co-simulated cycles, read_slang clean).  The memory
// records its packed geometry (packed_outer_dim), so `[j]` is lane j at
// `j * stride`; a plain word keeps the single-bit meaning.  read_verilog
// handles the shape, so the ordinary workflow is one formal gate and the
// read_slang miter (3 steps: reset, write, read-back, through the memory
// passes) is the other.
module dut (input logic clk, input logic we, input logic [3:0] ws, input logic [3:0] wa,
            input logic [3:0][7:0] wd, input logic re, input logic [3:0] ra, output logic [31:0] rd);
   logic [3:0][7:0] ram [15:0];
   always @(posedge clk) begin
      if (we) begin
         for (int i = 0; i < 4; i++)
            if (ws[i]) ram[wa][i] <= wd[i];
      end
   end
   always @(posedge clk) begin
      if (re) rd <= ram[ra]; else rd <= '0;
   end
endmodule
