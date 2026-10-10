// RSD DCacheMissHandler: always_ff with a per-field reset of every element in
// a loop and a whole-array NBA in the else branch.
typedef struct packed { logic valid; logic [2:0] phase; logic [7:0] line; logic flushed; logic [1:0] way; } ent_t;
module sync_elem_field_reset_whole_array_nba(input logic clk, input logic rst, input logic [29:0] nxt_flat, output logic [29:0] out_flat);
  ent_t nxt [2];
  ent_t mshr [2];
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      nxt[i] = nxt_flat[i*15 +: 15];
      out_flat[i*15 +: 15] = mshr[i];
    end
  end
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 2; i++) begin
        mshr[i].valid <= 1'b0;
        mshr[i].phase <= 3'd0;
        mshr[i].flushed <= 1'b0;
      end
    end
    else begin
      mshr <= nxt;
    end
  end
endmodule
