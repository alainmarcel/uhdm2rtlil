module dffe #(parameter width_p = 1) (input logic clk, input logic en, input logic [width_p-1:0] d, output logic [width_p-1:0] q);
  always_ff @(posedge clk) if (en) q <= d;
endmodule
module muxb #(parameter width_p = 1) (input logic [width_p-1:0] a, input logic [width_p-1:0] b, input logic s, output logic [width_p-1:0] y);
  logic [width_p-1:0] t;
  assign t = a - 1;
  assign y = s ? b : t;
endmodule
module repl #(parameter els_p = 2, parameter scheme_p = "lru", parameter safe_els_lp = (els_p > 1) ? els_p : 1)
  (input logic clk, input logic touch_i, input logic [safe_els_lp-1:0] sel_i, output logic [safe_els_lp-1:0] way_o);
  if (scheme_p == "lru") begin : lru
  logic [els_p-2:0] lru_n, lru_r;
  dffe #(.width_p(els_p-1)) lru_reg (.clk(clk), .en(touch_i), .d(lru_n), .q(lru_r));
  muxb #(.width_p(els_p-1)) upd_mux (.a(lru_r), .b(sel_i[els_p-2:0]), .s(touch_i), .y(lru_n));
  assign way_o = {1'b0, lru_r} ^ sel_i;
  end
endmodule
module top #(parameter els_4k_p, parameter vtag_width_p = 8)
  (input logic clk, input logic [vtag_width_p-1:0] vtag_i, input logic v_i, output logic [vtag_width_p-1:0] y);
  logic [vtag_width_p-1:0] vtag_r;
  dffe #(.width_p(vtag_width_p)) vtag_reg (.clk(clk), .en(v_i), .d(vtag_i), .q(vtag_r));
  logic [els_4k_p-1:0] way;
  repl #(.els_p(els_4k_p)) replacement_4k (.clk(clk), .touch_i(v_i), .sel_i(vtag_r[els_4k_p-1:0]), .way_o(way));
  assign y = vtag_r ^ {vtag_width_p{way[0]}};
endmodule
