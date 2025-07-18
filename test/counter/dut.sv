// Simple counter module to test more complex SystemVerilog constructs
module counter #(
    parameter WIDTH = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    output logic [WIDTH-1:0] count,
    output logic overflow
);

    logic [WIDTH-1:0] count_next;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else if (enable) begin
            count <= count_next;
        end
    end
    
    always_comb begin
        count_next = count + 1'b1;
        overflow = (count == {WIDTH{1'b1}}) && enable;
    end

endmodule