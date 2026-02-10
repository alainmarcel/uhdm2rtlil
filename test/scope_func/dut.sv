module scope_func(input [3:0] k, output reg [15:0] x, y);
    // Function with nested scope that shadows variables
    function [15:0] func_01;
        input [15:0] x, y;
       // begin
            func_01 = x + y;  // Initial computation
            //begin:blk
             //   reg [15:0] x;  // Local x that shadows parameter
             //   x = y;         // Local x = y
             //   func_01 = func_01 ^ x;  // XOR with local x
            //end
            //func_01 = func_01 ^ x;  // XOR with parameter x
      //  end
    endfunction

    always @* begin
        // Call with constants - should still generate logic in comb always
        //x = func_01(16'd11, 16'd22);
        x = 1;
       
        // Call with variables that depend on input
        y = func_01(x + k, x);
    end
endmodule
