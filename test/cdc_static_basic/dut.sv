module cdc_static_basic (
    input clk,
    input [3:0] src_data,
    output reg [3:0] gated_data_out
);
    (* cdc_static = "clk_b", real_attr = 1.5, int_attr = 42 *)
    wire [3:0] gated_data = src_data;

    always @(posedge clk) begin
        gated_data_out <= gated_data;
    end
endmodule
