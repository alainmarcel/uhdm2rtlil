// Simple testbench for simple_always_ff
module testbench;
    logic clk;
    logic rst_n;
    logic mode;
    logic [7:0] extra_sum;
    logic [7:0] extra_result;
    
    simple_always_ff dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .extra_sum(extra_sum),
        .extra_result(extra_result)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        mode = 0;
        extra_sum = 8'h00;
        
        #20 rst_n = 1;
        #10 extra_sum = 8'hAA;
        #10 mode = 1;
        #20 mode = 0;
        #10 extra_sum = 8'h55;
        #10 mode = 1;
        #20 $finish;
    end
endmodule