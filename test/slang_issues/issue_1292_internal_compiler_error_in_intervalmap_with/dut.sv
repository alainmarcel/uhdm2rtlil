// MikePopoloski/slang#1292 (closed): Internal compiler error in IntervalMap with looped array assignments in always_ff
// https://github.com/MikePopoloski/slang/issues/1292
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module Test (
  input  logic clk,
  input  logic in,
  output logic out
);

  logic internal[4];

  assign internal[0] = in;
  assign out = internal[3];

  always_ff @(posedge clk) begin
    internal[1] <= internal[0];
    for (int stage = 2; stage <= 3; stage++) begin
      internal[stage] <= internal[stage-1];
    end
  end

endmodule

