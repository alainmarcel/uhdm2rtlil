// Interface PORTS driven through a flat-port wrapper.
//
// A SystemVerilog interface port is flattened by every RTLIL frontend into one
// escaped identifier per member (`\bus.aw_addr`).  Verilator cannot take such a
// name as a port, so a co-sim testbench can only be built against a wrapper
// that instantiates the interface INSIDE and exposes ordinary ports -- the
// shape test/gen_iface_wrapper.py generates and netlist_cosim's `--iface-flat`
// renames the netlist to match.
//
// This test locks in the lowering both of those depend on: a module with
// interface ports on both a Slave and a Master modport, wrapped flat, must read
// identically through read_uhdm and read_slang.  read_verilog cannot parse the
// interface at all, so the slang miter is the gate.

interface bus_if #(
  parameter int unsigned ADDR_WIDTH = 8,
  parameter int unsigned DATA_WIDTH = 8
) (
  input logic clk,
  input logic rst_n
);
  typedef logic [ADDR_WIDTH-1:0] addr_t;
  typedef logic [DATA_WIDTH-1:0] data_t;

  addr_t addr;
  data_t data;
  logic  valid;
  logic  ready;

  modport Slave  (input  addr, data, valid, output ready);
  modport Master (output addr, data, valid, input  ready);
endinterface

// The DUT: interface ports in BOTH directions, with a modport each.
module xfer #(
  parameter bit REGISTERED = 1'b1
) (
  input  logic clk,
  input  logic rst_n,
  bus_if.Slave  in,
  bus_if.Master out
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out.addr  <= '0;
      out.data  <= '0;
      out.valid <= 1'b0;
    end else if (in.valid && out.ready) begin
      out.addr  <= in.addr;
      out.data  <= in.data ^ 8'hA5;
      out.valid <= 1'b1;
    end else begin
      out.valid <= 1'b0;
    end
  end
  assign in.ready = out.ready;
endmodule

// The flat-port wrapper: interfaces live inside, ports are ordinary.
module dut (
  input  logic       clk,
  input  logic       rst_n,
  input  logic [7:0] in__addr,
  input  logic [7:0] in__data,
  input  logic       in__valid,
  output logic       in__ready,
  output logic [7:0] out__addr,
  output logic [7:0] out__data,
  output logic       out__valid,
  input  logic       out__ready
);
  bus_if #(.ADDR_WIDTH(8), .DATA_WIDTH(8)) in_i  (.clk(clk), .rst_n(rst_n));
  bus_if #(.ADDR_WIDTH(8), .DATA_WIDTH(8)) out_i (.clk(clk), .rst_n(rst_n));

  xfer u_x (.clk(clk), .rst_n(rst_n), .in(in_i.Slave), .out(out_i.Master));

  // wrapper input  -> interface member
  assign in_i.addr   = in__addr;
  assign in_i.data   = in__data;
  assign in_i.valid  = in__valid;
  assign out_i.ready = out__ready;
  // interface member -> wrapper output
  assign in__ready   = in_i.ready;
  assign out__addr   = out_i.addr;
  assign out__data   = out_i.data;
  assign out__valid  = out_i.valid;
endmodule
