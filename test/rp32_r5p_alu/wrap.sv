// Test harness: drive r5p_alu with a VALID decoded instruction by running a
// random 32-bit instruction word through the design's own decoder dec32().
// r5p_alu takes `dec_t dec` as a port; random struct bits hit no opcode (RTL
// default vs netlist divergence), so decode first.
module r5p_alu_dec_wrap
  import riscv_isa_pkg::*;
  import riscv_isa_i_pkg::*;
(
  input  logic        clk,
  input  logic        rst,
  input  logic [31:0] instr,
  input  logic [31:0] pc,
  input  logic [31:0] rs1,
  input  logic [31:0] rs2,
  output logic [31:0] rd,
  output logic [32:0] sum
);
  localparam isa_t ISA = '{spec: RV32I, priv: MODES_NONE};
  dec_t dec;
  assign dec = dec32(ISA, instr);
  r5p_alu alu (.clk, .rst, .dec, .pc, .rs1, .rs2, .rd, .sum);
endmodule
