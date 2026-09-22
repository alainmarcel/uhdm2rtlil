// An unrolled for-loop body with MORE THAN ONE assignment, where an index is
// itself a runtime value (verilog-axis axis_crosspoint.v:134).
//
// `import_statement_with_loop_vars` substitutes the loop variable through
// `current_loop_substitutions`, which only the hand-written paths consult
// (indexed part-select LHS and a few RHS forms).  Everything else goes through
// plain import_expression(), which reads `loop_values` -- and that was never
// populated here.  A bit-select LHS `mv[i]` was therefore imported with `i`
// still DYNAMIC: it lowered to a shift/extract temp, the write landed on that
// dead temp instead of `\mv [0]`, and the loop counter was materialised as a
// 32-bit undriven wire.
//
// The first statement hides it: its indexed part-select LHS takes the
// substitution path and looks fine, so only the SECOND statement loses its
// driver.  axis_crosspoint showed 32 undriven `\i` bits plus an undriven
// valid output.
module dut #(parameter M = 4, parameter CL = 2, parameter S = 4, parameter W = 8) (
  input                  clk,
  input  [M*CL-1:0]      sel,      // per-output source index
  input  [S-1:0]         sv,
  input  [S*W-1:0]       sd,
  output reg [M-1:0]     mv,       // driven by the SECOND statement
  output reg [M*W-1:0]   md        // driven by the first
);
  integer i;
  always @(posedge clk) begin
    for (i = 0; i < M; i = i + 1) begin
      // indexed part-select LHS, RHS indexed by a runtime selector
      md[i*W +: W] <= sd[sel[i*CL +: CL]*W +: W];
      // bit-select LHS -- this is the one that used to vanish
      mv[i]        <= sv[sel[i*CL +: CL]];
    end
  end
endmodule
