// Reproducer for the synlig-reported PROC_DLATCH failure when
// `priority case` (or `unique case`) appears inside an `always_comb`.
// The SV `priority`/`unique` keywords on a `case` statement assert
// that the case is *full* (every relevant input pattern hits one of
// the branches); Yosys's `proc_dlatch` pass uses the `\full_case`
// attribute to know this.  Without that attribute the pass would
// (correctly, for plain `case`) infer a latch for the unwritten
// pattern and abort `always_comb`.  The fix is to set
// `\full_case = 1` on the RTLIL switch when the UHDM case_stmt
// carries `vpiQualifier = vpiUniqueQualifier | vpiPriorityQualifier`.
module priority_case (
    input  logic       a,
    input  logic       b,
    input  logic       c,
    input  logic [2:0] sel,
    output logic       y
);
    always_comb
        priority case (sel)
            3'b001: y = a;
            3'b010: y = b;
            3'b100: y = c;
        endcase
endmodule
