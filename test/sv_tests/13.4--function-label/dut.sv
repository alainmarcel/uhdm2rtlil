// Converted from sv-tests chapter-13/13.4--function-label.sv (:name: function,
// :tags: 13.4).  Upstream is `module top()` with an initial-block $display
// assertion; the construct under test is a function with a LABELLED
// `endfunction : test`.  Driven from a real input, observable at an output.
module top(input logic signed [31:0] val, output logic signed [31:0] result);
  function int test(int v);
    return v + 1;
  endfunction : test
  assign result = test(val);
endmodule
