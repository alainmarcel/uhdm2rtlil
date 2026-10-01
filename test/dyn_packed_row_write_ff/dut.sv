// A dynamic ROW write into a PACKED array under a clock.
//
// `logic [P.SIZE-1:0][P.XLEN-1:0] memory; memory[idx] <= d;` is one flat wire --
// no element wires, no `$mem` -- and importing that LHS as an expression yields
// the READ of the row (a `$shiftx` output).  The write then landed on that aux
// wire and `memory` was never driven at all: CORE-V Wally's RASPredictor
// reported 1024 undriven bits and `RASPCF` stuck at 0, 194 cycles diverging
// from the RTL while read_slang was clean.
//
// Both halves are gated here: the sync rule must update `\memory` itself, and
// the value must be the row-masked read-modify-write.
package cfg;
  typedef struct packed { int XLEN; int SIZE; } cfg_t;
endpackage

module leaf import cfg::*; #(parameter cfg_t P) (
  input logic clk, input logic [2:0] idx, input logic [P.XLEN-1:0] d,
  output logic [P.XLEN-1:0] q);
  // 2-D PACKED array, both dimensions from struct-member parameters -- cvw's
  // RASPredictor `logic [P.RAS_SIZE-1:0][P.XLEN-1:0] memory`.
  logic [P.SIZE-1:0][P.XLEN-1:0] memory;
  always_ff @(posedge clk) memory[idx] <= d;
  assign q = memory[idx];
endmodule

module dut import cfg::*; (input logic clk, input logic [2:0] idx,
                           input logic [63:0] d, output logic [63:0] q);
  localparam int XLEN = 64;
  localparam int SIZE = 8;
  localparam cfg_t P = '{XLEN: XLEN, SIZE: SIZE};
  leaf #(P) u (.clk(clk), .idx(idx), .d(d), .q(q));
endmodule
