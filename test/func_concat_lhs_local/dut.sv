// A CONCATENATION target over an inlined function's LOCALS, written inside one
// arm of an if/else and read back afterwards -- the shape of RSD's
// FP32CVT_F2I (FP32PipelinedOther.sv), whose float-to-int conversion came out
// X and, once the write landed, closed a combinational loop:
//
//   * the generic LHS import has no notion of an inlined body's SSA temps, so
//     each concat element fell back on import_ref_obj's unknown-signal path
//     and FABRICATED a 1-bit module wire -- the RHS was truncated to those bits
//     and the real temps were never written;
//   * `thread_comb_if` names a branch's writes by their single-wire target, so
//     a concatenation write was invisible to it and the arm kept the local's
//     X value at call entry;
//   * a write to such a local must be threaded under its `$0\...$func$...`
//     temp name, or the next read takes the RAW TEMP WIRE -- whose final value
//     already includes writes made LATER in the body (`lsb = int_result[0]`
//     read the post-rounding value and `round_up` fed back into itself).
module dut (
    input  logic [31:0] lhs,
    output logic [31:0] result,
    output logic        round_up_o
);
    function automatic void f2i(
        input  logic [31:0] l,
        output logic [31:0] result_o,
        output logic        round_up_o2
    );
        logic [7:0]  expo;
        logic [22:0] mant;
        logic [4:0]  shift_amount;
        logic [31:0] int_result;
        logic [22:0] lower_bits;
        logic lsb, guard, sticky, round_up;

        expo = l[30:23];
        mant = l[22:0];
        shift_amount = 158 - expo;

        if (expo <= 126) begin
            int_result = 0;
            lsb = 0;
            guard = (expo == 126) ? 1'b1 : 1'b0;
            sticky = (expo == 0 || expo == 126) ? |mant : 1'b1;
        end
        else if (expo <= 157) begin
            // the concatenation target, in an ARM, over two function locals
            {int_result, lower_bits} = {1'b1, mant, 31'h0} >> shift_amount;
            lsb = int_result[0];                       // reads it right back
            {guard, sticky} = {lower_bits[22], |lower_bits[21:0]};
        end
        else begin
            int_result = 32'h7fffffff;
            lsb = 1'b0; guard = 1'b0; sticky = 1'b0;
        end

        round_up = guard & (lsb | sticky);
        if (expo <= 157)
            int_result = int_result + {31'h0, round_up};   // reads it again
        result_o = int_result;
        round_up_o2 = round_up;
    endfunction

    always_comb f2i(lhs, result, round_up_o);
endmodule
