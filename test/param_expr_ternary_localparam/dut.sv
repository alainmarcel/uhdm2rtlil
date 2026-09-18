// Regression for the Caliptra chip co-sim's `s_axi_w_if_bresp` divergence.
//
// caliptra_top passes soc_ifc_top's address width as an EXPRESSION
// (`.AXI_ADDR_WIDTH($clog2((MASK >> 32) & '1))`).  Surelog then leaves the
// dependent localparam inside axi_addr unfolded:
//
//     localparam IN_AW = (AW >= 12) ? 12 : AW;
//
// and a fully-constant `?:` was never folded by the reader — it always became
// a $mux — so the localparam was "non-constant", defaulted to 0, and every
// `reg [IN_AW-1:0]` collapsed to ONE BIT.  The AXI read address then never
// incremented and the chip answered a write with SLVERR.
module inner #(parameter AW = 32) (
  input  logic [AW-1:0] a,
  output logic [AW-1:0] y,
  output logic [31:0]   w
);
  localparam int IN_AW = (AW >= 12) ? 12 : AW;
  localparam int LOW   = (AW > 4) ? 4 : 1;
  logic [IN_AW-1:0] t;
  logic [LOW-1:0]   u;
  always_comb t = a[IN_AW-1:0] + 1'b1;
  always_comb u = a[LOW-1:0] ^ {LOW{1'b1}};
  assign y = {{(AW-IN_AW){1'b0}}, t} ^ {{(AW-LOW){1'b0}}, u};
  assign w = IN_AW * 100 + LOW;   // observable: the localparam values themselves
endmodule

module dut #(parameter W = $clog2((320'h0007ffff_00000000 >> (32*1)) & {32{1'b1}})) (
  input  logic [W-1:0] a,
  output logic [W-1:0] y,
  output logic [31:0]  w
);
  inner #(.AW(W)) u (.a(a), .y(y), .w(w));
endmodule
