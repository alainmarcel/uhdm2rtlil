// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r23); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r23
// specify ignored
module r23(input A, output B);
assign B = A;
specparam a = 1;

specify
endspecify

specify
    (A => B) = (1);
    (A- => B) = (1,2);
    (A+ => B) = (1,2,3);
    (A => B) = (
     shortreal'(1.1), 2, 3,
     4, 5.5, 6.6
    );
    (A => B) = (
     1.1, 2, 3,
     4, 5.5, 6.6,
     7.7, 8.8, 9,
     10.1, 11, 12
    );
    specparam [1:2] b = 1;
endspecify

specify
    specparam c = 1:2:3;
endspecify
endmodule

