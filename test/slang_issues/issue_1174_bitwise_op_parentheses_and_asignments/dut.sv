// MikePopoloski/slang#1174 (closed): bitwise-op-parentheses and |= asignments
// https://github.com/MikePopoloski/slang/issues/1174
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_a, __i_b, __o_c);
    logic [15:0] a;
    logic [15:0] b;
    logic c;

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            c |= a[i] & b[i];
        end
    end


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [15:0] __i_a;
  assign a = __i_a;
  input logic [15:0] __i_b;
  assign b = __i_b;
  output logic __o_c;
  assign __o_c = c;
endmodule

