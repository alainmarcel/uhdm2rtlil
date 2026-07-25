// Repro of CVA6 tc_sram.sv r_addr_q partial-reset ("8'mmmmmmm0"): a packed array
// whose ELEMENT type is a TYPE PARAMETER `addr_t` (= logic[W-1:0]), reset
// element-by-element with `for (i) q[i] <= '0` in an async-reset always_ff.
// `q[i]` must select a W-bit element; if the type-param element width is lost it
// collapses to a 1-bit select, only bit 0 resets, and proc/PROC_ARST aborts.
module packed_array_reset_loop #(
    parameter int unsigned W = 8,
    parameter int unsigned N = 1,
    parameter type         addr_t = logic [W-1:0]
) (
    input  logic               clk_i,
    input  logic               rst_ni,
    input  logic               en_i,
    input  addr_t [N-1:0]      d_i,
    output addr_t [N-1:0]      q_o
);
  addr_t [N-1:0] q;
  assign q_o = q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < N; i++) begin
        q[i] <= {W{1'b0}};
      end
    end else begin
      if (en_i) begin
        for (int i = 0; i < N; i++) begin
          q[i] <= d_i[i];
        end
      end
    end
  end
endmodule
