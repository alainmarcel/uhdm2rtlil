// Dynamic bit writes of a packed register in DIFFERENT arms of one always_ff
// (`val[widx] <= d` under `if (wv)`, `val[ridx] <= 0` under `else if (rv)`),
// next to a memory write in the same arms -- OpenPiton l15_csm's ticket valid
// bits.  The else arm's first write chained on the then arm's in-flight
// value instead of the register once the always_ff blocking temps got their
// own map: clearing ticket 5 cleared every ticket (co-sim 4 div, formal
// `differs`).
module dut (input logic clk, input logic rst_n, input logic wv_i, input logic [2:0] widx_i, input logic d_i, input logic [7:0] d8_i,
            input logic rv_i, input logic [2:0] ridx_i, input logic cv_i, input logic [2:0] cidx_i, output logic [7:0] v_o);
    reg [7:0] val;
    reg [7:0] cache [7:0];
    always @(posedge clk) begin
        if (!rst_n) begin
            val[0] <= 0; cache[0] <= 0; val[1] <= 0; cache[1] <= 0; val[2] <= 0; cache[2] <= 0; val[3] <= 0; cache[3] <= 0;
            val[4] <= 0; cache[4] <= 0; val[5] <= 0; cache[5] <= 0; val[6] <= 0; cache[6] <= 0; val[7] <= 0; cache[7] <= 0;
        end else begin
            if (wv_i) begin
                cache[widx_i] <= d8_i;
                val[widx_i] <= d_i;
                if (cv_i && (cidx_i != widx_i)) val[cidx_i] <= 1'b0;
            end else if (rv_i) begin
                cache[ridx_i] <= 0;
                val[ridx_i] <= 1'b0;
                if (cv_i && (cidx_i != ridx_i)) val[cidx_i] <= 1'b0;
            end else if (cv_i) begin
                val[cidx_i] <= 1'b0;
            end
        end
    end
    assign v_o = val;
endmodule
