// An `initial` block that writes CONSTANT SLICES of a register -- a bit, or a
// whole write followed by a slice -- is a set of init values:
//
//     initial r_op_pc[0] = 1'b0;                      // ZipCPU zipcore
//     initial begin s = '0; s[7:4] = 4'hA; end
//
// The reader sent any partial-write initial block down the comb path, whose
// process ends in `sync always`: each slice became a CONTINUOUS driver of
// the constant that fought the register's own flop.  zipcore, zipaxi,
// zipaxil, zipbones and zipsystem all failed their miter with "Conflicting
// init values" and `check` reported driver-driver conflicts on the same
// bits.  read_verilog emits `init` attributes with the other bits undefined;
// so does the sync path once the slices of one wire are merged.
module dut(input clk, input [3:0] d, output reg [3:0] r, output reg [7:0] s);
  initial r[0] = 1'b0;
  always @(posedge clk) r <= d;
  initial begin s = '0; s[7:4] = 4'hA; end
  always @(posedge clk) s <= {d, d};
endmodule
