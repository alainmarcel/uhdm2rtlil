// One-hot legalisation for the ex_block-internal ibex_alu adder-select: ex_block
// drives alu.multdiv_sel_i = (mult_sel_i | div_sel_i) and alu.operator_i =
// alu_operator_i, so the same `unique case (1'b1)` multi-hot arises when a
// multdiv is selected while alu_operator_i is a SHxADD.  In the real design the
// decoder never pairs those, so force ADD when a multdiv path is selected.
if (mult_sel_i || div_sel_i) alu_operator_i = ibex_pkg::ALU_ADD;
