// A struct field that is itself a PACKED array of structs, read by element on
// an element of an unpacked struct array: `pipeReg[i].microOps[j]` on RSD's
// `OpInfo [MICRO_OP_MAX_NUM-1:0] microOps` inside DecodeStageRegPath.  The
// element-array struct field handler knew unpacked-array and two-range logic
// fields but not a packed_array_typespec field, so `[j]` selected BIT j of the
// field: every micro-op the decode stage handed on was its valid bit (280
// co-sim divergences, read_slang clean).  12-bit elements make it visible.
package sfpaep;
  typedef struct packed { logic valid; logic [6:0] a; logic [3:0] b; } OpInfo;            // 12 bits
  typedef struct packed { logic valid; logic [3:0] pc; OpInfo [1:0] microOps; } DecReg;    // 29 bits
endpackage
module struct_field_packed_array_elem(input logic [57:0] pipe_in, input logic sel, output logic [11:0] r0, output logic [11:0] r1, output logic [11:0] rs);
  import sfpaep::*;
  DecReg pipeReg [2];
  always_comb begin
    pipeReg[0] = pipe_in[28:0]; pipeReg[1] = pipe_in[57:29];
    r0 = pipeReg[0].microOps[1];
    r1 = pipeReg[1].microOps[0];
    rs = pipeReg[1].microOps[sel];
  end
endmodule
