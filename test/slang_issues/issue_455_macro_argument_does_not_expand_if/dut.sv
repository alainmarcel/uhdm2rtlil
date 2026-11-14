// MikePopoloski/slang#455 (closed): Macro argument does not expand if contained within a module name beginning with a backslash
// https://github.com/MikePopoloski/slang/issues/455
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define MAKE_INST(NAME, SIG) \
    (* instance_name = `"inst_``NAME`" *) \
    mod \inst_``NAME (.sig(SIG));

module mod(input logic sig);
endmodule
module top;
    logic sig1, sig2;
    `MAKE_INST(A, sig1)
    `MAKE_INST(B, sig2)
endmodule

