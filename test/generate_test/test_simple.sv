module test_simple (
    input  logic clk,
    input  logic rst_n,
    input  logic [31:0] data_in,
    output logic [31:0] result
);
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_ff
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result[i*8 +: 8] <= '0;
                end else begin
                    result[i*8 +: 8] <= data_in[i*8 +: 8];
                end
            end
        end
    endgenerate
endmodule