// Three arms of ONE always_ff write the same element of a 2-D unpacked array
// at DIFFERENT GRANULARITIES:
//   * by FIELD under reset              (`.valid <= 0; .dep <= '0`)
//   * WHOLE in the shift arm            (`pipeReg[i][j-1] <= pipeReg[i][j]`)
//   * by FIELD again in the stall arm
// The loop-unrolled sync path computed each arm's else-value from an EXACT
// pending-key hit, so the stall arm found the reset arm's 1-bit/8-bit keys and
// took those -- the shift arm never reached `valid`/`dep`.  The fields no arm
// writes individually (`ptr` here) shifted correctly, which is what makes the
// bug so quiet: the register keeps working, just not for the written fields.
//
// RSD's WakeupPipelineRegister has exactly this shape over
//   WakeupPipeReg memPipeReg[MEM_ISSUE_WIDTH][ISSUE_QUEUE_MEM_LATENCY]
// and its `port.wakeupVector` read all zeroes for 68 of 301 co-simulated
// cycles while `port.wakeupPtr` was right.
//
// read_verilog CANNOT be the gold: it rejects `pipeReg[i][j].valid` (member
// access on an element of a 2-D unpacked array) with a syntax error, and the
// field write IS the bug, so the shape cannot be rephrased away.  The
// read_slang miter in test_slang_equiv.ys is the only real gate.
typedef struct packed { logic valid; logic [3:0] ptr; logic [7:0] dep; } R;

module pipe_elem_whole_and_field_arms(
    input  logic clk, rst, stall,
    input  R     nxt0, nxt1,
    output logic [7:0] o_dep,
    output logic [3:0] o_ptr,
    output logic       o_valid);

    R pipeReg[2][3];
    R nxt[2];
    assign nxt[0] = nxt0;
    assign nxt[1] = nxt1;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 2; i++)
                for (int j = 0; j < 3; j++) begin
                    pipeReg[i][j].valid <= 1'b0;
                    pipeReg[i][j].dep   <= '0;
                end
        end
        else if (!stall) begin
            for (int i = 0; i < 2; i++) begin
                for (int j = 1; j < 3; j++)
                    pipeReg[i][j-1] <= pipeReg[i][j];
                pipeReg[i][2] <= nxt[i];
            end
        end
        else begin
            for (int i = 0; i < 2; i++) begin
                for (int j = 1; j < 2; j++)
                    pipeReg[i][j-1] <= pipeReg[i][j];
                pipeReg[i][1].valid <= 1'b0;
                pipeReg[i][1].dep   <= '0;
            end
        end
    end

    // `dep` is the field the shift arm lost; `ptr` is the control.
    assign o_dep   = pipeReg[0][0].dep;
    assign o_ptr   = pipeReg[0][0].ptr;
    assign o_valid = pipeReg[0][0].valid;
endmodule
