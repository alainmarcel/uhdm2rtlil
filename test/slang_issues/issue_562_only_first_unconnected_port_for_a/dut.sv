// MikePopoloski/slang#562 (closed): Only first unconnected port for a module flags a warning
// https://github.com/MikePopoloski/slang/issues/562
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module M(
    input logic a,
    input logic b,
    output logic c
);
endmodule

module top();
    M m();
endmodule

