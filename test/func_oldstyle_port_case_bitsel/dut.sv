// A case arm that writes its result ONLY through bit-selects lost its value.
//
// `f = result;` makes scan_for_return_variables bind the local `result` to the
// function's RESULT wire, which excludes it from SSA renaming — so its
// pre-case mapping IS the result wire.  The case phi-merge had an explicit
// "skip when the pre-map is the result wire" rule, so the arm's value was
// thrown away: an arm that only does `result[2*i] = x[i];` builds its value in
// SSA temps, nothing writes it back, and the arm returned the PRE-case value.
//
// It only bites with OLD-STYLE (non-ANSI) function ports.  With ANSI ports the
// function-scope locals become block-locals and get their own wire, which
// dodges the aliasing — which is why the identical function passes one way and
// fails the other.  many_functions' func_mixed is old-style, and its mode
// 2'b01 bit-interleave is exactly this shape.
module func_oldstyle_port_case_bitsel (
  input  logic [7:0] x,
  input  logic [7:0] y,
  input  logic [1:0] m,
  output logic [7:0] o_old,   // old-style ports  — the failing shape
  output logic [7:0] o_ansi   // ANSI ports       — control, always worked
);
  // Old-style (non-ANSI) function port declarations.
  function [7:0] f_old;
    input [7:0] x, y;
    input [1:0] m;
    reg [7:0] result;
    integer i;
    begin
      result = 0;
      case (m)
        2'b01: begin
          for (i = 0; i < 4; i = i + 1) begin
            result[2*i]   = x[i];
            result[2*i+1] = y[i];
          end
        end
        default: result = 8'hAA;
      endcase
      f_old = result;
    end
  endfunction

  // Same body, ANSI ports.
  function automatic [7:0] f_ansi (input [7:0] x, input [7:0] y, input [1:0] m);
    reg [7:0] result;
    integer i;
    begin
      result = 0;
      case (m)
        2'b01: begin
          for (i = 0; i < 4; i = i + 1) begin
            result[2*i]   = x[i];
            result[2*i+1] = y[i];
          end
        end
        default: result = 8'hAA;
      endcase
      f_ansi = result;
    end
  endfunction

  assign o_old  = f_old(x, y, m);
  assign o_ansi = f_ansi(x, y, m);
endmodule
