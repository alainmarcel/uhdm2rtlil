// casez / casex item values with `z` / `x` wildcard bits (`4'bzzz1`) were
// imported as LITERAL z bits in the RTLIL switch compare, which never
// matches (only State::Sa is a don't-care to `proc`), so every wildcard arm
// was dead: verilog-pcie pcie_us_axil_master's `casez (first_be_reg)` lower
// address / byte count fields were always 0 (279 co-sim divergences).  The
// existing Casezx test used whole-variable writes with a default, where the
// read_verilog comparison did not catch it; this one covers the four paths:
//  * comb casez with PARTIAL LHS writes and no default (`lo`, `bc`)
//  * a read of the casez result later in the SAME block (`rd`: the in-flight
//    threading used to bail on wildcards)
//  * a casez inside an always_ff with a reset (the sync-path case importer)
//  * casex (`x` and `z` both wildcards)
module casez_wildcard_partial_lhs (
  input  logic       clk,
  input  logic       rst,
  input  logic [3:0] be,
  input  logic [6:2] addr,
  output logic [31:0] y,
  output logic [7:0]  rd,
  output logic [3:0]  q,
  output logic [1:0]  cx
);
  always @* begin
    y = 32'd0;
    casez (be)
      4'b0000: y[6:0] = {addr, 2'b00};
      4'bzzz1: y[6:0] = {addr, 2'b00};
      4'bzz10: y[6:0] = {addr, 2'b01};
      4'bz100: y[6:0] = {addr, 2'b10};
      4'b1000: y[6:0] = {addr, 2'b11};
    endcase
    casez (be)
      4'b0000: y[28:16] = 13'd1;
      4'b0001: y[28:16] = 13'd1;
      4'b0010: y[28:16] = 13'd1;
      4'b0011: y[28:16] = 13'd2;
      4'b0110: y[28:16] = 13'd2;
      4'b01z1: y[28:16] = 13'd3;
      4'b1z10: y[28:16] = 13'd3;
      4'b1zz1: y[28:16] = 13'd4;
    endcase
    rd = y[7:0] + y[23:16];   // read-after-casez in the same block
  end
  always @(posedge clk) begin
    if (rst) q <= 4'd0;
    else begin
      casez (be)
        4'b1???: q <= 4'd8;
        4'b01zz: q <= 4'd4;
        4'b001z: q <= 4'd2;
        default: q <= q + 1'b1;
      endcase
    end
  end
  always @* begin
    cx = 2'd0;
    casex (be)
      4'b1xzx: cx = 2'd3;
      4'b01xx: cx = 2'd2;
      4'b001x: cx = 2'd1;
    endcase
  end
endmodule
