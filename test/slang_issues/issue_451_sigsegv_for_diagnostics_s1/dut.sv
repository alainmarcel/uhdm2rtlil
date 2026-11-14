// MikePopoloski/slang#451 (closed): sigsegv for Diagnostics
// https://github.com/MikePopoloski/slang/issues/451
// Code block(s) from the issue (variant s1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define MAKE_INST(NAME, SIG) \
    (* instance_name = `"inst_``NAME`" *) \
    mod \inst_``NAME (.sig(SIG));

module mod(input logic sig);
endmodule
module top (__i_sig1);
    logic sig1, sig2;
    `MAKE_INST(A, sig1)
    `MAKE_INST(B, sig2)

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_sig1;
  assign sig1 = __i_sig1;
endmodule

