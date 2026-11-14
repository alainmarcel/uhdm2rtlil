// MikePopoloski/slang#673 (closed): Variables only used to index LHS of assignments considered as unused
// https://github.com/MikePopoloski/slang/issues/673
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(
    output logic [7:0] lhs,
    input  logic [7:0] rhs,
    input  logic [2:0] lhs_lsb,
    input  logic [2:0] rhs_lsb
);

   always_comb begin
       lhs = 0;
       lhs[lhs_lsb +: 2] = rhs[rhs_lsb +: 2];
   end

endmodule

