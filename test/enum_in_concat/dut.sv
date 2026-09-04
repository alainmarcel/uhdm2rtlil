// Package enum literal wrapped in a single-element concat `{OPC}` nested in a
// bigger concat — Pavona/ibex compressed decoder expansions
// (`{... , ~instr_i[15], {OPCODE_JAL}}`) lost the opcode (low 7 bits = 0).
package eic_pk;
  typedef enum logic [6:0] {
    OPC_JAL  = 7'h6f,
    OPC_LUI  = 7'h37,
    OPC_IMM  = 7'h13
  } opc_e;
endpackage

module enum_in_concat
  import eic_pk::*;
(
  input  logic [1:0]  s,
  output logic [31:0] o_wrapped,
  output logic [31:0] o_bare,
  output logic [31:0] o_case
);
  // enum literal in single-element concat, nested
  assign o_wrapped = {23'h12345, s, {OPC_JAL}};
  // bare enum literal in concat
  assign o_bare    = {23'h12345, s, OPC_LUI};
  // through a unique-case comb (the decoder shape)
  always_comb begin
    unique case (s)
      2'b00:   o_case = {25'h0, {OPC_IMM}};
      2'b01:   o_case = {25'h1, {OPC_JAL}};
      default: o_case = {25'h2, OPC_LUI};
    endcase
  end
endmodule
