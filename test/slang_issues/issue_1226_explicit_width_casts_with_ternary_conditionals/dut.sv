// MikePopoloski/slang#1226 (closed): Explicit width-casts with ternary-conditionals can trigger -Wwidth-expand
// https://github.com/MikePopoloski/slang/issues/1226
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_a, __i_b, __i_c, __o_d, __o_e, __o_f);

    localparam int unsigned SIZE = 16;

    logic a;
    logic [7:0] b, c;
    logic [SIZE-1:0] d, e, f;

    always_comb begin
        d = SIZE'( a ? b : c);
        e = SIZE'(b);
        f = a ? SIZE'(b) : SIZE'(c);
    end


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_a;
  assign a = __i_a;
  input logic [7:0] __i_b;
  assign b = __i_b;
  input logic [7:0] __i_c;
  assign c = __i_c;
  output logic [15:0] __o_d;
  assign __o_d = d;
  output logic [15:0] __o_e;
  assign __o_e = e;
  output logic [15:0] __o_f;
  assign __o_f = f;
endmodule

