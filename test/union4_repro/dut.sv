typedef struct packed { logic [1:0] hilo; logic [4:0] opc; } opcode_t;
typedef struct packed { logic [4:0] rs2; logic [4:0] rs1; logic [4:0] rd; logic [6:0] f7; opcode_t opcode; } r_t;
typedef union packed { r_t r; logic [31:0] raw; } u_t;
typedef struct packed { logic [4:0] o; logic [26:0] pad; } d_t;
function automatic d_t mydec (u_t op);
  mydec.o   = op.r.opcode.opc;
  mydec.pad = op.raw[26:0];
endfunction
module union4_repro (input logic [31:0] instr, output logic [4:0] o);
  d_t d; assign d = mydec(instr);
  assign o = d.o;
endmodule
