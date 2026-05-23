// PR 3 of the svtypes/struct_array.sv breakdown.
// Tests writing ranges and single elements of a packed-array
// struct field (`s.a[1:0] = ...` and `s.a[3] = ...`).

module top;
    struct packed {
        bit [3:0][7:0] a;
    } s;

    initial begin
        s        = '0;
        s.a[1:0] = 16'h1234;
        s.a[3]   = 8'h42;
    end

    always_comb assert(s == 32'h4200_1234);
endmodule
