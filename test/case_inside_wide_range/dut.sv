// `case (x) inside [lo:hi]` with a WIDE range (cheshire clic's register
// decode: `[MCLICINT_START:MCLICINT_END]` = 'h1000..'h4fff, 16384 values).
// read_uhdm enumerated a range one compare value per element and silently
// stopped after 4096, so every address above 'h1fff took the default arm.
module dut (
    input  logic [31:0] addr,
    input  logic [3:0]  a,
    input  logic [3:0]  b,
    output logic [3:0]  y
);
    localparam int unsigned ADDR_W = 16;
    localparam logic [ADDR_W-1:0] CFG_START = 'h00000;
    localparam logic [ADDR_W-1:0] INT_START = 'h01000;
    localparam logic [ADDR_W-1:0] INT_END   = 'h04fff;
    localparam logic [ADDR_W-1:0] S_START   = 'h08000;
    always_comb begin
        y = '0;
        unique case (addr[ADDR_W-1:0]) inside
            CFG_START:           y = a;
            [INT_START:INT_END]: y = b;
            S_START:             y = 4'h3;
            [16'h9001:16'h9ffe]: y = 4'h5;
            default:             y = 4'hF;
        endcase
    end
endmodule
