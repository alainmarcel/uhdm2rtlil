// MikePopoloski/slang#2018 (closed): defparam inside a module is ignored in elements of an instance array
// https://github.com/MikePopoloski/slang/issues/2018
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module leaf #(parameter W = 1) (input logic [W-1:0] a); endmodule
module mid; leaf l (.a()); defparam l.W = 8; endmodule
module top; mid m [1:0] (); mid s (); endmodule

