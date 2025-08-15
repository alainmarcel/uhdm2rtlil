module simple_memory_noreset (
    input  logic       clk,
    input  logic       we,
    input  logic [3:0] addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);

    // Simple memory array with packed and unpacked dimensions
    logic [7:0] memory [0:15];

    // Memory read/write process
    always_ff @(posedge clk) begin
        if (we) begin
            memory[addr] <= data_in;
        end
        data_out <= memory[addr];
    end

endmodule