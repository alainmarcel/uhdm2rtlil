// Byte-enable writes into a 3-D PACKED register file, unrolled from a loop
// inside an ASYNC-RESET always_ff -- snitch's register_file_3r_2w_be:
//   else if (WriteEnable) for (int i = 0; i < NUM_BYTE; i++)
//     if (WriteBE[i]) Mem[WriteAddr][i] <= WriteData[i];
// Each byte is a dynamic packed-select write under its own `if (be[i])` arm;
// the second byte's read-modify-write must start from the FIRST byte's
// pending value, not the registered word, or the first byte is clobbered.
module dut(input logic clk, input logic rst_n, input logic we, input logic [1:0] wa,
           input logic [1:0][7:0] wd, input logic [1:0] be,
           input logic [1:0] ra, output logic [15:0] rd);
  logic [3:0][1:0][7:0] mem;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) mem <= '0;
    else if (we)
      for (int i = 0; i < 2; i++)
        if (be[i]) mem[wa][i] <= wd[i];
  assign rd = mem[ra];
endmodule
