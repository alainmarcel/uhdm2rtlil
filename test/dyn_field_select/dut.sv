// A struct member that is itself indexed by a RUNTIME value, reached through a
// run of dynamic array indices.  CVA6 bht2lvl:
//   bht_q[index][i].saturation_counter[read_history[i]][1]
// The importer gave up on the dynamic field index and dropped the whole
// continuous assign, leaving that output bit UNDRIVEN.
package p;
  typedef struct packed {
    logic       valid;
    logic [1:0] hist;
    logic [3:0][1:0] sat;      // 4 x 2-bit -- indexed at RUNTIME
  } entry_t;
endpackage

module dut (
    input  logic        row_i,
    input  logic        col_i,
    input  logic [1:0]  sel_i,
    input  logic [95:0] flat_i,
    output logic        taken_o,     // dynamic field index + trailing const bit
    output logic [1:0]  cnt_o,       // dynamic field index, whole element
    output logic        valid_o,     // sibling field, no select  (control)
    output logic        const_o      // same field, CONSTANT index (control)
);
  p::entry_t [1:0][1:0] tbl;
  assign tbl = flat_i;

  assign taken_o = tbl[row_i][col_i].sat[sel_i][1];
  assign cnt_o   = tbl[row_i][col_i].sat[sel_i];
  assign valid_o = tbl[row_i][col_i].valid;
  assign const_o = tbl[row_i][col_i].sat[2][0];
endmodule
