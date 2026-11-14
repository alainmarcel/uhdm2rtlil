// MikePopoloski/slang#1008 (closed): Handling of packed structures for -Wbitwise-op-mismatch
// https://github.com/MikePopoloski/slang/issues/1008
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_a, __i_b, __i_c, __o_d);

  typedef struct packed {
      logic [1:0] a;
      logic [1:0] b;
  } s_t;

  s_t a, b, c, d;

  always_comb begin
      d = a |  b | c;
  end


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [3:0] __i_a;
  assign a = s_t'(__i_a);
  input logic [3:0] __i_b;
  assign b = s_t'(__i_b);
  input logic [3:0] __i_c;
  assign c = s_t'(__i_c);
  output logic [3:0] __o_d;
  assign __o_d = d;
endmodule

