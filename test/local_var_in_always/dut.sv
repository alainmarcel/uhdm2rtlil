module local_var_in_always #(parameter CTR_WIDTH = 5, MAX_CREDITS = 16) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 tx_valid_out,
    input  wire                 tx_ready_in,
    input  wire [CTR_WIDTH-1:0] credit_return_val,
    output reg  [CTR_WIDTH-1:0] credit_cnt
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_cnt <= MAX_CREDITS[CTR_WIDTH-1:0];
        end else begin
            logic [CTR_WIDTH-1:0] dec;
            dec = (tx_valid_out && tx_ready_in) ? 1'b1 : '0;
            credit_cnt <= credit_cnt - dec + credit_return_val[CTR_WIDTH-1:0];
        end
    end
endmodule
