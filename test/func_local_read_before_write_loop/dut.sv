// An inlined function's local is an `automatic` variable: it has NO value at
// call entry.  The reader used the local's OWN WIRE as that entry value, and
// since the wire is driven by the very process reading it, a local READ BEFORE
// IT IS WRITTEN closed a COMBINATIONAL CYCLE -- the `$add`'s output returning
// to its own input through the enclosing `if`'s mux.
//
// This is RSD FP32PipelinedOther's FP32CVT_F2I reduced to plain types (its
// `int_result` is never initialised and read-modify-written under
// `if (expo <= 157)`).  read_uhdm built 32 logic loops, one per bit, where
// read_slang builds none: read_slang materialises the undefined entry value as
// a constant X, which is what the LRM says reading an unwritten `automatic`
// gives.
//
// The shape that matters, and why each piece is here:
//   * the local is read before any write, so its entry value is observable;
//   * the call sits inside a CASE ARM, so the body's assignments land in a
//     case rather than the root -- the local's temp then has no root-case
//     default at all, and `proc` closes every unwritten path through the temp
//     itself;
//   * the grouped non-ANSI `input` / `output` header is RSD's own style and is
//     what makes Surelog list the local in BOTH the function's Variables() and
//     the body block's, so the temp the body uses is the SECOND one.
//
// The gate is STRUCTURAL (test_structural.ys): a formal miter cannot see this,
// because the module stays equivalent either way -- yosys itself labels the
// report "cell's internal connectivity overapproximated; loop may be a false
// positive".  That is exactly why the RSD sweep's formal column PROVED while
// the netlist carried 32 loops.
typedef struct packed {
    logic [31:0] result;
    logic [4:0]  fflags;
} PipeRegPath;

function automatic void cvt_f2i(
input
    logic [31:0] lhs,
    logic        fmt_unsigned,
    logic [2:0]  rm,
output
    logic [31:0] result,
    logic [4:0]  fflags
);
    logic [7:0]  expo;
    logic [31:0] int_result;
    logic        round_up;
    logic        lhs_is_neg;
    fflags = '0;
    if (expo <= 126) begin
        int_result = int_result + {31'h0, round_up};
        result = lhs_is_neg ? (fmt_unsigned ? 32'h0 : -int_result) : int_result;
    end
endfunction

module func_local_read_before_write_loop #(parameter PIPELINE_DEPTH = 5)(
    input  logic [31:0] lhs,
    input  logic [4:0]  fpuCode,
    input  logic [2:0]  rm,
    output logic [31:0] result,
    output logic [4:0]  fflags);

    logic [31:0] resultOut;
    logic [4:0]  fflagsOut;
    logic        fmt_unsigned;
    assign result = resultOut;
    assign fflags = fflagsOut;

    always_comb begin
        // default both outputs so THIS block is complete: without it the
        // `default: ;` arm leaves them holding their own value and every
        // reader (ours and read_slang's) reports that self-hold as a loop,
        // masking the one under test.
        resultOut = '0;
        fflagsOut = '0;
        unique case (fpuCode)
            5'd10, 5'd11: begin
                cvt_f2i(lhs, fmt_unsigned, rm, resultOut, fflagsOut);
            end
            default: ;
        endcase
    end
endmodule
