// `receiver_if[i].flit[0]` -- an ELEMENT of a packed-struct-array member of an
// interface-ARRAY PORT element, read from a generate loop (tnoc_vc_mux's
// `sender_if.flit[i] = receiver_if[i].flit[0]`).  No instance of that name
// exists in the module, so the element geometry was unknown and the select
// took ONE BIT of the 291-bit flit; the port's interface definition declares
// the member, but with the definition's parameter defaults (two elements),
// so the element is sized by its TYPE and the wire says how many there are.
interface types;
  typedef struct packed { logic [3:0] ptype; logic [3:0] data; } flit_t;
endinterface
interface fi #(parameter int CH = 2) (types t);
  typedef t.flit_t flit_t;
  flit_t [CH-1:0] flit;
  logic  [CH-1:0] valid;
  modport receiver (input flit, input valid);
  modport sender (output flit, output valid);
endinterface
module vc_mux (types t, fi.receiver receiver_if[2], fi.sender sender_if);
  for (genvar i = 0; i < 2; ++i) begin : g
    always_comb begin
      sender_if.valid[i] = receiver_if[i].valid;
      sender_if.flit[i]  = receiver_if[i].flit[0];
    end
  end
endmodule
module top (input logic [15:0] f, input logic [1:0] v, output logic [15:0] y, output logic [1:0] yv);
  types t();
  fi #(.CH(1)) receiver_if[2](t);
  fi #(.CH(2)) sender_if(t);
  vc_mux dut (.t(t), .receiver_if(receiver_if), .sender_if(sender_if));
  assign receiver_if[0].flit = f[7:0];  assign receiver_if[1].flit = f[15:8];
  assign receiver_if[0].valid = v[0];   assign receiver_if[1].valid = v[1];
  assign y = sender_if.flit; assign yv = sender_if.valid;
endmodule
