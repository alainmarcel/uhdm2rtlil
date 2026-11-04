// A struct member written through a PACKED ARRAY-OF-STRUCT element
// (`l.ops[1].ew16 = ...`) on a variable declared INSIDE A GENERATE BLOCK:
// spatz_ipu's gen_64b_ipu distributor fills `lane_signal_inp.ops[k].ew8[j]`,
// `.ew16` and `.ew32` per element width.  The nested-tail resolver looked the
// base up by its BARE name, which a generate-scope variable does not have
// (its wire is `\g1.l`), so every such write and read was unresolved and the
// SIMD lanes received all-zero operands.  Plain members (`f.ew16`) were fine.
// read_verilog cannot lower a member write through an array-of-struct element
// (it drops the write), so the gates are the read_slang miter and a value proof.
module dut(input logic [31:0] a, output logic [55:0] q1, output logic [55:0] q2, output logic [47:0] q3);
  typedef struct packed { logic [1:0][7:0] ew8; logic [15:0] ew16; logic [31:0] ew32; } ops_t;
  typedef struct packed { ops_t [2:0] ops; } lane_t;
  typedef struct packed { logic [15:0] ew16; logic [31:0] ew32; } flat_t;
  // module-level typedef, variable in a generate block
  if (1) begin : g1
    lane_t l;
    always_comb begin l = '0; l.ops[1].ew16 = a[15:0]; l.ops[0].ew32 = a; l.ops[2].ew8[1] = a[15:8]; end
    assign q1 = l.ops[1];
    assign q3 = {l.ops[2].ew8, l.ops[0].ew32};
  end
  // typedef AND variable in the generate block
  if (1) begin : g2
    typedef struct packed { logic [1:0][7:0] ew8; logic [15:0] ew16; logic [31:0] ew32; } ops2_t;
    typedef struct packed { ops2_t [2:0] ops; } lane2_t;
    lane2_t l;
    always_comb begin l = '0; l.ops[1].ew16 = a[15:0]; end
    assign q2 = l.ops[1];
  end
endmodule
