// An initial block is SEQUENTIAL: `a = 1; b = a; c = b;` leaves b and c at 1,
// and a declaration initializer (`reg a = 3`) runs before it.  read_uhdm
// turned `b = a` into a continuous `connect \b \a` -- b aliased to a's wire
// for ever -- and with `reg b = 2` the two inits collided in ffinit
// ("Conflicting init values"; chipsalliance/sv-tests 10.4.1, 9.3.1, 9.3.4,
// 9.3.5, 9.4.5).
module dut (
    input  logic       clk,
    input  logic [7:0] d,
    output logic [7:0] qa, qb, qc, qe,
    output logic       ok
);
  logic [7:0] a = 8'd3;
  logic [7:0] b = 8'd2;
  logic [7:0] c;
  logic [7:0] e = 8'd9;
  initial begin
    a = 8'd1;
    b = a;          // 1, the value a has NOW, not a's wire
    c = b + 8'd1;   // 2
    e = #10 c;      // 2 (9.4.5: the delay is ignored, the value is c's)
  end
  // the registers keep their initial values until a clock edge loads d
  always @(posedge clk) begin
    a <= d; b <= d; c <= d; e <= d;
  end
  assign qa = a; assign qb = b; assign qc = c; assign qe = e;
  assign ok = (a == 8'd1) && (b == 8'd1) && (c == 8'd2) && (e == 8'd2);
endmodule
