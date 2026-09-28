// A function with OUTPUT arguments called from an expression inside an
// always_comb case arm -- I3C bus_tx_flow's
//   state_d = start_transfer(tx_req_i, req_value_d, drive_mode_d, bit_counter_en);
// The comb inliner bound the outputs like inputs (the actuals' current
// values) and left their writes in the function's own value map, so the
// return value came back and all three outputs were dropped: the block's
// defaults survived and sel_od_pp_o never left open-drain (169 co-sim
// divergences).  The write-back must land in the ACTIVE if/case arm, not the
// root case.  read_verilog cannot parse the package enums/struct: the miter
// against read_slang is the gate.
package p;
  typedef enum logic { OpenDrain = 1'b0, PushPull = 1'b1 } drive_e;
  typedef enum logic [1:0] { RawByte, AckRegular, TReadCont, TReadEnd } req_e;
  typedef enum logic [1:0] { Idle, WaitNegEdge, DriveByte } state_e;
  typedef struct packed { logic valid; req_e req_type; drive_e drive_type; logic [7:0] data; } req_t;
endpackage
module dut import p::*; (input logic clk_i, input logic rst_ni, input req_t req_i, input logic neg_edge_i,
                         output logic sel_od_pp_o, output logic [7:0] req_value_o, output logic counter_en_o, output state_e state_o);
  drive_e drive_mode_q, drive_mode_d;
  logic [7:0] req_value_q, req_value_d;
  state_e state_q, state_d;
  logic counter_en;
  function automatic state_e start_transfer(input req_t req, output logic [7:0] req_value, output drive_e drive_mode, output logic counter_en);
    req_value  = '1;
    drive_mode = OpenDrain;
    counter_en = 1'b0;
    case (req.req_type)
      RawByte:    begin req_value = req.data;   drive_mode = req.drive_type; end
      AckRegular: begin req_value[7] = 1'b0;    drive_mode = OpenDrain; end
      TReadCont:  begin req_value[7] = 1'b1;    drive_mode = PushPull; end
      TReadEnd:   begin req_value[7] = 1'b0;    drive_mode = PushPull; end
      default: ;
    endcase
    counter_en = 1'b1;
    return DriveByte;
  endfunction
  always_comb begin
    counter_en   = 1'b0;
    req_value_d  = req_value_q;
    drive_mode_d = drive_mode_q;
    state_d      = state_q;
    unique case (state_q)
      Idle: if (req_i.valid) begin
              if (neg_edge_i) state_d = start_transfer(req_i, req_value_d, drive_mode_d, counter_en);
              else            state_d = WaitNegEdge;
            end
      WaitNegEdge: if (neg_edge_i) state_d = start_transfer(req_i, req_value_d, drive_mode_d, counter_en);
      DriveByte: if (!req_i.valid) state_d = Idle;
      default: state_d = Idle;
    endcase
  end
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) begin drive_mode_q <= OpenDrain; req_value_q <= '1; state_q <= Idle; end
    else begin drive_mode_q <= drive_mode_d; req_value_q <= req_value_d; state_q <= state_d; end
  assign sel_od_pp_o = drive_mode_q; assign req_value_o = req_value_q; assign counter_en_o = counter_en; assign state_o = state_q;
endmodule
