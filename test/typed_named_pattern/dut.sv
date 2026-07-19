// A TYPED named assignment pattern `T'{field: value, ...}` (RISC-V NOP encoding
// `op32_i_t'{imm_11_0: .., rs1: .., ...}` from rp32 hamster/degu).  Surelog
// emits this as a cast wrapping a concat whose operands alternate
// (member-name ref, value); the field-name keys previously leaked in as
// undriven phantom wires and the whole value collapsed to 0.  The result must
// equal the same pattern written without the type prefix.
package q;
  typedef struct packed { logic opc; logic [1:0] c11; } opcode_t;
  typedef struct packed {
    logic [11:0] imm_11_0;
    logic [4:0]  rs1;
    logic [2:0]  funct3;
    logic [4:0]  rd;
    opcode_t     opcode;
  } op32_i_t;
endpackage

module typed_named_pattern import q::*; (
  output logic [26:0] o_cast,   // typed   T'{...}
  output logic [26:0] o_plain   // untyped   '{...}
);
  localparam op32_i_t NOP_CAST  = op32_i_t'{imm_11_0: 12'h123, rs1: 5'd5, funct3: 3'd2, rd: 5'd9, opcode: '{opc: 1'b1, c11: 2'b11}};
  localparam op32_i_t NOP_PLAIN =           '{imm_11_0: 12'h123, rs1: 5'd5, funct3: 3'd2, rd: 5'd9, opcode: '{opc: 1'b1, c11: 2'b11}};
  assign o_cast  = NOP_CAST;
  assign o_plain = NOP_PLAIN;
endmodule
