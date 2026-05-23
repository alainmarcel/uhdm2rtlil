// PR 8 of the svtypes/struct_array.sv breakdown.
// Tests an unpacked array nested inside a packed struct
// (Yosys-specific extension; Surelog parses it as a struct member
// with non-empty unpacked dimensions).  The struct flattens to
// `{a[3], a[2], a[1], a[0], b}` (highest unpacked index = MSB end).

module top;
    struct packed {
        bit [7:0] a [4];
        bit [7:0] b;
    } s;

    initial begin
        s      = '0;
        s.a[2] = 8'h42;
        s.b    = 8'hFF;
    end

    always_comb assert(s == 40'h00_42_00_00_FF);
endmodule
