// sv-elab regress.sv r34 (sv-elab#129): a `forever` loop in an initial block
// that terminates through `break` is unrolled at elaboration -- q starts at
// 4'b1111.  read_uhdm's initial-block interpreter had no `forever` case, so
// the block set nothing and q was undriven.
module top(output logic [3:0] q);
  initial begin
    int i = 0;
    forever begin
      if (i == 4) break;
      q[i] = 1;
      i = i + 1;
    end
  end
endmodule
