// Reproducer for the synlig-reported PROC_DLATCH failure when
// `priority if` (or `unique if`) appears inside an `always_comb`.
// The SV `priority`/`unique` keywords assert that one of the
// branches is always taken; Yosys's `proc_dlatch` pass uses the
// `\full_case` attribute on the synthesized switch rule to know
// this.  Without it the pass would (correctly, for a plain
// if/else-if) infer a latch for the unwritten pattern and abort
// `always_comb`.  Note: even the Yosys Verilog frontend syntax-
// errors on `priority if` (it only accepts `priority case`), so
// this test is UHDM-only.
module priority_if (
    input  logic       a,
    input  logic       b,
    input  logic       c,
    input  logic [2:0] sel,
    output logic       y
);
    always_comb
        priority if (sel == 3'b001)
            y = a;
        else if (sel == 3'b010)
            y = b;
        else if (sel == 3'b100)
            y = c;
endmodule
