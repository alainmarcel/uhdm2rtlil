// read_uhdm must be SILENT by default: its ~1300 debug traces are gated on
// `-debug`.  A bare log() prints on every read -- 99 lines on simple_counter,
// 292 MB in 7 minutes on BlackParrot's bp_unicore (~640 KB/s), which alone
// makes a 125-row core sweep unusable in CI.
//
// The shape below is deliberately ordinary: the point is that ANY design trips
// the trace, and the heaviest emitter is get_width_from_typespec, which every
// port with a typespec walks.  A typedef'd packed port plus a struct field
// read is enough to reach it several times over.
typedef struct packed { logic [7:0] hi; logic [7:0] lo; } pair_t;
typedef logic [3:0] nib_t;

module dut
  #(parameter int W = 8)
   (input  logic        clk,
    input  nib_t [1:0]  idx,
    input  pair_t       pr,
    output logic [W-1:0] sum,
    output logic [7:0]  hi);
  always_ff @(posedge clk)
    sum <= {4'b0, idx[0]} + {4'b0, idx[1]};
  assign hi = pr.hi;
endmodule
