// Regression for yosys tests/simple/genblk_dive (CI sharded regression red
// since #790): a continuous assign whose LHS is a GENERATE-SCOPE-relative
// path (`assign B.x = 0` written inside Z.A.B.C, `assign A.x = A.B.C.x`,
// `assign B.C.x = B.x`).  The cross-module-write deferral took the leading
// name for a child instance and parked the assign as an XMR write that never
// resolved, dropping all three drivers: `x` and every generate-block wire
// were left undriven.  A real child-instance XMR write (`u_leaf.flag = ...`)
// is kept next to them so the deferral path is exercised too.
`default_nettype none
module leaf(input wire clk, output wire y);
  wire flag;
  reg q;
  always @(posedge clk) q <= flag;
  assign y = q;
endmodule
module dut(input wire clk, input wire a_i, output wire x, output wire y);
  generate
    if (1) begin : Z
      if (1) begin : A
        wire x;
        if (1) begin : B
          wire x;
          if (1) begin : C
            wire x;
            assign B.x = a_i;
            wire z = A.B.C.x;
          end
          assign A.x = A.B.C.x;
        end
        assign B.C.x = B.x;
      end
    end
  endgenerate
  assign x = Z.A.x;
  leaf u_leaf(.clk(clk), .y(y));
  assign u_leaf.flag = Z.A.B.C.z;
endmodule
`default_nettype wire
