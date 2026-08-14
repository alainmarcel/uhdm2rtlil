// Repro: part-select with a NON-ZERO declared low bound on a struct field
// reached through a packed UNION (`instr.rftype.rs2[22:20]` where rs2 is
// declared `logic [24:20]`).  The nested-field part-select handler treated
// the select bounds as 0-based, overshot the bounds check (offset 20 + lsb 20
// > 32) and fell back to decodeHierPath, which collapsed the 3-bit slice to a
// single bit.  CVA6 decoder's FCVT source-format check
// `unique case (instr.rftype.rs2[22:20])` then accepted illegal encodings.
typedef struct packed {
  logic [31:25] funct7;
  logic [24:20] rs2;
  logic [19:15] rs1;
  logic [14:12] rm;
  logic [11:7]  rd;
  logic [6:0]   opcode;
} rftype_t;

typedef struct packed {
  logic [31:20] imm;
  logic [19:15] rs1;
  logic [14:12] funct3;
  logic [11:7]  rd;
  logic [6:0]   opcode;
} itype_t;

typedef union packed {
  logic [31:0] instr;
  rftype_t     rftype;
  itype_t      itype;
} instruction_t;

module union_field_partsel (
    input  logic [31:0] instr_i,
    output logic        ill_o,
    output logic [2:0]  fmt_o,
    output logic [1:0]  hi2_o,
    output logic        bit_o
);
  instruction_t instr;
  assign instr = instr_i;
  always_comb begin
    ill_o = 1'b0;
    fmt_o = instr.rftype.rs2[22:20];
    hi2_o = instr.rftype.rs2[24:23];
    bit_o = instr.rftype.rs2[21];
    unique case (instr.rftype.rs2[22:20])
      3'b000: ;
      3'b001: ;
      default: ill_o = 1'b1;
    endcase
  end
endmodule
