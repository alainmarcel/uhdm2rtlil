// N == 2**$bits(sel_i) on purpose: an OUT-OF-RANGE unpacked-array read is
// undefined behaviour and simulators legitimately differ, which would swamp
// the behaviour under test.
// A parameter that is an UNPACKED ARRAY of a STRUCT type, indexed at runtime.
// This is how cvxif's instr_decoder is configured (`parameter copro_issue_resp_t
// CoproInstr [NbInstr]`), and reading an element's fields is what went to zero.
package pk;
  typedef struct packed {
    logic [7:0] tag;
    logic [3:0] code;
    logic       accept;
  } entry_t;

  parameter int N = 4;
  parameter entry_t TBL[N] = '{
      '{tag: 8'hA1, code: 4'h5, accept: 1'b1},
      '{tag: 8'hB2, code: 4'h6, accept: 1'b0},
      '{tag: 8'hC3, code: 4'h7, accept: 1'b1},
      '{tag: 8'hD4, code: 4'h8, accept: 1'b0}
  };
endpackage

module dut (
    input  logic       clk_i,
    input  logic [1:0] sel_i,
    input  logic [7:0] tag_i,
    output logic [7:0] tag_o,
    output logic [3:0] code_o,
    output logic       accept_o,
    output logic       hit_o
);
  import pk::*;

  // element selected by a runtime index
  assign tag_o    = TBL[sel_i].tag;
  assign code_o   = TBL[sel_i].code;
  assign accept_o = TBL[sel_i].accept;

  // the decoder pattern: compare an input against every entry
  logic [N-1:0] match;
  always_comb begin
    for (int i = 0; i < N; i++) match[i] = (TBL[i].tag == tag_i);
  end
  assign hit_o = |match;
endmodule
