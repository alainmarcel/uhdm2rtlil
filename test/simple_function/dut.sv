// Simple function test: function -> continuous assignment -> flip-flop
module simple_function (
    input  logic clk,
    input  logic rst,
    input  logic a,
    input  logic b, 
    input  logic c,
    output logic q
);

    // Function that implements AND-OR tree
    function logic and_or_tree;
        input logic x, y, z;
        begin
            // (x & y) | z
            and_or_tree = (x & y) | z;
        end
    endfunction

    // Intermediate wire driven by continuous assignment using the function
    logic d;
    assign d = and_or_tree(a, b, c);

    // Sequential always block for flip-flop
    always_ff @(posedge clk) begin
        if (rst)
            q <= 1'b0;
        else
            q <= d;
    end

endmodule