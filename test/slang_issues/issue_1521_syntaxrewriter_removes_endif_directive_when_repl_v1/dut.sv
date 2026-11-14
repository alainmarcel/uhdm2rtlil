// MikePopoloski/slang#1521 (closed): SyntaxRewriter removes endif directive when replacing a subsequent statement
// https://github.com/MikePopoloski/slang/issues/1521
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test(
    input wire clock,
    input wire reset,
    output reg [3:0] o_signal
);
wire t;
`ifndef SYNTHESIS
initial begin
    $display("hello");
end
`endif
assign t = 2;

endmodule

