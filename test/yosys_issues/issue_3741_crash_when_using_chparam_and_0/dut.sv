// YosysHQ/yosys#3741 (open): Crash when using -chparam and '0 as input to a module
// https://github.com/YosysHQ/yosys/issues/3741
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module mod1
  #(parameter int NBITS=32)
   (output logic [NBITS-1:0] B);
   mod2 #(.NBITS(NBITS)) m (.A('0), .B(B));          // crash
//   mod2 #(.NBITS(NBITS)) m (.A(1'b0), .B(B));   // ok
endmodule

module mod2
  #(parameter NBITS=32)
   (input  logic A,
    output logic [NBITS-1:0] B);   
   assign B = { NBITS{A} };
endmodule

