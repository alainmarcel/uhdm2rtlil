// OpenTitan prim_multibit_sync with NumChecks = 1: `logic [NumChecks-1:0]
// [Width-1:0] data_check_q` is a packed 2-D array with ONE row, and
// `data_check_d[NumChecks:1] = data_check_q[NumChecks-1:0]` is a ROW range on
// it.  A single-row array got no packed-geometry tag, so its `[0:0]` range
// was read as bit 0: the synchronizer's consistency check never passed and
// caliptra-ss dev_entropy's rate register never updated (46 of 301 co-sim
// cycles).  The slang miter is the gate; `ycheck` reads the row by element.
module dut #(parameter int NumChecks = 1, parameter int Width = 4) (
  input  [Width-1:0] a, input [Width-1:0] q0,
  output [(NumChecks+1)*Width-1:0] y, output [Width-1:0] ycheck, output [Width-1:0] yrow);
  logic [NumChecks:0][Width-1:0]   d;
  logic [NumChecks-1:0][Width-1:0] cq;    // ONE row when NumChecks == 1
  assign cq = q0;
  assign d[0] = a;
  assign d[NumChecks:1] = cq[NumChecks-1:0];
  assign y = d;
  assign ycheck = d[NumChecks];
  assign yrow = cq[0:0];
endmodule
