// `initial if (MemInitFile != "") begin : gen_meminit $readmemh(MemInitFile, mem); end`
// — OpenTitan's prim_util_memload.svh shape, reached through a paramod
// (MemInitFile passed from the parent).  The $readmemh scanner could not enter
// a named_begin (it cast it to `begin`), so the ROM stayed uninitialised and
// rom_ctrl's scrambled ROM read 0 for every word.  init.vmem sits next to
// this file; the importer resolves the path relative to the source.
module rom_named_begin_readmemh_rom #(parameter MemInitFile = "") (
  input logic clk_i, input logic [1:0] addr_i, output logic [7:0] rdata_o);
  logic [7:0] mem [4];
  always_ff @(posedge clk_i) rdata_o <= mem[addr_i];
  initial begin
    if (MemInitFile != "") begin : gen_meminit
      $readmemh(MemInitFile, mem);
    end
  end
endmodule
module rom_named_begin_readmemh (input logic clk_i, input logic [1:0] addr_i, output logic [7:0] rdata_o);
  rom_named_begin_readmemh_rom #(.MemInitFile("init.vmem")) u (.clk_i, .addr_i, .rdata_o);
endmodule
