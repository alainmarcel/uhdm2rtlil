// YosysHQ/yosys#3741 (open): Crash when using -chparam and '0 as input to a module
// https://github.com/YosysHQ/yosys/issues/3741
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): second mod2 instance driven by a new input a, observable on C (the '0-connected instance under test makes B a constant, so the co-sim was vacuous)

// ---- b0.sv
module mod1
  #(parameter int NBITS=32)
   (output logic [NBITS-1:0] B,
    input  logic a,
    output logic [NBITS-1:0] C);
   mod2 #(.NBITS(NBITS)) m_obs (.A(a), .B(C));
   mod2 #(.NBITS(NBITS)) m (.A('0), .B(B));          // crash
//   mod2 #(.NBITS(NBITS)) m (.A(1'b0), .B(B));   // ok
endmodule

module mod2
  #(parameter NBITS=32)
   (input  logic A,
    output logic [NBITS-1:0] B);   
   assign B = { NBITS{A} };
endmodule

