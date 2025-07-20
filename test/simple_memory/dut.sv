module simple_memory #(
    parameter WIDTH = 8,
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = 4
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  we,           // write enable
    input  wire [ADDR_WIDTH-1:0] addr,        // address
    input  wire [WIDTH-1:0]      data_in,     // write data
    output reg  [WIDTH-1:0]      data_out     // read data
);

    // Memory array
    reg [WIDTH-1:0] memory [0:DEPTH-1];
    
    // Initialize memory to zero on reset
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                memory[i] <= {WIDTH{1'b0}};
            end
            data_out <= {WIDTH{1'b0}};
        end else begin
            // Write operation
            if (we) begin
                memory[addr] <= data_in;
            end
            
            // Read operation (always)
            data_out <= memory[addr];
        end
    end

endmodule