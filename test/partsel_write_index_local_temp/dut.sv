// An indexed part-select WRITE whose offset reads BLOCKING temps of the same
// block, inside an unrolled for (YosysHQ/yosys#4363's nibble shuffle):
// `x = n % 2; o = n / 2; di[(16*x)+(4*o) +: 4] = wr[4*n +: 4];`.  The offset
// was imported against the raw temp wires, looked dynamic, and the
// read-modify-write read the block's own output: a combinational loop, and q
// read X.  One block-local and one module-level set of temps.
module dut (input  logic [31:0] wr,
            output logic [31:0] q, r, rb);
  always @(*) begin : map
    integer n, x, o;
    for (n = 0; n < 8; n = n + 1) begin
      x = n % 2;
      o = n / 2;
      q[(16*x)+(4*o) +: 4] = wr[4*n +: 4];
    end
  end

  integer m, xm, om;
  logic [31:0] di;
  always @(*) begin
    for (m = 0; m < 8; m = m + 1) begin
      xm = m % 2;
      om = m / 2;
      di[(16*xm)+(4*om) +: 4] = wr[4*m +: 4];
      rb[4*m +: 4] = di[(16*xm)+(4*om) +: 4];   // read back through the same temps
    end
  end
  assign r = di;
endmodule
