// MikePopoloski/slang#2082 (closed): -Wunsized-concat should not be thrown for single unsized int in the count/LHS of a replication operator
// https://github.com/MikePopoloski/slang/issues/2082
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module sample (__o_a, __o_b, __o_c, __o_d);

    logic [3:0] foo;
    logic [15:0] a;
    logic [19:0] b;
    logic [63:0] c;
    logic [3:0] d;

    assign a = {{4}{foo}}; // warning: unsized integer in concat; using a width of 32 [-Wunsized-concat]
    assign b = {foo, {4{foo}}};
    assign c = {1, 2}; // warning: unsized integer in concat; using a width of 32 [-Wunsized-concat]
    assign d = {{{1}}{foo}}; // warning: unsized integer in concat; using a width of 32 [-Wunsized-concat]


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [15:0] __o_a;
  assign __o_a = a;
  output logic [19:0] __o_b;
  assign __o_b = b;
  output logic [63:0] __o_c;
  assign __o_c = c;
  output logic [3:0] __o_d;
  assign __o_d = d;
endmodule

