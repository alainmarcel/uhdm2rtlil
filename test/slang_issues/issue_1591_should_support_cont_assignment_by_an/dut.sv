// MikePopoloski/slang#1591 (closed): Should support cont-assignment by an element-selection expr of *dynamic* type.
// https://github.com/MikePopoloski/slang/issues/1591
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__o_n);
  
  wire [4:0] n;
  
  string ss ;
  
  assign n[1] = ss[6];
  
  
  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [4:0] __o_n;
  assign __o_n = n;
endmodule

