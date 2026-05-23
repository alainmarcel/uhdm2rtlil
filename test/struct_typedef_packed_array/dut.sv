// PR 5 of the svtypes/struct_array.sv breakdown.
// Tests width computation for a typedef'd packed-array field — Surelog
// previously dropped the outer dimension of `bit8_t [3:0]` (the bit-
// based typedef wrapper was missing in CompileType.cpp::compileTypespec).

module top;
    typedef bit [7:0] bit8_t;
    struct packed {
        bit8_t [3:0] a;
        bit [15:0]   b;
    } s;

    initial s = '0;

    always_comb assert($bits(s) == 48);
endmodule
