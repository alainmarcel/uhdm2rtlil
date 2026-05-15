module MultiDimHierPath8 (
    input logic [3:0] a,
    input logic [3:0] b,
    output logic [1:0][3:0] out
);
    typedef logic [3:0] logic4;

    struct packed {
        logic4 [2:0] vector3x4;
    } s;

    assign s.vector3x4[1] = a;
    assign s.vector3x4[2] = b;

    assign out = s.vector3x4[2:1];

endmodule
