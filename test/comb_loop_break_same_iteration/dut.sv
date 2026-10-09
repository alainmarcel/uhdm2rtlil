// `break` in an always_comb for loop, with statements AFTER it in the same
// iteration -- RSD DecodedBranchResolver's lane scan:
//
//     for (int i = 0; i < DECODE_WIDTH; i++) begin
//         if (!insnValidIn[i]) begin
//             break;
//         end
//         if (!insnInfo[i].writePC && brPredIn[i].predTaken) begin
//             addrCheckLane = i; addrCheck = TRUE; addrIncorrect = TRUE;
//             break;
//         end
//         ...
//
// The comb unroller guarded every LATER iteration behind "no break so far"
// but ran the rest of the SAME iteration unconditionally: with no valid
// instruction the lane checks still executed and a flush was triggered
// (139 co-sim divergences, from cycle 2).  The shared per-iteration flag
// cannot guard them -- its final value also includes the breaks inside the
// guarded statements -- so every break SITE now has its own flag and the
// statements after a break-containing statement run behind the negation of
// the OR of the sites imported so far.
module comb_loop_break_same_iteration(
    input  logic [1:0] valid,
    input  logic [1:0] taken,
    output logic       flag,
    output logic [1:0] lane,
    output logic [1:0] seen   // which iterations reached the second check
);
    always_comb begin
        flag = 1'b0; lane = 2'd0; seen = 2'b00;
        for (int i = 0; i < 2; i++) begin
            if (!valid[i]) begin
                break;
            end
            seen[i] = 1'b1;
            if (taken[i]) begin
                flag = 1'b1; lane = i[1:0];
                break;
            end
        end
    end
endmodule
