// MikePopoloski/slang#1126 (closed): Request for sign-compare and useless-cast warning relaxation involving genvar type
// https://github.com/MikePopoloski/slang/issues/1126
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_b, __i_valid, __o_a);
    logic valid;
    logic [7:0] a;
    logic [7:0] b;

    for (genvar i = 0; i < 8; i++) begin
        always_comb a[i] = valid && i == b;
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [7:0] __i_b;
  assign b = __i_b;
  input logic __i_valid;
  assign valid = __i_valid;
  output logic [7:0] __o_a;
  assign __o_a = a;
endmodule

