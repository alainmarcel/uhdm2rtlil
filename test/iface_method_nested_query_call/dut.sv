// An interface method that calls ANOTHER method of the same interface with a
// constant argument (`return tail ? get_channel_ack(channel) : '0`, tnoc's
// tnoc_flit_if.get_tail_flit_ack): the nested plain call was folded at
// compile time because its only argument is constant, although the callee
// reads interface STATE (`valid[channel] & ready[channel]`), so every
// tail-flit acknowledge of tnoc's VC arbiter was 0.  Two array elements,
// called from a generate loop, as the arbiter does.
interface fi #(parameter int CH = 1);
  logic [CH-1:0] valid;
  logic [CH-1:0] ready;
  logic [3:0]    flit;
  function automatic logic get_channel_ack(logic [CH-1:0] channel);
    return valid[channel] & ready[channel];
  endfunction
  function automatic logic get_tail_flit_ack(logic [CH-1:0] channel);
    logic tail;
    tail = flit[2];
    return (tail) ? get_channel_ack(channel) : '0;
  endfunction
endinterface

module top (input logic [1:0] v, input logic [1:0] rdy, input logic [7:0] f, output logic [1:0] fr, output logic [1:0] ack);
  fi #(.CH(1)) flit_vc_if[2]();
  for (genvar i = 0; i < 2; ++i) begin : g_arbitration
    always_comb begin
      flit_vc_if[i].valid = v[i];
      flit_vc_if[i].ready = rdy[i];
      flit_vc_if[i].flit  = f[4*i +: 4];
      fr[i]  = flit_vc_if[i].get_tail_flit_ack(0);
      ack[i] = flit_vc_if[i].get_channel_ack(0);
    end
  end
endmodule
