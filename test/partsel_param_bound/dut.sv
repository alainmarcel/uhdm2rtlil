package cfg_pkg;
  typedef struct packed {
    int unsigned ways;
    int unsigned sets;
  } cfg_t;
endpackage

module lfsr8 #(
    parameter int WIDTH = 8,
    localparam type data_t = logic [WIDTH-1:0]
) (
    input  logic  clk_i,
    input  logic  rst_ni,
    input  logic  shift_i,
    output data_t val_o
);
  logic [15:0] polynomial;
  assign polynomial = (WIDTH == 8) ? 16'h00E1 : 16'h0BAD;
  data_t lfsr_q, lfsr_d, lfsr_shifted;
  assign lfsr_shifted = {1'b0, lfsr_q[WIDTH-1:1]};
  always_comb begin
    if (lfsr_q[0]) lfsr_d = lfsr_shifted ^ polynomial[WIDTH-1:0];
    else           lfsr_d = lfsr_shifted;
  end
  assign val_o = lfsr_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)      lfsr_q <= '1;
    else if (shift_i) lfsr_q <= lfsr_d;
  end
endmodule

module mid
import cfg_pkg::*;
#(
    parameter cfg_t CFG = '0,
    localparam type way_vector_t = logic [CFG.ways-1:0]
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        shift_i,
    output logic [7:0]  val_o
);
  lfsr8 #(.WIDTH(8)) lfsr_i (.clk_i, .rst_ni, .shift_i, .val_o);
endmodule

module sel
import cfg_pkg::*;
#(
    parameter cfg_t CFG = '0,
    parameter type way_vector_t = logic
) (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic       shift_i,
    output logic [7:0] val_o
);
  if (CFG.ways == 1) begin : gen_one
    assign val_o = '0;
  end else begin : gen_rand
    mid #(.CFG(CFG)) mid_i (.clk_i, .rst_ni, .shift_i, .val_o);
  end
endmodule

module partsel_param_bound (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic       shift_i,
    output logic [7:0] val_o
);
  import cfg_pkg::*;
  localparam cfg_t Cfg = '{ways: 8, sets: 64};
  sel #(.CFG(Cfg), .way_vector_t(logic [7:0])) sel_i (.clk_i, .rst_ni, .shift_i, .val_o);
endmodule
