typedef struct packed {
  logic       valid;
  logic [1:0] sat;
} e_t;

module unpacked_struct_2d (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic       flush_i,
    input  logic       upd_i,
    input  logic       taken_i,
    input  logic [1:0] upd_pc,
    input  logic       upd_row,
    input  logic [1:0] rd_idx,
    output e_t         out0,
    output e_t         out1
);
  e_t d[3:0][1:0], q[3:0][1:0];
  logic [1:0] sat;

  assign out0 = q[rd_idx][0];
  assign out1 = q[rd_idx][1];

  always_comb begin
    d   = q;
    sat = q[upd_pc][upd_row].sat;
    if (upd_i) begin
      d[upd_pc][upd_row].valid = 1'b1;
      if (sat == 2'b11) begin
        if (!taken_i) d[upd_pc][upd_row].sat = sat - 1;
      end else if (sat == 2'b00) begin
        if (taken_i) d[upd_pc][upd_row].sat = sat + 1;
      end else begin
        if (taken_i) d[upd_pc][upd_row].sat = sat + 1;
        else d[upd_pc][upd_row].sat = sat - 1;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned i = 0; i < 4; i++) begin
        for (int j = 0; j < 2; j++) begin
          q[i][j] <= '0;
        end
      end
    end else begin
      if (flush_i) begin
        for (int i = 0; i < 4; i++) begin
          for (int j = 0; j < 2; j++) begin
            q[i][j].valid <= 1'b0;
            q[i][j].sat   <= 2'b10;
          end
        end
      end else begin
        q <= d;
      end
    end
  end
endmodule
