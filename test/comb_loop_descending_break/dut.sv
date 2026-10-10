// A `break` inside a DESCENDING always_comb for loop.  The Process-level
// unroller gave descending loops their own plain loop with no `break`
// handling, so every iteration's writes landed and the LAST one (the lowest
// index) won: RSD CommitStage's GetFinishedInsnRange reported the first
// finished lane instead of the last.  Both the `i >= 0; i--` form and the
// bound-on-the-left `0 <= j; j--` form (GetInsnPtr) are covered; the values
// are 2-bit so a random co-sim cannot pass by luck.
module comb_loop_descending_break (
    input  logic [3:0] last,
    input  logic [2:0] n,
    output logic [2:0] range,   // index+1 of the HIGHEST lane < n with last set, else 0
    output logic [1:0] head     // 1 + the highest j < 2 with last[j] set, else 0
);
    always_comb begin
        range = 0;
        for (int i = 3; i >= 0; i--) begin
            if (i < n && last[i]) begin
                range = i + 1;
                break;
            end
        end
    end

    always_comb begin
        head = 0;
        for (int j = 1; 0 <= j; j--) begin
            if (last[j]) begin
                head = j + 1;
                break;
            end
        end
    end
endmodule
