// Tests that `(* anyseq *)` is lowered to a `$anyseq` cell.  Unlike
// `$anyconst`, `$anyseq` may produce a new value each cycle, so the
// `$stable(x)` assertion would not formally hold — that doesn't matter
// here: we only need the cells to be emitted correctly so the
// UHDM-frontend output matches the Verilog frontend.
module anyseq_attr (
    input  wire       clock,
    output reg [7:0]  x_out,
    output reg        f_past_valid
);
    (* anyseq *) reg [7:0] x;

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
