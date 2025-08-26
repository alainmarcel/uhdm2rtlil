module lut_map_or(
    input a, b,
    output y
);
    assign y = a | b;
endmodule