// Write-then-read / read-modify-write of a combinational variable in always_comb.
// Mirrors Ibex ibex_compressed_decoder's cm_rlist_d:
//   x = q;                 // default from a register
//   if (sel) x = init;     // conditional overwrite
//   if (x <= 3) ...        // READ x (must see the written value)
//   else       x -= 1;     // READ-MODIFY-WRITE x  (x = x - 1)
//   y = f(x);              // READ x again
// A naive importer feeds the FINAL x net back into `x - 1`, forming a
// combinational loop x -> (x-1) -> mux -> x.  The read must instead see the
// value accumulated so far in the block.
module rmw_comb_var (
    input  logic       clk,
    input  logic       sel,
    input  logic [4:0] init,
    output logic [4:0] y,
    output logic [4:0] x_q
);
    logic [4:0] x_d, x_reg;

    always_comb begin
        x_d = x_reg;
        if (sel) begin
            x_d = init;
            if (x_d <= 5'd3) begin
                x_d = 5'd0;
            end else begin
                x_d -= 5'd1;
            end
        end
    end

    assign y = x_d;

    always_ff @(posedge clk) x_reg <= x_d;
    assign x_q = x_reg;
endmodule
