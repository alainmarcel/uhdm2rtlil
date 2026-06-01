// Reproducer extracted from picorv32.v's huge `always @(posedge clk)`
// block at line 1397 — `cpu_state` outer case wraps an inner case
// carrying `(* parallel_case, full_case *)`.  Both `case` statements
// reach `import_statement_comb(CaseRule*)` (the nested overload), not
// `import_case_stmt_comb(Process*)`.  Before this fix the CaseRule*
// overload silently dropped both the SV `unique`/`priority` qualifier
// and the Verilog attribute, so picorv32 emitted 165 `$mux` cells
// where the Verilog frontend emitted 107 `$mux` + 46 `$pmux` cells
// (only 2 `\parallel_case` markers vs 49 expected).
//
// Expected: inner switch has `\parallel_case 1` and `\full_case 1`.
module nested_full_case(
    input  wire        clk,
    input  wire [1:0]  outer,
    input  wire [1:0]  inner_sel,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output reg  [7:0]  q
);
    always @(posedge clk) begin
        case (outer)
            2'd0: begin
                (* parallel_case, full_case *)
                case (inner_sel)
                    2'd0: q <= a;
                    2'd1: q <= b;
                    2'd2: q <= a + b;
                endcase
            end
            2'd1: q <= a ^ b;
            default: q <= 8'h00;
        endcase
    end
endmodule
