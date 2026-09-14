// rom_ctrl_scrambled_rom with a DETERMINISTIC 16x40 ROM image (rom_init.vmem,
// $readmemh via prim_rom's MemInitFile): without an image the ROM content is
// unconstrained, so the miter finds a trivial "counterexample" on the read data
// and the RTL co-sim reads uninitialized memory — neither compares anything.
// Path is relative to the per-module work dir (work/<mod>/).  Wrapper-only top.
module rom_ctrl_scrambled_rom_init_flat import prim_rom_pkg::rom_cfg_t; (
  input  logic        clk_i, input logic rst_ni, input logic req_i,
  input  logic  [3:0] rom_addr_i, input logic [3:0] prince_addr_i,
  output logic        rvalid_o, output logic [39:0] scr_rdata_o, output logic [39:0] clr_rdata_o,
  input  rom_cfg_t    cfg_i
);
  rom_ctrl_scrambled_rom #(.MemInitFile("../../rom_init.vmem"), .Width(40), .Depth(16),
    .ScrNonce(64'h0123456789abcdef), .ScrKey(128'hfedcba9876543210_0f1e2d3c4b5a6978)) u (
    .clk_i, .rst_ni, .req_i, .rom_addr_i, .prince_addr_i, .rvalid_o, .scr_rdata_o, .clr_rdata_o, .cfg_i);
endmodule
