// A packed array declared over a TYPEDEF in a CHILD module, read with a
// dynamic index.  In the module definition the bit_select carries no
// Actual_group, and the definition's own net of that name is the only thing
// that knows the declared geometry (`type_mprf_v [1:31] mprf_int`: a
// logic_typespec with the outer range and the typedef as Elem_typespec).  The
// element read `mprf_int[ra]` came out as ONE BIT of the flat array while the
// write beside it placed the full 32-bit element -- SCR1's register file,
// where every rs1/rs2 read of a written register returned 0.  The top-level
// module read fine (its elaborated packed_array_var was found by name), so the
// array MUST live in a child instance here.
//
// The reset is ACTIVE-HIGH (SCR1's is `negedge rst_n`): every flop here has an
// enable, and the co-sim's clock/reset extractor reads the polarity only off
// `$_DFF_*` / `$_SDFF_*` cell names, not `$_DFFE_*`, so an active-low reset
// would be driven high and the co-sim would sit in reset (vacuous).  The
// defect is in the combinational read; the reset style is immaterial to it.
typedef logic [31:0] type_mprf_v;

module mprf (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  ra,
    input  logic [4:0]  wa,
    input  logic        we,
    input  logic [31:0] wd,
    output logic [31:0] rd
);
    logic rs_vd, wr_vd;
    type_mprf_v [1:31] mprf_int;
    assign rs_vd = |ra;
    assign wr_vd = we & |wa;
    assign rd = rs_vd ? mprf_int[ra] : '0;
    always_ff @(posedge clk, posedge rst) begin
        if (rst)          mprf_int <= '0;
        else if (wr_vd)   mprf_int[wa] <= wd;
    end
endmodule : mprf

module dut (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  ra,
    input  logic [4:0]  wa,
    input  logic        we,
    input  logic [31:0] wd,
    output logic [31:0] rd
);
    mprf i_mprf (.clk, .rst, .ra, .wa, .we, .wd, .rd);
endmodule
