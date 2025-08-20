module test_sim3;
    integer j;
    reg [7:0] memory[0:7];
    integer i;
    
    initial begin
        j = 64'hF4B1CA8127865242;
        $display("j after assignment = 0x%08x", j);
        
        // Initialize memory with blockrom pattern
        for (i = 0; i <= 7; i = i + 1) begin
            memory[i] = j * 64'h2545F4914F6CDD1D;
            $display("memory[%0d] = 0x%02x (j = 0x%08x)", i, memory[i], j);
            j = j ^ (j >> 12);
            j = j ^ (j << 25);
            j = j ^ (j >> 27);
        end
        
        $finish;
    end
endmodule