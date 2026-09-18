// Regression for CVA6 commit_stage (`csr_wdata_o[4:0]` wrong, the module's
// per-module miter went from proven to counterexample).
//
//   csr_wdata_o = {{XLEN-5{1'b0}}, commit_instr_i[0].ex.cause[4:0]};
//
// Surelog gives that read THREE path elements — bit_select(commit_instr_i[0]),
// ref_obj(ex), part_select named `cause` — so the handler for
// `arr[idx].field[hi:lo]` fired but used only the OUTER member's offset: it
// read `ex`'s low bits instead of `cause`'s, 65 bits away.  The part-select's
// own name is the member it slices, so a differing name means the path is
// nested and both offsets count.
package p;
  typedef struct packed {
    logic [63:0] cause;
    logic [63:0] tval;
    logic        valid;
  } exc_t;
  typedef struct packed {
    exc_t        ex;
    logic [63:0] result;
    logic [2:0]  fu;
  } sbe_t;
endpackage

// The type comes in as a type parameter, exactly as commit_stage receives it.
module inner #(parameter type scoreboard_entry_t = logic) (
  input  scoreboard_entry_t [1:0] commit_instr_i,
  input  logic                    sel,
  output logic [63:0]             csr_wdata_o,
  output logic [63:0]             tval_o
);
  always_comb begin
    csr_wdata_o = '0;
    tval_o      = '0;
    if (sel) begin
      csr_wdata_o = {{64 - 5{1'b0}}, commit_instr_i[0].ex.cause[4:0]};
      tval_o      = {{64 - 8{1'b0}}, commit_instr_i[1].ex.tval[7:0]};
    end
  end
endmodule

module dut import p::*; (
  input  sbe_t [1:0]  ci,
  input  logic        sel,
  output logic [63:0] o,
  output logic [63:0] t
);
  inner #(.scoreboard_entry_t(sbe_t)) u (
    .commit_instr_i(ci), .sel(sel), .csr_wdata_o(o), .tval_o(t));
endmodule
