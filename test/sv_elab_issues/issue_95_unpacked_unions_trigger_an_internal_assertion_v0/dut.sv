// povik/sv-elab#95 (open): Unpacked unions trigger an internal assertion
// https://github.com/povik/sv-elab/issues/95
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
typedef union packed {
    logic a;
    logic  b;
} test_union_t;

module foo ();
    test_union_t foobar;
endmodule

