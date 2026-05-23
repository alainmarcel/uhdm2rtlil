// PR 6 of the svtypes/struct_array.sv breakdown.
// Tests ascending-range packed arrays inside a struct.
// `bit [0:7][7:0]` flips the outer dimension's element ordering
// relative to the descending form covered by PR 3.

module top;
    struct packed {
        bit [0:7][7:0] a;
    } s;

    initial begin
        s        = '0;
        s.a[2]   = 8'h42;
        s.a[5:6] = 16'h1234;
    end

    always_comb assert(s == 64'h00_42_00_00_00_12_34_00);
endmodule
