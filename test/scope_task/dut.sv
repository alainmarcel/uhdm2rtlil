module scope_task(input [3:0] k, output reg [15:0] x, y);
    // Task with nested scope blocks
    task task_01;
        input [3:0] a;
        output [15:0] result;
        reg [15:0] temp;
        begin
            temp = a * 23;
            result = x + temp;  // Modifies output based on module's x
        end
    endtask

    // Task with multiple nested named blocks
    task task_02;
        input [3:0] a;
        output [15:0] result;
        begin:foo
            reg [15:0] x, z;
            x = y;  // Local x = module's y
            begin:bar
                reg [15:0] x;
                x = 77 + a;  // Nested local x
                z = -x;      // z = -(77 + a)
            end
            result = x ^ z;  // Local x XOR z
        end
    endtask

    reg [15:0] temp1, temp2;
    
    always @* begin
        x = 16'd60;  // Initial value
        y = 16'd0;   // Initial value
        
        // Call tasks that modify based on input
        task_01(k, temp1);
        x = temp1;
        
        task_02(k, temp2);
        y = temp2;
    end
endmodule