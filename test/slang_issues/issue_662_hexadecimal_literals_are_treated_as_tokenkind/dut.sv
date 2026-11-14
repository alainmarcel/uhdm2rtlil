// MikePopoloski/slang#662 (closed): Hexadecimal literals are treated as TokenKind::Identifier
// https://github.com/MikePopoloski/slang/issues/662
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module a;
    localparam b = 4'hd;
    localparam c = 12'hffa;
    localparam d = 32'hffaaffff;
    localparam e = 32'd123;

    logic ia;
    logic ib;
    logic ic;

    always_ff @(posedge ia) begin
        ib <= ic;
    end
endmodule

