// Minimal isolation test for int_types failing assertions.
// Focuses on: integer (32-bit signed, is_signed=1)
//   - assert 4: (a == -1) == 1   [was failing: -1 generated as 64-bit, zero-extended]
// and: reg signed (1-bit signed, is_signed=1)
//   - assert 2: a == b            [was failing]
//   - assert 3: a == c            [was failing]
module top;

    // --- integer (32-bit signed) ---
    integer x_int = -1;
    localparam integer y_int = -1;
    logic [127:0] a_int = x_int;
    logic [127:0] b_int = y_int;
    function automatic integer f_int;
        input integer inp;
        f_int = inp;
    endfunction
    logic [127:0] c_int = f_int(-1);
    always @* begin
        assert (x_int == y_int);        // assert 1
        assert (a_int == b_int);        // assert 2
        assert (a_int == c_int);        // assert 3
        assert ((a_int == -1) == 1);    // assert 4: is_signed=1
    end

    // --- reg signed (1-bit signed) ---
    reg signed x_reg = -1;
    localparam reg signed y_reg = -1;
    logic [127:0] a_reg = x_reg;
    logic [127:0] b_reg = y_reg;
    function automatic reg signed f_reg;
        input reg signed inp;
        f_reg = inp;
    endfunction
    logic [127:0] c_reg = f_reg(-1);
    always @* begin
        assert (x_reg == y_reg);        // assert 1
        assert (a_reg == b_reg);        // assert 2
        assert (a_reg == c_reg);        // assert 3
        assert ((a_reg == -1) == 1);    // assert 4: is_signed=1
    end

endmodule
