// An interface-ARRAY port at the TOP level whose element count is a
// struct-parameter field -- tnoc's
//
//     localparam int CHANNELS = PACKET_CONFIG.virtual_channels
//     ...
//     tnoc_flit_if.sender sender_if[CHANNELS]
//
// Surelog gives such a port a BARE array_typespec (no element typespec),
// so import_port's interface branch never ran and the port got NO member
// wires of its own; only the element instances Surelog materialised were
// imported afterwards -- element 0 here, none at all for tnoc, where the
// hierarchy then died on "does not have a port named 'sender_if.vc_ready'"
// (seven tnoc rows read-failed).  The interface and modport are named by the
// Low_conn's interface_array; the fix takes them from there.
//
// UHDM-only: yosys's read_verilog does not parse interfaces.
// test_structural.ys asserts both elements' member ports; the slang miter
// proves the values.
package cfg_pkg;
  typedef struct packed { shortint width; shortint vcs; } cfg_t;
  localparam cfg_t DEFAULT_CFG = '{width: 8, vcs: 2};
endpackage

interface bus_if #(parameter int W = 8);
  logic         valid;
  logic         ready;
  logic [W-1:0] data;
  modport sender   (output valid, data, input ready);
  modport receiver (input valid, data, output ready);
endinterface

module top
  import cfg_pkg::*;
#(
  parameter  cfg_t CFG      = DEFAULT_CFG,
  localparam int   CHANNELS = CFG.vcs
)(
  input  logic i_clk, i_rst_n,
  bus_if.receiver receiver_if,
  bus_if.sender   sender_if[CHANNELS]
);
  for (genvar i = 0; i < CHANNELS; ++i) begin : g
    assign sender_if[i].valid = receiver_if.valid;
    assign sender_if[i].data  = receiver_if.data + i;
  end
  assign receiver_if.ready = sender_if[0].ready & sender_if[1].ready;
endmodule
