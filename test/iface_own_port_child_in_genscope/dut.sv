// A module's OWN interface PORT handed to a child instantiated inside a
// GENERATE block -- rggen block_0's external register:
//
//   generate if (1) begin : g_register_19
//     rggen_external_register u_register (..., .bus_if(register_19_bus_if));
//
// Surelog binds that actual to the port's MODPORT (not an interface instance)
// once the module also declares an interface ARRAY instance (block_0's
// `rggen_register_if register_if[29]()`; without that declaration the actual
// binds to the interface instance and the existing branch handles it).  With
// a modport actual the generic import ran, its gen-scope lookup wanted
// `g_register_19.register_19_bus_if`, found nothing, and connected a
// fabricated 1-bit wire; the interface expansion pass then had nothing to
// expand and the child's bus_if.* floated (block_0: the wrapper's
// register_19_bus_if__write_data / address / strobe undriven).
interface ext_bus_if #(parameter int ADDRESS_WIDTH = 16, parameter int BUS_WIDTH = 32);
  logic                     valid;
  logic [ADDRESS_WIDTH-1:0] address;
  logic [BUS_WIDTH-1:0]     read_data;
  modport master (output valid, address, input read_data);
  modport slave  (input valid, address, output read_data);
endinterface

interface reg_if;
  logic [31:0] value;
  modport regp (output value);
endinterface

module reg_sink (reg_if.regp register_if[1]);
  assign register_if[0].value = '0;
endmodule

module ext_reg #(parameter int ADDRESS_WIDTH = 8, parameter int BUS_WIDTH = 32) (
  ext_bus_if.master   bus_if,
  input  logic        i_valid,
  input  logic [15:0] i_address,
  output logic [31:0] o_read_data
);
  assign bus_if.valid   = i_valid;
  assign bus_if.address = i_address;
  assign o_read_data    = bus_if.read_data;
endmodule

module block #(parameter int ADDRESS_WIDTH = 8) (
  ext_bus_if.master   register_19_bus_if,
  input  logic        i_valid,
  input  logic [15:0] i_address,
  output logic [31:0] o_read_data
);
  // the interface-array declaration that flips Surelog's binding to the modport;
  // it is driven through an interface-ARRAY port, which yosys's read_verilog
  // rejects -- that keeps this test UHDM-only (read_verilog would otherwise
  // declare `bus_if.valid` etc. as implicit 1-bit wires and the Verilog
  // comparison would be vacuous)
  reg_if register_if[1]();
  reg_sink u_sink (.register_if(register_if));

  generate if (1) begin : g_register_19
    ext_reg #(.ADDRESS_WIDTH(16), .BUS_WIDTH(32)) u_register (
      .bus_if      (register_19_bus_if),
      .i_valid     (i_valid),
      .i_address   (i_address),
      .o_read_data (o_read_data)
    );
  end endgenerate
endmodule

// the flat wrapper the sweeps build: interface INSIDE, plain ports outside
module block_flat (
  input  logic        i_valid,
  input  logic [15:0] i_address,
  output logic [31:0] o_read_data,
  output logic        bus__valid,
  output logic [15:0] bus__address,
  input  logic [31:0] bus__read_data
);
  ext_bus_if #(.ADDRESS_WIDTH(16), .BUS_WIDTH(32)) bus_i ();
  block #(.ADDRESS_WIDTH(16)) dut (.register_19_bus_if(bus_i.master), .*);
  assign bus__valid     = bus_i.valid;
  assign bus__address   = bus_i.address;
  assign bus_i.read_data = bus__read_data;
endmodule
