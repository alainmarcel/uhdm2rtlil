// A memory bit that is only ever WRITTEN with a constant.  opt_mem (first step
// of the `memory` script) folds such a bit to that constant because the memory
// has no initialiser -- legal under X-init, but a frontend whose write-port
// data is a mux with a 0 default (read_uhdm's process lowering) keeps the bit,
// and the two netlists then disagree on a read-before-write under
// `-set-init-zero`.  The miter must map memories WITHOUT opt_mem and zero
// their words before optimising, so both sides start from the same state.
// (The constant comes from a package: read_verilog's own memory lowering
// folds the same bit, so its equivalence check is not comparable here and
// the read_slang miter is the gate.)
package p;
  localparam logic ONE = 1'b1;
endpackage
module top import p::*; (input logic clk, input logic we, input logic addr, input logic [6:0] d, input logic raddr, output logic [7:0] q);
  logic [7:0] mem [1:0];
  always_ff @(posedge clk) if (we) mem[addr] <= {ONE, d};
  assign q = mem[raddr];
endmodule
