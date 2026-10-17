// A SLICE of an interface array as the actual of a child's interface-ARRAY
// port -- tnoc's packet serializer:
//
//     tnoc_flit_if flit_if[3](types);
//     tnoc_flit_if_mux u_flit_mux (.receiver_if(flit_if[0:1]), .sender_if(flit_if[2]), ...);
//
// over `tnoc_flit_if.receiver receiver_if[ENTRIES]`.  The actual is a
// part_select named after the array; the generic expression import found
// no signal of that name, connected an EMPTY `receiver_if`, and `hierarchy`
// rejected the cell ("does not have a port named 'receiver_if'":
// tnoc_error_checker, tnoc_packet_serializer, tnoc_packet_deserializer).
//
// UHDM-only (interfaces); test_structural.ys runs `hierarchy -check` and
// `check -assert`, and test_slang_equiv.ys proves the mux against read_slang
// (the top has no interface ports).
interface bus_if #(parameter int W = 8);
  logic         valid;
  logic [W-1:0] data;
  logic         ready;
  modport rx (input valid, data, output ready);
  modport tx (output valid, data, input ready);
endinterface

module mux2 #(parameter int W = 8) (
  input  logic   i_select,
  bus_if.rx      rx[2],
  bus_if.tx      tx
);
  assign tx.valid = i_select ? rx[1].valid : rx[0].valid;
  assign tx.data  = i_select ? rx[1].data  : rx[0].data;
  assign rx[0].ready = ~i_select & tx.ready;
  assign rx[1].ready =  i_select & tx.ready;
endmodule

module top (
  input  logic       i_select,
  input  logic       i_valid0, i_valid1,
  input  logic [7:0] i_data0, i_data1,
  input  logic       i_ready,
  output logic       o_valid, o_ready0, o_ready1,
  output logic [7:0] o_data
);
  bus_if b[3]();
  assign b[0].valid = i_valid0; assign b[0].data = i_data0;
  assign b[1].valid = i_valid1; assign b[1].data = i_data1;
  assign b[2].ready = i_ready;
  mux2 u_mux (.i_select(i_select), .rx(b[0:1]), .tx(b[2]));
  assign o_valid = b[2].valid; assign o_data = b[2].data;
  assign o_ready0 = b[0].ready; assign o_ready1 = b[1].ready;
endmodule
