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

module top();
  my_if i ();
  adder adder0 (i);
endmodule

