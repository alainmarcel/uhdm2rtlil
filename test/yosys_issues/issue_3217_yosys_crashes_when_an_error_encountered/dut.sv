// YosysHQ/yosys#3217 (closed): Yosys crashes when an error encountered under Windows/Anaconda during file delete
// https://github.com/YosysHQ/yosys/issues/3217
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
`timescale 1 ns / 100 ps
module crash_yosys(__o_clk);

// Simulator generated clock & reset
logic  clk;
initial begin
  clk <= 1'b0;
end

always begin
  #10 clk <= ~clk;
end

// Only run the I2C transaction once
always_ff @(posedge clk) begin
  $stop;
end


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_clk;
  assign __o_clk = clk;
endmodule

