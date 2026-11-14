// MikePopoloski/slang#565 (closed): Errors with module range specification and implicit port connections
// https://github.com/MikePopoloski/slang/issues/565
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module M(
    input logic a,
    output logic b
);
endmodule

module top;
    localparam N = 8;

    logic [N-1:0] a;
    logic [N-1:0] b;

    M m [N-1:0] (
        .a,
        .b
    );
endmodule

