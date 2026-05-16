// Reproducer for named `cover`/`assert` statements inside an
// `always_comb`.  The original report assigns to a *input* port,
// which is not legal SV, so this version uses an internal wire `q`
// driven by `b` and asserts/covers the relation between `a`, `b`,
// and `q` so the synth output has real consumers and the formal
// statements all see a defined target.
module named_cover_assert (
    input  logic a,
    output logic b,
    output logic q
);
    assign q = b;

    always_comb cover_in_eq_out  : cover  (a == b);
    always_comb cover_in_neq_out : cover  (a != b);
    always_comb assert_a_eq_b    : assert (a == b);
    always_comb assert_a_neq_b   : assert (a != b);

    assign b = a;
endmodule
