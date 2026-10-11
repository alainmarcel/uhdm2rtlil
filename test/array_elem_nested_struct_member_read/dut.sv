// RSD DispatchStage: `opInfo[i].operand.intOp.shiftIn` -- a member of a packed
// UNION member of a struct, read through an element of an unpacked array.
typedef struct packed { logic [3:0] a1; logic [3:0] a2; } int_t;
typedef struct packed { logic [1:0] b1; logic [5:0] b2; } mem_t;
typedef union packed { int_t intOp; mem_t memOp; } operand_t;
typedef struct packed { logic [1:0] cond; operand_t operand; logic t; } opinfo_t;
module array_elem_nested_struct_member_read(input logic [21:0] x, output logic [7:0] y1, output logic [11:0] y2, output logic [1:0] y3);
  opinfo_t opInfo [2];
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      opInfo[i] = x[i*11 +: 11];
      y1[i*4 +: 4] = opInfo[i].operand.intOp.a1;
      y2[i*6 +: 6] = opInfo[i].operand.memOp.b2;
      y3[i] = opInfo[i].t;
    end
  end
endmodule
