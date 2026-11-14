// MikePopoloski/slang#1660 (closed): Ignoring invalid assign in constant false if statement
// https://github.com/MikePopoloski/slang/issues/1660
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test #(
    parameter int DELAY = 1
) (
    input  logic clk,
    input  [7:0]  in_byte,
    output [7:0]  out_byte
);

  logic [DELAY-1:0][7:0] byte_dl;

  always_ff @(clk) begin
    byte_dl[0] <= in_byte;

    if (DELAY > 1) begin
      byte_dl[DELAY-1:1] <= byte_dl[DELAY-2:0];
    end
  end

  assign out_byte = byte_dl[DELAY-1];

endmodule : test

