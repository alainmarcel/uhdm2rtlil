// An INCOMPLETE case inside a function returned X for every unlisted selector
// value, instead of the value the variable held before the case.
//
// When a case has no default arm the reader synthesises one "to preserve the
// current value" — but it did so by emitting a SELF-ASSIGN, `assign \r \r`.
// In RTLIL, preserving a value means emitting NO action for that signal: the
// arm leaves it alone and whatever was established before the switch stands.
// A self-assign does the opposite — `proc` builds the $pmux with the wire
// itself as the default input, and since that wire is only ever assigned
// INSIDE this process it has no driver, so an unmatched case yields X.
//
// The same shape reaches the root action list through `f = result;`, which
// becomes `\r = \r` once scan_for_return_variables has aliased the local
// `result` to the function's result wire; that no-op is filtered too.
module func_incomplete_case_default (
  input  logic [7:0] x,
  input  logic [7:0] y,
  input  logic [1:0] m,
  output logic [7:0] o_gap,     // incomplete case, pre-set local
  output logic [7:0] o_gap_nest,// incomplete case with a nested incomplete case
  output logic [7:0] o_full     // control: every selector value listed
);
  // 2'b00 and 2'b10 are not listed: both must return the pre-case value 8'h5A.
  function automatic [7:0] f_gap (input [7:0] x, input [7:0] y, input [1:0] m);
    reg [7:0] result;
    integer i;
    begin
      result = 8'h5A;
      case (m)
        2'b01: begin
          for (i = 0; i < 4; i = i + 1) result[i] = x[i] ^ y[i];
        end
        2'b11: result = x & 8'hF0;
      endcase
      f_gap = result;
    end
  endfunction

  // Nested incomplete case: the inner one leaves 2'b00 unlisted as well.
  function automatic [7:0] f_gap_nest (input [7:0] x, input [7:0] y, input [1:0] m);
    reg [7:0] result;
    begin
      result = 8'h3C;
      case (m)
        2'b01: begin
          case (x[1:0])
            2'b01: result = y;
            2'b10: result = ~y;
          endcase
        end
        2'b11: result = x ^ y;
      endcase
      f_gap_nest = result;
    end
  endfunction

  // Control: a complete case was never affected.
  function automatic [7:0] f_full (input [7:0] x, input [7:0] y, input [1:0] m);
    reg [7:0] result;
    begin
      result = 8'h5A;
      case (m)
        2'b00: result = x;
        2'b01: result = y;
        2'b10: result = x | y;
        2'b11: result = x & 8'hF0;
      endcase
      f_full = result;
    end
  endfunction

  assign o_gap      = f_gap(x, y, m);
  assign o_gap_nest = f_gap_nest(x, y, m);
  assign o_full     = f_full(x, y, m);
endmodule
