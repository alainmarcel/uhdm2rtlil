// povik/sv-elab#172 (closed): BUG: `specify` blocks should be ignored with `--ignore-timing`
// https://github.com/povik/sv-elab/issues/172
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test_specify(input A, output B);

specparam a=1;

specify
endspecify

specify
(A => B) = ( 1 ) ;
(A- => B) = ( 1,2 ) ;
(A+ => B) = ( 1,2,3 ) ;
(A => B) = (
 1.1, 2, 3,
 4, 5.5, 6.6
) ;
(A => B) = (
 1.1, 2, 3,
 4, 5.5, 6.6 ,
 7.7, 8.8, 9,
 10.1, 11, 12
) ;
specparam b=1;
specparam [1:2] asasa=1;
endspecify

specify
specparam c=1:2:3;
endspecify

endmodule

