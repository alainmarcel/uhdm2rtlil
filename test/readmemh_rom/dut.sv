// $readmemh initialising a memory from a hex file — the frontend must bake the
// file contents into the memory as $meminit so the synthesized netlist carries
// the same ROM the RTL loads at sim time.
module readmemh_rom (input logic clk, input logic [3:0] adr, output logic [31:0] dat);
  logic [31:0] mem [0:15];
  initial $readmemh("rom.mem", mem);
  always_ff @(posedge clk) dat <= mem[adr];
endmodule
