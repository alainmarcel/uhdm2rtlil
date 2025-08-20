module test_sim;
    parameter DATA_WIDTH = 8;
    parameter ADDRESS_WIDTH = 3;
    localparam WORD = DATA_WIDTH - 1;
    localparam DEPTH = (2 ** ADDRESS_WIDTH) - 1;
    
    reg [DATA_WIDTH-1:0] memory [0:DEPTH];
    integer i;
    logic [63:0] j;
    
    initial begin
        j = 64'hF4B1CA8127865242;
        for (i = 0; i <= DEPTH; i++) begin
            memory[i] = j * 64'h2545F4914F6CDD1D;
            $display("memory[%0d] = 0x%02x, j = 0x%016x", i, memory[i], j);
            j = j ^ (j >> 12);
            j = j ^ (j << 25);
            j = j ^ (j >> 27);
        end
        $finish;
    end
endmodule