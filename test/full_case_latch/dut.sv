// Reproducer extracted from picorv32.v lines 401-428:
//   always @* begin
//     (* full_case *)
//     case (mem_wordsize)
//       0: begin mem_la_wdata = ...; mem_la_wstrb = ...; mem_rdata_word = ...; end
//       1: begin ... end
//       2: begin ... end
//     endcase
//   end
//
// The `case` covers values 0..2 of a 2-bit selector; value 3 is
// unassigned.  Yosys's Verilog frontend honours the `(* full_case *)`
// attribute and treats the missing 3 path as don't-care, producing
// pure combinational logic.  The UHDM frontend drops the attribute
// (or fails to propagate it to the resulting case_stmt) so `proc_dlatch`
// infers `$_DLATCH_*` cells for every signal written in the case —
// 68 such latches in the full picorv32 build.  `equiv_induct` then
// aborts with "No SAT model available for cell ... ($_DLATCH_N_)"
// since DLATCH primitives are not modelled by satgen.
//
// Expected post-synth: pure comb logic, zero DLATCH cells.
module full_case_latch(
    input  wire [1:0] sel,
    input  wire [7:0] a,
    input  wire [7:0] b,
    output reg  [7:0] x,
    output reg  [7:0] y
);
    always @* begin
        (* full_case *)
        case (sel)
            2'd0: begin x = a;     y = b;     end
            2'd1: begin x = a + 1; y = b + 1; end
            2'd2: begin x = a + 2; y = b + 2; end
        endcase
    end
endmodule
