// MikePopoloski/slang#855 (closed): slang-netlist: isKind assertion on code using an interface
// https://github.com/MikePopoloski/slang/issues/855
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface my_if();
  logic [31:0] a;
  logic [31:0] b;
  logic [31:0] sum;
  logic        co;

  modport test (
    input  a,
    input  b,
    output sum,
    output co
  );
endinterface

module adder(my_if.test i);
  logic [31:0] sum;
  logic co;
  assign {co, sum} = i.a + i.b;
  assign i.sum = sum;
  assign i.co = co;
endmodule

module top(__i_i_a, __i_i_b, __o_i_co, __o_i_sum);
  my_if i ();
  adder adder0 (i);

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [31:0] __i_i_a;
  input logic [31:0] __i_i_b;
  output logic __o_i_co;
  output logic [31:0] __o_i_sum;
  assign i.a = __i_i_a;
  assign i.b = __i_i_b;
  assign __o_i_co = i.co;
  assign __o_i_sum = i.sum;
endmodule

