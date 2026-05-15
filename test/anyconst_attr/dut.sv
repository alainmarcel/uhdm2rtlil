// Reduced reproducer for `(* anyconst *)` attribute dropped by the
// UHDM frontend (originally `read_systemverilog`).  Wrapped to expose
// the formal signal on a module output so co-sim / equivalence can
// inspect it.
//
// Expected: Yosys synthesizes `(* anyconst *) reg [7:0] x` into a
// `$anyconst` cell whose Y output drives `x`.  The Verilog frontend
// emits this cell; the UHDM frontend used to silently drop the
// attribute, leaving `x` undriven so downstream logic was constant-
// folded away.
module anyconst_attr (
    input  wire       clock,
    output reg [7:0]  x_out,
    output reg        f_past_valid
);
    (* anyconst *) reg [7:0] x;

    initial begin
        f_past_valid = 1'b0;
        x_out        = 8'h00;
    end

    always @(posedge clock) begin
        f_past_valid <= 1'b1;
        if (f_past_valid) assert($stable(x));
        x_out        <= x;
    end
endmodule
