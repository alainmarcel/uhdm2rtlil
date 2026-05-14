module MultiDimHierPath9 (
    input logic [3:0] a,
    input logic [3:0] b,
    output logic [1:0][3:0] out
);

    typedef logic [3:0] logic4;

    function automatic logic4 [1:0] f(logic4 a, logic4 b);
        logic4 [1:0] out;
        out[0] = a;
        out[1] = b;
        return out;
    endfunction

    logic4 [1:0] vector2x4;
    assign vector2x4 = f(a, b);

    assign out = vector2x4;

endmodule
