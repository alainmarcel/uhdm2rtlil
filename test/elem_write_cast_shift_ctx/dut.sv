// A size cast of a SHIFT, written into a packed-array ELEMENT inside a comb
// for-loop: `enc[i] = 24'(c[i] << 13)` (adams-bridge pkdecode's coefficient
// encoder).  The element-write path imported the right-hand side with no
// context width, so the 10-bit `c[i] << 13` was sized by itself and every
// bit fell off the top before the cast widened it -- all eight encoded
// coefficients were 0 (84 diverging co-simulated cycles, read_slang clean).
// The same expression assigned to a plain 24-bit wire was already right.  The
// element writes now import their right-hand side under the element's width,
// as every other assignment path does.
module dut (
    input  logic [7:0][9:0]  c,
    input  logic [9:0]       a,
    output logic [7:0][23:0] enc,
    output logic [23:0]      direct
);
    localparam SHIFT_LEFT = 13;
    always_comb begin
        for (int i = 0; i < 8; i++)
            enc[i] = 24'(c[i] << SHIFT_LEFT);
    end
    assign direct = 24'(a << SHIFT_LEFT);
endmodule
