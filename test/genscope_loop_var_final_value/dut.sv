// A for-loop variable declared in a GENERATE scope (`begin : g  integer i;`)
// was left UNDRIVEN after the comb loop was unrolled: the post-loop value
// (i = 4 here, what read_verilog and read_slang drive) was looked up by the
// BARE name `i`, which misses the gen-scope wire `g.i`, so the wire was
// X-filled instead.  The module-scope twin `k` was fine.  The loop variable is
// observable through `iy`/`ky`, so the miter and the read_verilog comparison
// both see the missing driver.
module genscope_loop_var_final_value (
  input  logic [3:0] a,
  input  logic       en,
  output logic [3:0] y,
  output logic [3:0] z,
  output logic [31:0] iy,
  output logic [31:0] ky
);
  generate if (1) begin : g
    integer i;
    logic [3:0] t;
    always @* begin
      t = 4'd0;
      for (i = 0; i < 4; i = i + 1)
        if (a[i]) t[i] = en;
    end
    assign y  = t;
    assign iy = i;
  end endgenerate
  integer k;
  logic [3:0] u;
  always @* begin
    u = 4'd0;
    for (k = 0; k < 4; k = k + 1)
      if (a[k]) u[k] = en;
  end
  assign z  = u;
  assign ky = k;
endmodule
