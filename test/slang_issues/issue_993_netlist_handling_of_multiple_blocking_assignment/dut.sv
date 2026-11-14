// MikePopoloski/slang#993 (closed): netlist handling of multiple blocking assignments of same var in always_comb
// https://github.com/MikePopoloski/slang/issues/993
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t2 (input clk, output reg [31:0]nq);
reg [31:0]n;
always_comb begin
        n = nq;
        n = n + 1;
end

always_ff @(posedge clk)
        nq <= n;
endmodule

