// Reading a BIT of a struct field of an element of a parameter that is an
// unpacked array of structs: `TBL[i].flags[b]`.
//
// The path is hier_path[bit_select(TBL,i), ref_obj(flags), bit_select(b)] --
// the trailing element is a bit_select rather than a plain field reference,
// and treating that as "not a field chain" abandons the whole access, which
// then reads as zero.  cvxif's instr_decoder gates issue_ready_o on exactly
// this shape (`CoproInstr[i].resp.register_read[2]`).
package pk;
  typedef struct packed {
    logic [7:0] tag;
    logic [3:0] flags;
  } entry_t;

  parameter int N = 4;
  parameter entry_t TBL[N] = '{
      '{tag: 8'hA1, flags: 4'b1101},
      '{tag: 8'hB2, flags: 4'b0010},
      '{tag: 8'hC3, flags: 4'b0111},
      '{tag: 8'hD4, flags: 4'b1000}
  };
endpackage

module dut (
    input  logic       clk_i,
    input  logic [1:0] sel_i,
    input  logic [1:0] bit_i,   // 2 bits vs a 4-bit field: always in range
    output logic       const_bit_o,
    output logic       dyn_bit_o,
    output logic [3:0] all_flags_o,
    output logic       ready_o
);
  import pk::*;

  // constant bit index of a field of a dynamically selected element
  assign const_bit_o = TBL[sel_i].flags[2];
  // dynamic bit index too
  assign dyn_bit_o   = TBL[sel_i].flags[bit_i];
  assign all_flags_o = TBL[sel_i].flags;

  // the cvxif gating shape: a loop-constant element, bit of a vector field
  always_comb begin
    ready_o = 1'b0;
    for (int unsigned i = 0; i < N; i++)
      if (i == sel_i) ready_o = ~TBL[i].flags[0] || TBL[i].flags[1];
  end
endmodule
