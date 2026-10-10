// A `function automatic void` whose body CALLS another void function with
// output arguments that are the caller's own locals (`Inner(t, eq, a_i, b_i)`
// -- RSD CommitStage's DecideCommit calls GetInsnPtr / GetFinishedOpNum on
// its locals).  Unpatched read_uhdm had no case for a call statement inside
// an inlined body: the callee was skipped, its outputs never assigned
// ("Reference to unknown signal"), and on the real row a width-mismatch
// assert killed the read.
module void_func_nested_call(input logic [1:0] a, input logic [1:0] b, output logic [1:0] y, output logic z);
  function automatic void Inner(output logic [1:0] o, output logic f, input logic [1:0] a_i, input logic [1:0] b_i);
    o = a_i + b_i;
    f = (a_i == b_i);
  endfunction
  function automatic void Outer(output logic [1:0] y_o, output logic z_o, input logic [1:0] a_i, input logic [1:0] b_i);
    logic [1:0] t;
    logic eq;
    Inner(t, eq, a_i, b_i);
    y_o = t ^ 2'b01;
    z_o = eq & t[0];
  endfunction
  always_comb Outer(y, z, a, b);
endmodule
