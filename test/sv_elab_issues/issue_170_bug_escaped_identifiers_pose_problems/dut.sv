// povik/sv-elab#170 (open): BUG: escaped identifiers pose problems
// https://github.com/povik/sv-elab/issues/170
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// There must be white space after the
// string which uses escape character
module \1dff (
q,      // Q output
\q~ ,   // Q_out output
d,      // D input
cl$k,   // CLOCK input
\reset* // Reset input
);

input d, cl$k, \reset* ;
output q, \q~ ;  

endmodule

