// Nested struct-field read on a LOCAL struct variable (`d.gpr.rs1`).  The
// variable's wire exists in name_map but its UHDM object may be absent from
// wire_map, so the struct typespec must be recovered from the base ref_obj's
// Actual_group (the variable declaration).  Mirrors the degu core reading the
// decoded register enables `idu_dec.gpr.rs1` / `.rs2`.
package p;
  typedef struct packed { logic rd; logic rs1; logic rs2; } ena_t;
  typedef struct packed { logic [6:0] opc; ena_t gpr; } dec_t;
endpackage

module top (input logic [31:0] instr, output logic e1, output logic e2);
  import p::*;
  dec_t d;
  assign d = '{opc: instr[6:0], gpr: '{rd: instr[0], rs1: instr[1], rs2: instr[2]}};
  assign e1 = d.gpr.rs1;   // = instr[1]
  assign e2 = d.gpr.rs2;   // = instr[2]
endmodule
