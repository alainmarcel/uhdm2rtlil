interface pkt_if #(parameter int W = 16);
  logic         valid;
  logic         ready;
  logic [7:0]   a, b;
  function automatic logic get_ack();
    return valid & ready;
  endfunction
  function automatic logic [W-1:0] pack();
    return {a, b};
  endfunction
  modport user (input valid, a, b, output ready, import get_ack, pack);
endinterface

module consumer (
  input  logic        clk, rst_n,
  pkt_if.user         packet_if,
  output logic [15:0] o_data,
  output logic        o_acked
);
  assign packet_if.ready = 1'b1;
  assign o_data = packet_if.pack();
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) o_acked <= 1'b0;
    else if (packet_if.get_ack()) o_acked <= 1'b1;
endmodule

module top (
  input  logic       clk, rst_n, i_valid,
  input  logic [7:0] i_a, i_b,
  output logic [15:0] o_data,
  output logic        o_acked, o_ready
);
  pkt_if p();
  assign p.valid = i_valid; assign p.a = i_a; assign p.b = i_b;
  assign o_ready = p.ready;
  consumer u_c (.clk(clk), .rst_n(rst_n), .packet_if(p), .o_data(o_data), .o_acked(o_acked));
endmodule
