/* Generated by Yosys 0.55+46 (git sha1 aa1daa702, g++ 11.4.0-1ubuntu1~22.04 -fPIC -O3) */

(* top =  1  *)
(* src = "dut.sv:2.1-65.10" *)
module simple_fsm(clk, reset, start, done, busy, state);
  wire _0_;
  wire _1_;
  wire _2_;
  (* src = "dut.sv:7.17-7.21" *)
  output busy;
  wire busy;
  (* src = "dut.sv:3.17-3.20" *)
  input clk;
  wire clk;
  (* src = "dut.sv:6.17-6.21" *)
  input done;
  wire done;
  (* src = "dut.sv:17.11-17.21" *)
  wire [1:0] next_state;
  (* src = "dut.sv:4.17-4.22" *)
  input reset;
  wire reset;
  (* src = "dut.sv:5.17-5.22" *)
  input start;
  wire start;
  (* src = "dut.sv:8.23-8.28" *)
  output [1:0] state;
  wire [1:0] state;
  \$_NOR_  _3_ (
    .A(state[1]),
    .B(state[0]),
    .Y(_1_)
  );
  \$_ORNOT_  _4_ (
    .A(state[0]),
    .B(state[1]),
    .Y(_2_)
  );
  \$_ANDNOT_  _5_ (
    .A(done),
    .B(_2_),
    .Y(_0_)
  );
  \$_MUX_  _6_ (
    .A(_0_),
    .B(start),
    .S(_1_),
    .Y(next_state[0])
  );
  \$_XOR_  _7_ (
    .A(state[1]),
    .B(state[0]),
    .Y(busy)
  );
  (* \always_ff  = 32'd1 *)
  (* src = "dut.sv:20.1-25.4" *)
  \$_DFF_PP0_  \state_reg[0]  /* _8_ */ (
    .C(clk),
    .D(next_state[0]),
    .Q(state[0]),
    .R(reset)
  );
  (* \always_ff  = 32'd1 *)
  (* src = "dut.sv:20.1-25.4" *)
  \$_DFF_PP0_  \state_reg[1]  /* _9_ */ (
    .C(clk),
    .D(busy),
    .Q(state[1]),
    .R(reset)
  );
  assign next_state[1] = busy;
endmodule
