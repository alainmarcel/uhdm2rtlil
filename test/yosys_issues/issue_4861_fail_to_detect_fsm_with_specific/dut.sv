// YosysHQ/yosys#4861 (open): Fail to detect FSM with specific writing style
// https://github.com/YosysHQ/yosys/issues/4861
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module fsm_main_def (
    input  logic clk,
    input  logic reset,
    input  logic fsm_start_out,
    input  logic invoke0_done_out,
    input  logic invoke1_done_out,
    output logic s0_out,
    output logic s1_out,
    output logic s2_out,
    output logic s3_out
);

  localparam logic [1:0] S0 = 2'd0;
  localparam logic [1:0] S1 = 2'd1;
  localparam logic [1:0] S2 = 2'd2;
  localparam logic [1:0] S3 = 2'd3;

  (* fsm_encoding="auto" *)logic [3:0] current_state;
  logic [3:0] next_state;

  assign {s3_out, s2_out, s1_out, s0_out} = current_state;
  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= 'b1;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    next_state = 'b0;
    case (1'b1)
      current_state[S0]: begin
          next_state[S1] = 1'b1;
      end
      current_state[S1]: begin
          next_state[S2] = 1'b1;
      end
      current_state[S2]: begin
          next_state[S3] = 1'b1;
        end
      current_state[S3]: begin
        next_state[S0] = 1'b1;
      end
      default begin
        next_state = 'b1;
      end
    endcase
  end
endmodule

