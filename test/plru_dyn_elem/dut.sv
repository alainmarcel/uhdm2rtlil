// hpdcache_victim_plru core shape: packed 2D state, dynamic element read and
// dynamic element write in always_comb, plus reduction-conditional update.
module plru_dyn_elem (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       updt,
    input  logic [1:0] updt_set,
    input  logic [1:0] sel_set,
    input  logic [7:0] updt_way,
    output logic [7:0] plru_row,
    output logic [7:0] not_plru_row
);
  typedef logic [7:0] way_vector_t;

  way_vector_t [3:0] plru_q, plru_d;
  way_vector_t updt_plru;

  assign updt_plru = plru_q[updt_set] | updt_way;

  always_comb begin
    plru_d = plru_q;
    if (updt) plru_d[updt_set] = &updt_plru ? updt_way : updt_plru;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) plru_q <= '0;
    else        plru_q <= plru_d;
  end

  assign plru_row     = plru_q[sel_set];
  assign not_plru_row = ~plru_q[sel_set];
endmodule
