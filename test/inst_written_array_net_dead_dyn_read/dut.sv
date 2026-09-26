// An unpacked array of WIRES whose elements are driven by instance outputs
// inside a generate loop (`.state_out(crc_next[n])`, verilog-ethernet
// axis_eth_fcs), read in a clocked block with a constant index, plus a DEAD
// dynamic-index read in a loop under a constant-false parameter branch.
// The dead read made the array "dynamically indexed", and the array_net
// memory site did not consult the instance-written veto (the array_var site
// did), so the array became a writer-less $memory whose $memrd returned X:
// the FCS output stayed 0 (297 co-sim divergences, formal differs).
module inst_written_array_net_dead_dyn_read #(
  parameter DATA_WIDTH  = 8,
  parameter KEEP_ENABLE = 0,
  parameter KEEP_WIDTH  = 1
) (
  input  logic                  clk,
  input  logic [DATA_WIDTH-1:0] d,
  input  logic [KEEP_WIDTH-1:0] keep,
  input  logic                  valid,
  input  logic                  last,
  output logic [31:0]           fcs
);
  reg  [31:0] state = 32'hFFFFFFFF;
  wire [31:0] nxt[KEEP_WIDTH-1:0];
  genvar n;
  generate
    for (n = 0; n < KEEP_WIDTH; n = n + 1) begin : g
      mix_step #(.W(DATA_WIDTH/KEEP_WIDTH*(n+1))) u (
        .data_in (d[DATA_WIDTH/KEEP_WIDTH*(n+1)-1:0]),
        .state_in(state),
        .state_out(nxt[n])
      );
    end
  endgenerate
  integer i;
  always @(posedge clk) begin
    if (valid) begin
      state <= nxt[KEEP_WIDTH-1];
      if (last) begin
        state <= 32'hFFFFFFFF;
        if (KEEP_ENABLE) begin
          fcs <= ~nxt[0];
          for (i = 0; i < KEEP_WIDTH; i = i + 1)
            if (keep[i]) fcs <= ~nxt[i];
        end else begin
          fcs <= ~nxt[KEEP_WIDTH-1];
        end
      end
    end
  end
endmodule

module mix_step #(parameter W = 8) (
  input  logic [W-1:0]  data_in,
  input  logic [31:0]   state_in,
  output logic [31:0]   state_out
);
  assign state_out = {state_in[30:0], state_in[31]} ^ {{(32-W){1'b0}}, data_in} ^ (state_in[31] ? 32'h04c11db7 : 32'h0);
endmodule
