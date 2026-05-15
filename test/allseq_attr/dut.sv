// Tests that `(* allseq *)` is lowered to a `$allseq` cell.  Like
// `$anyseq`, `$allseq` re-samples each cycle; the `$stable(x)`
// assertion is purely there to exercise the same end-to-end lowering
// path (anyconst/anyseq/allconst/allseq → $check cell → DFF for $past).
module allseq_attr (
    input  wire       clock,
    output reg [7:0]  x_out,
    output reg        f_past_valid
);
    (* allseq *) reg [7:0] x;

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
