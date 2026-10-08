// An `if` inside a for loop whose condition is a VECTOR expression, in an
// always block with non-blocking writes -- verilog-ethernet's
// axis_xgmii_rx_64:
//     for (i = CTRL_WIDTH-1; i >= 0; i = i - 1)
//         if ({xgmii_term[3:0], swap_rxc_term} & (1 << i)) ...
// `(1 << i)` is an integer, so the `&` is 32 bits wide.  The loop-unrolling
// path built the hold mux with that vector as the $mux SELECT: yosys's design
// check found the malformed port, its error reporter re-entered itself, and
// read_uhdm segfaulted with no message at all.  The condition has to be
// reduced to a boolean, as read_verilog does.
module loop_if_vector_condition (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] term,
    input  logic [3:0] rxc,
    output logic [2:0] lane,
    output logic       hit
);
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            lane <= 3'd0;
            hit  <= 1'b0;
        end else begin
            hit <= 1'b0;
            for (i = 7; i >= 0; i = i - 1) begin
                if ({term, rxc} & (1 << i)) begin
                    lane <= i[2:0];
                    hit  <= 1'b1;
                end
            end
        end
    end
endmodule
