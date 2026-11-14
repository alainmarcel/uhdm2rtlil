// MikePopoloski/slang#1124 (closed): slang-netlist issue with net declaration assignments
// https://github.com/MikePopoloski/slang/issues/1124
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t (__o_a, __o_b, __o_c, __o_d, __o_e);
reg a, b;
wire c;
initial begin
  a <= 1;
  b <= a;
end
assign c = a;
wire d = a;
wire e = d;

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_a;
  output logic __o_b;
  output logic __o_c;
  output logic __o_d;
  output logic __o_e;
  assign __o_a = a;
  assign __o_b = b;
  assign __o_c = c;
  assign __o_d = d;
  assign __o_e = e;
endmodule

