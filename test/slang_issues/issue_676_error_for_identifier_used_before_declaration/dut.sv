// MikePopoloski/slang#676 (closed): Error for identifier used before declaration when declaration is before use
// https://github.com/MikePopoloski/slang/issues/676
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m (
    clk,
    ram
);
parameter S = "no_rw_check";

input logic clk;

(* ramstyle = S *)
output reg [31:0] ram [15:0];

endmodule

