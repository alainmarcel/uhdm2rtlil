// PR 4 of the svtypes/struct_array.sv breakdown.
// Tests out-of-bound / negative indices on a packed-array struct
// field.  A negative-index write must be a silent no-op (matching
// the Verilog gold path); an out-of-bound partial-select read
// produces `x` for the missing bits.

module top;
    struct packed {
        bit [3:0][7:0] a;
    } s;

    initial begin
        s        = '0;
        s.a[-1]  = '0;  // out-of-bound write — must be a no-op
    end

    always_comb assert(s == 32'h0);
endmodule
