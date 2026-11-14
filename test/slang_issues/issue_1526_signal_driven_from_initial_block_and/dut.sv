// MikePopoloski/slang#1526 (closed): Signal driven from initial block AND always_ff should not raise error
// https://github.com/MikePopoloski/slang/issues/1526
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test(
  input  logic      clk,
  input  logic[9:0] addr,
  input  logic[7:0] data_in,
  input  logic      wr,
  output logic[7:0] data_out
);

  logic [7:0] ram[1024];

  initial begin
    for (int i = 0; i < 1024; i++) begin
      ram[i] = i[7:0];
    end
  end

  always_ff @(posedge clk) begin
    if (wr)
      ram[addr] <= data_in;
    else
    data_out <= ram[addr];
  end

endmodule : test

