module top(
    input [31:0] a,
    output reg [31:0] ox, oy, oz
);
    integer x, y, z;
    always_comb begin
        x = a; y = 0; z = 0;

        // post-increment/decrement as statements
        x++;           // x = a+1
        z--;           // z = -1

        // pre-increment/decrement as statements
        ++z;           // z = 0
        --x;           // x = a

        // pre-increment as expression
        z = ++x;       // x = a+1, z = a+1
        y = --x;       // x = a, y = a

        // nested assignment expressions
        x = (y = (z = 99) + 1) + 1;  // z=99, y=100, x=101

        // simple assignment expression
        z = (y = 0);   // y=0, z=0

        ox = x;
        oy = y;
        oz = z;
    end
endmodule
