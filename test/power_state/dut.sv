module power_state (
  input clock,
  input reset,
  input [2:0] state,
  output reg gnt_0,
  output reg gnt_1
);

  parameter IDLE = 3'b001;
  parameter GNT0 = 3'b010;
  parameter GNT1 = 3'b100;

  //----------Output Logic-----------------------------
  always @ (posedge clock)
  begin : TADA
    if (reset == 1'b1) begin
      gnt_0 <= #1 1'b0;
      gnt_1 <= #1 1'b0;
    end
    else begin
      case(state)
        IDLE : begin
          gnt_0 <= #1 1'b0;
          gnt_1 <= #1 1'b0;
        end
        GNT0 : begin
          gnt_0 <= #1 1'b1;
          gnt_1 <= #1 1'b0;
        end
        GNT1 : begin
          gnt_0 <= #1 1'b0;
          gnt_1 <= #1 1'b1;
        end
        default : begin
          gnt_0 <= #1 1'b0;
          gnt_1 <= #1 1'b0;
        end
      endcase
    end
  end // End Of Block OUTPUT_LOGIC

endmodule
