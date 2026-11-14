// MikePopoloski/slang#451 (closed): sigsegv for Diagnostics
// https://github.com/MikePopoloski/slang/issues/451
// Code block(s) from the issue (variant s2); harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define MAKE_INST(NAME, SIG) \
    (* instance_name = `"\inst_``NAME`" *) \
    mod \inst_``NAME ( \
        .sig(SIG) \
    );

module mod(input logic sig);
endmodule
module top;
    logic sig1, sig2;
    `MAKE_INST(A, sig1)
    `MAKE_INST(B, sig2)
endmodule

