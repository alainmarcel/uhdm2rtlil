// Minimal test for struct field write in an initial block.
// After `s = '0`, the named-field write `s.a = 8'h42` must land in
// the corresponding slice of s — gold drives s via $0\s temp wire.

module top;
    struct packed {
        bit [7:0] a;
        bit [7:0] b;
    } s;

    initial begin
        s = '0;
        s.a = 8'h42;
    end

    always_comb assert(s == 16'h4200);
endmodule
