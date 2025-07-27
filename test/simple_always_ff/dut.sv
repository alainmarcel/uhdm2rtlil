// Simple test case for always_ff with else-if structure
module simple_always_ff (
    input  logic clk,
    input  logic rst_n,
    input  logic mode,
    input  logic [7:0] extra_sum,
    output logic [7:0] extra_result
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            extra_result <= '0;
        end else if (mode) begin
            extra_result <= extra_sum;
        end
    end

endmodule