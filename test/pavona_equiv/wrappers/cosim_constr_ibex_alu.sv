// One-hot legalisation for the ibex_alu adder-select `unique case (1'b1)`:
// multdiv_sel_i and the SHxADD adder-shift selects must be mutually exclusive
// (in the real design the multdiv unit drives operator_i to ADD/SUB, never
// SH{1,2,3}ADD, while multdiv_sel_i is high).  Random stimulus otherwise makes
// them multi-hot, so behavioural priority (multdiv first) and the synthesised
// netlists diverge on BOTH frontends -- a shared artefact, not a UHDM bug.
if (multdiv_sel_i) operator_i = ibex_pkg::ALU_ADD;
