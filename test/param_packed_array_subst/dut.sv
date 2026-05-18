// Reproducer for chipsalliance/synlig#1073
// (UHDM-integration-tests/tests/ParameterPackedArraySurelogSubstitution/top.sv).
// A module parameter with a packed-array typespec
// (`parameter logic [0:0][3:0] P`) initialised by a nested
// assignment-pattern.  Indexing `P[0]` selects the only element, a
// 4-bit slice that should evaluate to `4'b1000 == 4'd8`.
//
// The original UHDM frontend resolved `P` by reading the
// pre-substitution value from `Design->AllModules()` and got
// `4'd1`; the issue's screenshot points out that Surelog already
// stores the correct post-substitution value on the elaborated
// `TopModules` parameter (`P[0] == 8`).
//
// Added an `in` input XORed into the result so co-sim exercises a
// range of values; with `in == 0` the low 4 bits still equal
// `P[0] == 4'd8` (the upstream-expected result).
module top (
    input  logic [3:0] in,
    output logic [3:0] a
);
   parameter logic [0:0][3:0] P = '{'{1'b1, 1'b0, 1'b0, 1'b0}};

   assign a = P[0] ^ in;
endmodule
