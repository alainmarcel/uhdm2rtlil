// MikePopoloski/slang#907 (closed): $assertoff() gets errors when passed a module hierarchy for recursive assertion disabling
// https://github.com/MikePopoloski/slang/issues/907
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module M(
    input logic clk,
    input logic rst_b
);
    myprop: assert property(@(posedge clk) disable iff (rst_b) ~1);
endmodule

module top;
    logic clk;
    logic rst_b;

    M m(
        .clk   (clk),
        .rst_b (rst_b)
    );

    initial begin
        $assertoff(0, m);
        $assertoff(0, m.myprop);
    end
endmodule

