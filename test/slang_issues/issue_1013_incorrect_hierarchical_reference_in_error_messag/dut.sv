// MikePopoloski/slang#1013 (closed): Incorrect hierarchical reference in error message
// https://github.com/MikePopoloski/slang/issues/1013
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t40 (__i_x, __i_y, __o_z);
typedef struct {
        logic a;
        logic b;
} t;
t x, y, z;
assign z = x & y;


  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [1:0] __i_x;
  assign x = t'(__i_x);
  input logic [1:0] __i_y;
  assign y = t'(__i_y);
  output logic [1:0] __o_z;
  assign __o_z = z;
endmodule

