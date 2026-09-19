// Two linked defects in the function-body → RTLIL-case lowering, both of which
// silently produce X.  They mask each other, so the failing shape needs both:
// a conditional branch whose for loop uses a FUNCTION-SCOPE loop variable and
// writes only function LOCALS.
//
//   1. A loop variable declared at function scope (`integer i;`, rather than
//      inline `for (int i = …)`) is shadowed in input_mapping by a block-local
//      WIRE.  Reads of `i` in the body then resolve to that wire — which
//      nothing ever drives — instead of the iteration constant, so `x >> i`
//      shifted by X and the unrolled result was X.
//
//   2. A branch containing a for loop is given its own intermediate
//      `$N\<ctx>.$result$N` wire, copied back into the enclosing result.  A
//      loop that only touches LOCALS never drives that wire, so it stayed
//      undriven and the copy clobbered the branch's result with X
//      (`assign $22\…$result$22 $25\…$result$25`, nothing driving `$25\`).
//
// NB: every loop here is deliberately NON-accumulative (bit-select LHS), so
// the test isolates these two defects from the separate loop-accumulator bug.
module func_scope_loopvar_nested (
  input  logic [7:0] x,
  input  logic [7:0] y,
  input  logic [1:0] m,
  output logic [7:0] o_branch,  // loop inside if inside case, writes a local
  output logic [7:0] o_shift,   // loop var used as a shift amount
  output logic [7:0] o_idx      // loop var used as a bit index
);
  // Defect 1 + 2 together.
  function automatic [7:0] f_branch (input [7:0] x, input [7:0] y, input [1:0] m);
    reg [7:0] result;
    integer i;
    begin
      result = 0;
      case (m)
        2'b00: result = x + y;
        2'b01: result = x ^ y;
        2'b10: result = y >> 1;
        2'b11: begin
          if (x > y) begin
            for (i = 0; i < 4; i = i + 1) result[i] = x[i] ^ y[i];
          end else begin
            result = y & 8'hF0;
          end
        end
      endcase
      f_branch = result;
    end
  endfunction

  // Defect 1 on its own: `i` is the shift amount.
  function automatic [7:0] f_shift (input [7:0] x);
    reg [7:0] res;
    integer i;
    begin
      res = 0;
      for (i = 0; i < 4; i = i + 1) res[i] = ^(x >> i);
      f_shift = res;
    end
  endfunction

  // Defect 1 with the loop variable as a bit INDEX.
  function automatic [7:0] f_idx (input [7:0] x);
    reg [7:0] res;
    integer i;
    begin
      res = 0;
      for (i = 0; i < 8; i = i + 1) res[i] = x[7-i];
      f_idx = res;
    end
  endfunction

  assign o_branch = f_branch(x, y, m);
  assign o_shift  = f_shift(x);
  assign o_idx    = f_idx(x);
endmodule
