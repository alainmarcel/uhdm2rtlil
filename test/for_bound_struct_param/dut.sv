// A `for` bound that is a struct-member parameter, in a clocked block.
//
// The sync path's loop-bound reader accepted a plain reference, a constant, a
// function call or an operation -- but not a hier_path, which is what
// `index < P.SIZE` is.  `can_unroll` went false, "Cannot unroll for loop -
// complex pattern" was logged at WARNING level, and the loop's whole body was
// DROPPED: CORE-V Wally's RASPredictor lost the reset arm that clears its
// return-address stack, so the memory mux had only the push term and the stack
// never cleared (188 of 301 co-sim cycles diverged while read_slang was clean).
package cfg;
  typedef struct packed { int SIZE; int XLEN; } cfg_t;
endpackage

module leaf import cfg::*; #(parameter cfg_t P) (
  input  logic clk, input logic clr, input logic [2:0] idx,
  input  logic [P.XLEN-1:0] d, output logic [P.XLEN-1:0] q);
  logic [P.SIZE-1:0][P.XLEN-1:0] mem;
  integer index;
  always_ff @(posedge clk) begin
    if (clr) begin
      for (index = 0; index < P.SIZE; index++) mem[index] <= '0;   // the dropped arm
    end else begin
      mem[idx] <= d;
    end
  end
  assign q = mem[idx];
endmodule

module dut import cfg::*; (input logic clk, input logic clr, input logic [2:0] idx,
                           input logic [63:0] d, output logic [63:0] q);
  localparam int SIZE = 8;
  localparam int XLEN = 64;
  localparam cfg_t P = '{SIZE: SIZE, XLEN: XLEN};
  leaf #(P) u (.clk(clk), .clr(clr), .idx(idx), .d(d), .q(q));
endmodule
