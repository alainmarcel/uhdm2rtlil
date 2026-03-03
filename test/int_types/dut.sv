// Test integer atom types and integer vector types
// Focuses on width and signedness behavior of each type
module top;
    // integer: 32-bit, signed by default
    if (1) begin : test_integer
        integer x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (x == -1);
            assert (a == {128{1'b1}});  // sign-extended -1
        end
    end

    // integer unsigned: 32-bit, unsigned
    if (1) begin : test_integer_unsigned
        integer unsigned x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == 128'hFFFFFFFF);  // zero-extended
        end
    end

    // int: same as integer (32-bit signed)
    if (1) begin : test_int
        int x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (x == -1);
            assert (a == {128{1'b1}});
        end
    end

    // int unsigned: 32-bit unsigned
    if (1) begin : test_int_unsigned
        int unsigned x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == 128'hFFFFFFFF);
        end
    end

    // shortint: 16-bit signed
    if (1) begin : test_shortint
        shortint x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (x == -1);
            assert (a == {128{1'b1}});
        end
    end

    // shortint unsigned: 16-bit unsigned
    if (1) begin : test_shortint_unsigned
        shortint unsigned x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == 128'hFFFF);
        end
    end

    // longint: 64-bit signed
    if (1) begin : test_longint
        longint x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (x == -1);
            assert (a == {128{1'b1}});
        end
    end

    // longint unsigned: 64-bit unsigned
    if (1) begin : test_longint_unsigned
        longint unsigned x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == 128'hFFFFFFFFFFFFFFFF);
        end
    end

    // byte: 8-bit signed
    if (1) begin : test_byte
        byte x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (x == -1);
            assert (a == {128{1'b1}});
        end
    end

    // byte unsigned: 8-bit unsigned
    if (1) begin : test_byte_unsigned
        byte unsigned x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == 128'hFF);
        end
    end

    // logic signed: explicit signed vector type (1-bit)
    if (1) begin : test_logic_signed
        logic signed x = 1'b1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == {128{1'b1}});  // sign-extended
        end
    end

    // logic unsigned: unsigned 1-bit vector
    if (1) begin : test_logic_unsigned
        logic x = 1'b1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == 128'h1);  // zero-extended
        end
    end

    // logic signed [7:0]: explicit 8-bit signed
    if (1) begin : test_logic8_signed
        logic signed [7:0] x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == {128{1'b1}});  // sign-extended
        end
    end

    // logic [7:0]: 8-bit unsigned
    if (1) begin : test_logic8_unsigned
        logic [7:0] x = -1;
        logic [127:0] a;
        always @* begin
            a = x;
            assert (a == 128'hFF);  // zero-extended
        end
    end
endmodule
