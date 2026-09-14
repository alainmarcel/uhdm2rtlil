// A generate-scope genvar inside an arithmetic index (OpenTitan prim_prince:
// `PRINCE_ROUND_CONST[10-NumRoundsHalf+k]` in `gen_bwd_pass[k]`) when the
// module sits inside an ANCESTOR generate loop that uses the same genvar name
// (prim_ram_1p_scr's `gen_par_scr[k]`, k = 0), two paramod levels down.  The
// importer handed the operation to Surelog's ExprEval from the MODULE
// instance; its name walk misses the generate scope, finds the ancestor's `k`
// and folded every backward-pass index to 10-3+0 = 7 — the sram_ctrl
// keystream was wrong (invisible to a write-then-read co-sim, caught by the
// seq-4 miter).  Operations with a generate-scope parameter operand are now
// folded by the reader from the ref_obj's own binding.
package gea_pkg;
  parameter logic [11:0][63:0] RC = {64'h0123456789abcdef, 64'hfedcba9876543210, 64'h1111111111111111, 64'h2222222222222222,
                                     64'h3333333333333333, 64'h4444444444444444, 64'h5555555555555555, 64'h6666666666666666,
                                     64'h7777777777777777, 64'h8888888888888888, 64'h9999999999999999, 64'haaaaaaaaaaaaaaaa};
endpackage
module gea_child #(parameter int DataWidth = 64, parameter int NumRoundsHalf = 5, parameter bit HalfwayDataReg = 1'b0) (
  input logic clk_i, input logic rst_ni,
  input logic [DataWidth-1:0] d_i, output logic [DataWidth-1:0] o_o);
  logic [NumRoundsHalf:0][DataWidth-1:0] lo, hi;
  assign lo[0] = d_i;
  for (genvar k = 1; k <= NumRoundsHalf; k++) begin : gen_fwd_pass
    logic [DataWidth-1:0] r;
    if (DataWidth == 64) begin : gen_fwd_d64
      always_comb r = ~lo[k-1];
    end else begin : gen_fwd_d32
      always_comb r = lo[k-1];
    end
    assign lo[k] = r ^ gea_pkg::RC[k][DataWidth-1:0];
  end
  logic [DataWidth-1:0] mid_d, mid_q;
  assign mid_d = lo[NumRoundsHalf];
  if (HalfwayDataReg) begin : gen_data_reg
    always_ff @(posedge clk_i or negedge rst_ni) if (!rst_ni) mid_q <= '0; else mid_q <= mid_d;
  end else begin : gen_no_data_reg
    assign mid_q = mid_d;
  end
  assign hi[0] = mid_q;
  for (genvar k = 1; k <= NumRoundsHalf; k++) begin : gen_bwd_pass
    logic [DataWidth-1:0] x0, x1, b;
    assign x0 = hi[k-1] ^ d_i;
    assign x1 = x0 ^ gea_pkg::RC[10-NumRoundsHalf+k][DataWidth-1:0];
    if (DataWidth == 64) begin : gen_bwd_d64
      always_comb begin b = ~x1; hi[k] = b; end
    end else begin : gen_bwd_d32
      always_comb begin b = x1; hi[k] = b; end
    end
  end
  assign o_o = hi[NumRoundsHalf] ^ gea_pkg::RC[11][DataWidth-1:0];
endmodule
module gea_mid #(parameter int Width = 64, parameter int NumParScr = 1, parameter int NumPrinceRoundsHalf = 3) (
  input logic clk_i, input logic rst_ni, input logic [Width-1:0] d_i, output logic [Width-1:0] o_o);
  logic [63:0] ks [NumParScr];
  for (genvar k = 0; k < NumParScr; k++) begin : gen_par_scr
    gea_child #(.DataWidth(64), .NumRoundsHalf(NumPrinceRoundsHalf), .HalfwayDataReg(1'b1)) u_prince (
      .clk_i, .rst_ni, .d_i(d_i[63:0] ^ 64'(k)), .o_o(ks[k]));
  end
  assign o_o = ks[0][Width-1:0];
endmodule
module genvar_exprfold_ancestor_shadow #(parameter int NumPrinceRoundsHalf = 3) (input logic clk_i, input logic rst_ni, input logic [63:0] d_i, output logic [63:0] o_o);
  gea_mid #(.Width(64), .NumParScr(1), .NumPrinceRoundsHalf(NumPrinceRoundsHalf)) u_mid (.clk_i, .rst_ni, .d_i, .o_o);
endmodule
