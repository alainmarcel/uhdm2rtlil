// A shift register written as `X[i] <= X[i-1]` in an always_ff for-loop, on
// an array NOT named `M`.  A legacy special case recognised the pattern for
// any name but only built element registers for `M` (mul_unsigned), so the
// whole always_ff body was dropped: YosysHQ/yosys#2423's
// `flipflop[i] <= flipflop[i-1]` came out as one flop wired D = Q = `in`.
module dut (input  logic clk, input logic d,
            output logic q_u, q_b, q_p,
            output logic [3:0] tap_b);
  // unpacked array, element 0 driven by a continuous assign (#2423's shape)
  logic u [3:0];
  assign u[0] = d;
  assign q_u = u[3];
  always_ff @(posedge clk) begin
    for (int i = 1; i <= 3; i++) u[i] <= u[i-1];
  end

  // unpacked array, element 0 written in the same block, local loop var
  logic b [3:0];
  assign q_b = b[3];
  assign tap_b = {b[3], b[2], b[1], b[0]};
  always_ff @(posedge clk) begin
    integer i;
    b[0] <= d;
    for (i = 1; i < 4; i = i + 1) b[i] <= b[i-1];
  end

  // packed vector
  logic [3:0] p;
  assign p[0] = d;
  assign q_p = p[3];
  always_ff @(posedge clk) begin
    for (int i = 1; i <= 3; i++) p[i] <= p[i-1];
  end
endmodule
