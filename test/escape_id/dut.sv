// There must be white space after the
// string which uses escape character
module escape_id (
q,      // Q output
\q~ ,   // Q_out output
d,      // D input
cl$k,   // CLOCK input
\reset* // Reset input
);

input d, cl$k, \reset* ;
output q, \q~ ;  

endmodule
