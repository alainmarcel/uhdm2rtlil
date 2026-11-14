// MikePopoloski/slang#1007 (closed): slang-netlist: Assertion 'it != nodes.end() && "Could not find node"' failed
// https://github.com/MikePopoloski/slang/issues/1007
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t34 (__i_v, __o_x);
  reg  [3:0] x;
  reg   [15:0] v;

  always @(v)
  begin
    integer i;
    x = '0;
    for (i = 0; i <= 15; i = i + 1)
      if (v[i] == 1'b0)
        x = i;
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [15:0] __i_v;
  assign v = __i_v;
  output logic [3:0] __o_x;
  assign __o_x = x;
endmodule

