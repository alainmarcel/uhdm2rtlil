// An interface METHOD called with a GENVAR argument from an always_ff in a
// generate loop (`if (fifo_out_if.get_head_flit_valid(i))`, tnoc's AXI
// write/read demux g_routing[i]): the formal's staged temp never received the
// actual, so every channel but 0 evaluated the method on an X channel and
// never latched its route.  Needs a 4-step bound: one step cannot see a
// register that fails to latch.
interface fi #(parameter int CH = 2);
  localparam int FLITS = CH;
  typedef struct packed { logic head; logic tail; logic [5:0] data; } flit_t;
  flit_t [FLITS-1:0] flit;
  logic  [CH-1:0]    valid;
  function automatic logic get_head_flit_valid(logic [$clog2(CH)-1:0] channel);
    logic head;
    if (FLITS >= 2) begin
      head = flit[channel].head;
    end
    else begin
      head = flit[0].head;
    end
    return (head) ? valid[channel] : '0;
  endfunction
endinterface
module top (input logic clk, input logic [1:0] v, input logic [15:0] f, input logic [3:0] d, output logic [3:0] q);
  fi #(.CH(2)) fifo_out_if();
  assign fifo_out_if.valid = v; assign fifo_out_if.flit = f;
  for (genvar i = 0; i < 2; ++i) begin : g_routing
    logic [1:0] route_latched;
    always_ff @(posedge clk) begin
      if (fifo_out_if.get_head_flit_valid(i)) route_latched <= d[2*i +: 2];
    end
    assign q[2*i +: 2] = route_latched;
  end
endmodule
