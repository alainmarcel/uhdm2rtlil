module param_test #(
    parameter WIDTH = 8,
    parameter DEPTH = 16,
    parameter INIT_VALUE = 8'hAA
) (
    input  wire             clk,
    input  wire             rst,
    input  wire [WIDTH-1:0] data_in,
    output reg  [WIDTH-1:0] data_out
);

    // Simple register with parameterized width
    always @(posedge clk) begin
        if (rst)
            data_out <= INIT_VALUE;
        else
            data_out <= data_in;
    end

endmodule