// MikePopoloski/slang#2017 (closed): ANSI port of anonymous enum type becomes the error type when followed by an anonymous struct port
// https://github.com/MikePopoloski/slang/issues/2017
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (input enum {A} p3, input struct packed {logic f;} p5);
endmodule

