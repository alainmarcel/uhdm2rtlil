// YosysHQ/yosys#1064 (closed): Fails to SAT solve, but why?
// https://github.com/YosysHQ/yosys/issues/1064
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module regfile2r1w_alt
  (input                   clk
  ,input [4-1:0]          waddr0
  ,input                  we0
  ,input [7-1:0]          din0
  ,input [4-1:0]          raddr0
  ,output [7-1:0]         q0
  ,output [7-1:0]         q1
  );

  reg [7-1:0] rf[2-1:0];

  reg [7-1:0] q0_next;
  always_comb begin
    if (we0 && raddr0 == waddr0)
      q0_next = din0;
    else
      q0_next = rf[raddr0];
  end

  always @(posedge clk) begin
    q0 <= q0_next;
  end

  always @(posedge clk) begin
    q1 <= q0_next;
  end

  always @(posedge clk) begin
    if (we0) begin
      rf[waddr0] <= din0;
    end
  end

endmodule

