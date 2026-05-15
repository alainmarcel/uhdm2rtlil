// Tests that `(* allconst *)` is lowered to a `$allconst` cell.  In
// formal verification `allconst` is the universal-quantification dual
// of `anyconst`; structurally the lowering is identical — a `$allconst`
// cell whose Y output drives the wire.
module allconst_attr (
    input  wire       clock,
    output reg [7:0]  x_out,
    output reg        f_past_valid
);
    (* allconst *) reg [7:0] x;

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
