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

        // nested assignment expressions (using a-dependent values)
        x = (y = (z = y + 1) + 1) + 1;  // z=a+1, y=a+2, x=a+3

        // simple assignment expression
        z = (y = x);   // y=a+3, z=a+3

        ox = x;        // ox = a+3
        oy = y;        // oy = a+3
        oz = z;        // oz = a+3
    end
endmodule
