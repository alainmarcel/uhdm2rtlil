// PR 2 of the svtypes/struct_array.sv breakdown.
// Tests a bit-range write into a packed-struct field (part-select LHS
// inside a hier_path).

module top;
    struct packed {
        bit [15:0] b;
    } s;

    initial begin
        s.b      = '1;
        s.b[1:0] = '0;
    end

    always_comb assert(s == 16'hFFFC);
endmodule
