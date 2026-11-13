// sv-elab regress.sv r20: a recursive function whose recursion depth is set
// by a CONSTANT argument.  The guard `exp > 0` never folded, both arms were
// inlined at every level down to the depth limit -- 2^21 inlinings, and
// read_uhdm never finished.  q = x**3 (mod 2^32).
module top(input [31:0] x, output [31:0] q);
  function automatic [31:0] pow;
    input [31:0] base;
    input [31:0] exp;
    begin
      if (exp > 0)
        pow = base * pow(base, exp - 1);
      else
        pow = 1;
    end
  endfunction
  assign q = pow(x, 3);
endmodule
