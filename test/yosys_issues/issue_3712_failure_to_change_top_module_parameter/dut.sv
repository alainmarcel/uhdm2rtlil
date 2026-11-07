// YosysHQ/yosys#3712 (closed): Failure to change top-module parameter value in hierarchy command with -chparam
// https://github.com/YosysHQ/yosys/issues/3712
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module mod1 
  #(parameter NBITS=5)
   (input  logic [2*NBITS-1:0] A,
    output logic [2*NBITS-1:0] B);
   logic [2*NBITS-1:0] C;
   mod2 #(.NBITS(NBITS)) m (.A(A), .B(C));
   mod3 #(.NBITS(NBITS)) m (.A(C), .B(B));
endmodule

module mod2 
  #(parameter NBITS=5)
   (input  logic [2*NBITS-1:0] A,
    output logic [2*NBITS-1:0] B);   
   assign B = { A[NBITS-1:0], A[2*NBITS-1:NBITS] };
endmodule

module mod3
  #(parameter NBITS=5)
   (input  logic [2*NBITS-1:0] A,
    output logic [2*NBITS-1:0] B);   
   assign B = { A[NBITS-2:0], A[2*NBITS-1:NBITS], A[NBITS-1] };
endmodule

