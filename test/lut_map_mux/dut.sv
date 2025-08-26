module lut_map_mux(
    input a, b, s,
    output y
);
    assign y = s ? a : b;
endmodule