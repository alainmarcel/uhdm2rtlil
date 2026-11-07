// YosysHQ/yosys#100 (closed): opt pass is optimizing my code away
// https://github.com/YosysHQ/yosys/issues/100
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- c0.sv
module fsm (input clk, input a, b, c, output k, m, l);
  localparam
    STATE_IDLE = 3'b000,
    STATE_K = 3'b001,
    STATE_M = 3'b010,
    STATE_L = 3'b100;

  reg [2:0] state;

  always @(posedge clk) begin
    // next state
    case (state)
      STATE_IDLE: begin
        if (a && b) begin
          state <= STATE_ML;
        end else if (b) begin
          state <= STATE_K;
        end
      end
      STATE_M, STATE_L: begin
        if (a && b && c) begin
          state <= STATE_L;
        end else if (b && c) begin
          state <= STATE_M;
        end
      end
    endcase

    // reset
    if (!a && !b && !c)
      state <= STATE_IDLE;
  end

  // output logic
  assign k = state[0] & ~state[1] & ~state[2];
  assign m = ~state[0] & state[1] & ~state[2];
  assign l = ~state[0] & ~state[1] & state[2];
endmodule

