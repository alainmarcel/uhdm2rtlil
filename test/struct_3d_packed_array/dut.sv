// PR 7 of the svtypes/struct_array.sv breakdown.
// 3D packed array with mixed endianness inside a struct.
// `bit [0:7][1:0][0:3]`: outer dim ascending, middle dim descending,
// innermost dim ascending.  Exercises chained bit-selects on a
// struct field (s.a[0][1] = '0).

module top;
    struct packed {
        bit [0:7][1:0][0:3] a;
    } s;

    initial begin
        s         = '0;
        s.a[0]    = '1;
        s.a[0][1] = '0;
    end

    always_comb assert(s == 64'h0F00_0000_0000_0000);
endmodule
