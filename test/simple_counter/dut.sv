// Simple test with just multi-bit signal
module simple_counter (
    input  logic clk,
    input  logic rst_n,
    output logic [7:0] count
);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'b0;
        end else begin
            count <= count + 1'b1;
        end
    end

endmodule