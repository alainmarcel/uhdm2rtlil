typedef struct packed {
  logic [6:0] f7; logic [4:0] rs2; logic [4:0] rs1;
  logic [2:0] f3; logic [4:0] rd;  logic [6:0] opc;
} r_t;
typedef union packed { r_t r; logic [31:0] raw; } u_t;
typedef struct packed { logic [4:0] rdo; logic [6:0] opco; } d_t;
function automatic d_t mydec (u_t op);
  mydec.rdo  = op.r.rd;
  mydec.opco = op.r.opc;
endfunction
module union_param_repro (input logic [31:0] instr, output logic [4:0] rdo, output logic [6:0] opco);
  d_t d; assign d = mydec(instr);
  assign rdo = d.rdo; assign opco = d.opco;
endmodule
