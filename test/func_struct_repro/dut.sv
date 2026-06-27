typedef struct packed { logic [4:0] opc; logic [31:0] imm; } dec_t;
function automatic dec_t mydec (logic [31:0] op);
  mydec.opc = op[6:2];
  mydec.imm = {{20{op[31]}}, op[31:20]};
endfunction
module func_struct_repro (input logic [31:0] instr, output logic [4:0] opc, output logic [31:0] imm);
  dec_t d; assign d = mydec(instr);
  assign opc = d.opc; assign imm = d.imm;
endmodule
