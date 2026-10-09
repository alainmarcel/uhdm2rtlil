// A `function automatic void` with BODY-LOCAL variables (`logic [1:0] t;`
// declared inside the function body).  Surelog lists such a local both in
// the function's Variables() and in the body begin-block's, and unpatched
// read_uhdm queued TWO `sync always` updates of its placeholder wire (an X
// one, then the temp): proc turned the driver conflict into a constant X
// that reached every output (RSD CommitStage's DecideCommit locals).
module void_func_body_local(input logic [1:0] a, input logic [1:0] b, output logic [1:0] y, output logic z);
  function automatic void Outer(output logic [1:0] y_o, output logic z_o, input logic [1:0] a_i, input logic [1:0] b_i);
    logic [1:0] t;
    logic eq;
    t = a_i + b_i;
    eq = (a_i == b_i);
    y_o = t ^ 2'b01;
    z_o = eq & t[0];
  endfunction
  always_comb Outer(y, z, a, b);
endmodule
