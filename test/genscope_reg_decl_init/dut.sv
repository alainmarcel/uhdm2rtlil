// A `reg` with a DECLARATION INITIALIZER inside a `generate` block, driven by
// an always block in the same scope.
//
// Surelog models `reg [7:0] r = 8'h00;` as a cont_assign with
// `vpiNetDeclAssign:1`.  At module scope the importer turns that into an
// `\init` ATTRIBUTE (correct: it is the register's initial value).  In a
// generate scope it emitted a constant `connect` instead, on the assumption
// that "a gen-scope net declaration has no FF driver".  That is false as soon
// as the scope also has an always block: the constant became a SECOND driver,
// `opt` resolved it in favour of the constant, and the flop — plus every cell
// behind it — was deleted.
//
// Alex Forencich's verilog-axis / verilog-ethernet / verilog-pcie declare
// every register that way inside `generate` (15 of them in axis_register
// alone), so `axis_register` came out of read_uhdm with ZERO cells and ~280 of
// 301 co-sim cycles diverged.  The same shape is behind dozens of rows in both
// sweeps.
//
// The module-scope register is kept alongside as the control: it was always
// correct, and it must stay correct.  The two registers compute DIFFERENT
// values on purpose — identical ones get merged by `opt` and the missing flop
// is invisible.
`default_nettype none
module genscope_reg_decl_init #(parameter EN = 1)
(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] d,
    output wire [7:0] q,
    output wire [7:0] qm
);

// module-scope reg with a declaration initializer: handled correctly today
reg [7:0] mod_reg = 8'h00;
always @(posedge clk) begin
    if (rst) mod_reg <= 8'h00;
    else     mod_reg <= d;
end
assign qm = mod_reg;

generate
if (EN) begin
    // SAME shape, but inside a generate block
    reg [7:0] gen_reg = 8'h00;
    always @(posedge clk) begin
        if (rst) gen_reg <= 8'h00;
        else     gen_reg <= d + 8'd1;
    end
    assign q = gen_reg;
end else begin
    assign q = 8'h00;
end
endgenerate
endmodule
