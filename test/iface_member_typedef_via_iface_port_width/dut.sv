// A modport member typed THROUGH the interface's own interface port --
// tnoc_flit_if's
//
//     interface tnoc_flit_if (tnoc_types types);
//       typedef types.tnoc_flit tnoc_flit;
//       tnoc_flit flit;
//
// The member's width is measured on the interface instance a port resolves
// to.  For `u_in.receiver_if(in_if)` that is the enclosing module's OWN
// interface port stub, where the typedef through `types` does not resolve,
// so `receiver_if.flit` measured ONE bit, while `sender_if.flit`, bound to
// the elaborated `mid_if[0]`, measured eight ("Resizing cell port ... flit
// from 8 bits to 1 bits").  The width is now taken from an elaborated
// instance of the interface where the member resolves.
//
// UHDM-only (interfaces); test_structural.ys splits the child's member
// wire into bits and counts eight.
interface types_if;
  typedef logic [7:0] flit_t;
endinterface

interface flit_if (types_if types);
  typedef types.flit_t flit_t;
  logic  valid;
  flit_t flit;
  logic  ready;
  modport sender   (output valid, flit, input ready);
  modport receiver (input valid, flit, output ready);
endinterface

module stage (
  types_if          types,
  input  logic      clk, rst_n,
  flit_if.receiver  receiver_if,
  flit_if.sender    sender_if
);
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin sender_if.valid <= 1'b0; sender_if.flit <= '0; end
    else if (sender_if.ready) begin sender_if.valid <= receiver_if.valid; sender_if.flit <= receiver_if.flit; end
  assign receiver_if.ready = sender_if.ready;
endmodule

module top (
  types_if          types,
  input  logic      clk, rst_n,
  flit_if.receiver  in_if,
  flit_if.sender    out_if
);
  flit_if mid_if[2](types);
  stage u_in  (.types(types), .clk(clk), .rst_n(rst_n), .receiver_if(in_if),     .sender_if(mid_if[0]));
  for (genvar i = 0; i < 1; ++i) begin : g
    stage u_mid (.types(types), .clk(clk), .rst_n(rst_n), .receiver_if(mid_if[i]), .sender_if(mid_if[i+1]));
  end
  stage u_out (.types(types), .clk(clk), .rst_n(rst_n), .receiver_if(mid_if[1]), .sender_if(out_if));
endmodule
