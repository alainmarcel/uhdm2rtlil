// MikePopoloski/slang#331 (closed): Port declaration in module
// https://github.com/MikePopoloski/slang/issues/331
// Code block(s) from the issue (variant v2); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top1(a);
       input a;
       var integer c;
       initial begin
               c = a; 
       end
       integer a;
endmodule

module top2(a, __o_c);
       var integer c;
       initial begin
               c = a; 
       end
       input integer a;

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [31:0] __o_c;
  assign __o_c = c;
endmodule

