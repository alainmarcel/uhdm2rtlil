// MikePopoloski/slang#1124 (closed): slang-netlist issue with net declaration assignments
// https://github.com/MikePopoloski/slang/issues/1124
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t;
reg a, b;
wire c;
initial begin
  a <= 1;
  b <= a;
end
assign c = a;
wire d = a;
wire e = d;
endmodule

