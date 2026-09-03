// Per-element-only array (mem2reg-demoted by the async-reset clear loop) with
// a dynamic trailing member index write: tbl[wi].cnt[wk] <= val.
module elem_field_idx_write (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [1:0]  wi,
    input  logic [2:0]  wk,
    input  logic [3:0]  val,
    output logic [35:0] flat0,
    output logic [35:0] flat1,
    output logic [35:0] flat2
);
  typedef struct packed {
    logic            v;
    logic [2:0]      tag;
    logic [7:0][3:0] cnt;
  } e_t;

  e_t tbl[3];
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 3; i = i + 1) tbl[i] <= '0;
    end else begin
      tbl[wi].cnt[wk] <= val;
      tbl[wi].v      <= 1'b1;
    end
  end
  assign flat0 = tbl[0];
  assign flat1 = tbl[1];
  assign flat2 = tbl[2];
endmodule
