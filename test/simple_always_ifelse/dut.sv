module simple_always_ifelse #(
    parameter DATA_WIDTH = 8
) (
    input  logic                clk,
    input  logic                rst_n,
    input  logic [DATA_WIDTH-1:0] unit_result,
    output logic [31:0]         result
);
    
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_blocks
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result[i*DATA_WIDTH +: DATA_WIDTH] <= '0;
                end else begin
                    result[i*DATA_WIDTH +: DATA_WIDTH] <= unit_result;
                end
            end
        end
    endgenerate
    
endmodule