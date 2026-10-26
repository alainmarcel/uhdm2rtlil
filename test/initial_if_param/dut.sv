// An `initial` block whose control flow is decided by PARAMETERS:
//
//     initial if (OPT_INITIAL) o_data = 0;
//
// is how every ZipCPU register gets its power-on value (rtl/ex/skidbuffer.v and
// the rest of the core).  It is control flow, so the reader sent it down the
// comb path, whose process ends in a `sync always` rule -- a CONTINUOUS driver
// of the constant.  The always block that really updates the register lost to
// it: `opt` folded the register to the constant and removed the flop.  The
// skidbuffer's o_data read 0 on 300 of 301 co-simulated cycles, and five
// ZipCPU tops failed their miter with "Conflicting init values" on the same
// registers.  read_verilog folds the constant `if` and emits `sync init` with
// the literal; so must we.
module dut #(
  parameter [0:0] OPT_INITIAL = 1'b1,
  parameter [0:0] OPT_LOWPOWER = 1'b0,
  parameter       RESET_VALUE = 8'h5A
) (
  input            clk,
  input            rst,
  input            en,
  input      [7:0] d,
  output reg [7:0] q,
  output reg [7:0] r,
  output reg       v
);
  // the ZipCPU shape: one if, no else
  initial if (OPT_INITIAL) q = 0;
  always @(posedge clk)
    if (rst)     q <= 0;
    else if (en) q <= d;

  // if / else, nested begin blocks, a parameter on the right-hand side
  initial begin
    if (OPT_LOWPOWER) begin
      r = 8'hFF;
      v = 1'b0;
    end else begin
      r = RESET_VALUE;
      if (OPT_INITIAL) v = 1'b1;
    end
  end
  always @(posedge clk) begin
    if (en) r <= d ^ q;
    v <= en;
  end
endmodule
