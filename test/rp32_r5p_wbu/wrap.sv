// Test harness: drive r5p_wbu's `dec` struct port with a VALID decoded
// instruction (random 32-bit word -> dec32()), so the random co-sim stimulus
// forms real instructions instead of arbitrary struct bits.
module r5p_wbu_dec_wrap
  import riscv_isa_pkg::*;
  import riscv_isa_i_pkg::*;
(
  input  logic        clk,
  input  logic        rst,
  input  logic [31:0] instr,
  input  logic [31:0] alu,
  input  logic [31:0] lsu,
  input  logic [31:0] pcs,
  input  logic [31:0] lui,
  input  logic [31:0] csr,
  input  logic [31:0] mul,
  output logic        wen,
  output logic [4:0]  adr,
  output logic [31:0] dat
);
  localparam isa_t ISA = '{spec: RV32I, priv: MODES_NONE};
  dec_t dec;
  assign dec = dec32(ISA, instr);
  r5p_wbu wbu (.clk, .rst, .dec, .alu, .lsu, .pcs, .lui, .csr, .mul, .wen, .adr, .dat);
endmodule
