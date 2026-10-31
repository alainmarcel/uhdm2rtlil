// Converted from chipsalliance/sv-tests chapter-13/13.4--function.sv
// (:name: function, :tags: 13.4) into a SYNTHESIZABLE test: the upstream file
// is `module top()` with no ports, exercising the construct from an `initial`
// block and checking it with `$display(":assert: ...")`.  Nothing there is
// observable to a synthesis flow -- there is no logic to compare.
//
// The construct under test is a FUNCTION with an explicit `return`.  Here it
// is driven from a real input and its result is observable at a real output,
// so read_uhdm's lowering can be compared against read_verilog and proven.
//
// The upstream file is kept verbatim beside this one as `orig.sv`.
module top(input  logic signed [31:0] val,
           output logic signed [31:0] result);

  function automatic int test(int v);
    return v + 1;
  endfunction

  assign result = test(val);

endmodule
