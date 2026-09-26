// A net-declaration initialiser NARROWER than its reg -- `reg [7:0] tag_reg =
// 7'd0, tag_next;` (verilog-pcie pcie_us_axil_master) -- was widened through
// a $pos cell, which made the RHS a wire instead of a constant; the
// initialiser then took the non-constant path and became a continuous
// `connect \tag_reg 8'0` that double-drove the flop, which folded to 0 (the
// completion TLP's tag was always 0: 279 co-sim divergences).  The sibling
// `t2_reg = 8'd0` with a matching width got the \init attribute and was fine.
// The miter must run a full `opt` so the double driver is not vacuous.
module regdecl_init_narrower_than_reg (
  input  logic         clk,
  input  logic         rst,
  input  logic [127:0] d,
  input  logic         en,
  output logic [7:0]   q,
  output logic [7:0]   q2,
  output logic         st
);
  reg [7:0] tag_reg = 7'd0, tag_next;
  reg [7:0] t2_reg  = 8'd0, t2_next;
  reg       state_reg = 1'b0, state_next;
  always @* begin
    tag_next   = tag_reg;
    t2_next    = t2_reg;
    state_next = state_reg;
    if (en) begin
      tag_next   = d[103:96];
      t2_next    = d[103:96];
      state_next = ~state_reg;
    end
  end
  always @(posedge clk) begin
    if (rst) state_reg <= 1'b0;
    else     state_reg <= state_next;
    tag_reg <= tag_next;
    t2_reg  <= t2_next;
  end
  assign q  = tag_reg;
  assign q2 = t2_reg;
  assign st = state_reg;
endmodule
