// MikePopoloski/slang#1008 (closed): Handling of packed structures for -Wbitwise-op-mismatch
// https://github.com/MikePopoloski/slang/issues/1008
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;

  typedef struct packed {
      logic [1:0] a;
      logic [1:0] b;
  } s_t;

  s_t a, b, c, d;

  always_comb begin
      d = a |  b | c;
  end

endmodule

