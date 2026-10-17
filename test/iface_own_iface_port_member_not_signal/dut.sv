// An interface that takes an INTERFACE as its own port, for typedefs only --
// tnoc_flit_if's `tnoc_types types` -- and a parent that passes such
// interface instances to a child:
//
//     tnoc_flit_if flit_vc_if[CHANNELS](types);
//     tnoc_flit_if_fifo u_fifo (.types(types), .sender_if(flit_vc_if[i]), ...);
//
// The interface's `types` port appears among the instance's Nets() as a
// typespec-less logic_net; a member wire `flit_vc_if[1].types` was created
// for it and the parent connected `sender_if.types` to a child whose
// flattened port set has no such port:
//
//     ERROR: Module `$paramod\tnoc_flit_if_fifo...' ... does not have a port
//     named 'sender_if.types'
//
// (tnoc_vc_arbiter, the flit muxes and demuxes, the packet (de)serializers.)
// UHDM-only (interfaces); test_structural.ys: `hierarchy -check` is the gate.
interface types_if;
  typedef logic [7:0] flit_t;
endinterface

interface flit_if (types_if types);
  typedef types.flit_t flit_t;
  logic  valid;
  logic [7:0] flit;   // (a member typed `flit_t` through the port is a separate, open width defect)
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
