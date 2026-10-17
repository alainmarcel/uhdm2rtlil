// An interface-ARRAY port of ONE element, passed whole through a middle
// module to the one that drives its elements from a generate loop -- rggen's
// adapters: `rggen_register_if.host register_if[REGISTERS]` with REGISTERS
// defaulting to 1, rggen_apb_adapter -> rggen_adapter_common.
//
// A one-element array port reports the same width as a scalar interface, so
// import_port created its members UNINDEXED (`register_if.valid`) while the
// elaborated element instance `register_if[0]` had already given the module
// an INDEXED set -- and the generate loop writing `register_if[i].valid`
// drove the indexed one.  The parent connected the unindexed, undriven set:
// every output of the five rggen adapters floated (301 diverging cycles).
// The naming now follows the port being declared an ARRAY, and a module's
// own array port handed to a child binds element-wise.  UHDM-only: yosys's
// read_verilog rejects the interface-array port.
interface reg_if #(parameter int ADDRESS_WIDTH = 16, parameter int BUS_WIDTH = 32);
  logic                     valid;
  logic [ADDRESS_WIDTH-1:0] address;
  logic [BUS_WIDTH-1:0]     read_data;
  modport host (output valid, address, input read_data);
  modport regp (input valid, address, output read_data);
endinterface

module adapter_common #(parameter int REGISTERS = 1, parameter bit ERROR_STATUS = 0) (
  reg_if.host         register_if[REGISTERS],
  reg_if.regp         bus_if,
  input  logic        i_valid,
  input  logic [15:0] i_address,
  output logic [31:0] o_read_data
);
  genvar i;
  generate
    if (ERROR_STATUS) begin : g_response
      for (i = 0; i < REGISTERS; ++i) begin : g
        always_comb begin
          register_if[i].valid   = i_valid;
          register_if[i].address = i_address;
        end
      end
    end
    else begin : g_response
      for (i = 0; i < REGISTERS; ++i) begin : g
        always_comb begin
          register_if[i].valid   = i_valid;
          register_if[i].address = i_address;
        end
      end
    end
  endgenerate
  // the bus side returns the selected register's read data (rggen's shape)
  assign bus_if.read_data = register_if[0].read_data;
  assign o_read_data = register_if[0].read_data;
endmodule

// the middle module is a $paramod (a parameter overridden by the wrapper),
// as rggen's adapters are under the sweep's wrapper -- an un-overridden
// instance did not reproduce the row
module adapter #(parameter int REGISTERS = 1, parameter int LOCAL_ADDRESS_WIDTH = 8) (
  reg_if.host         register_if[REGISTERS],
  input  logic        i_valid,
  input  logic [15:0] i_address,
  output logic [31:0] o_read_data
);
  logic [15:0] local_address;
  assign local_address = 16'(i_address[LOCAL_ADDRESS_WIDTH-1:0]);
  // an internal interface instance handed to the child too, as rggen's
  // adapters hand their bus_if to rggen_adapter_common
  reg_if #(.ADDRESS_WIDTH(16), .BUS_WIDTH(32)) bus_if();
  assign bus_if.valid = i_valid;
  assign bus_if.address = local_address;
  adapter_common #(.REGISTERS(REGISTERS)) u_adapter_common (
    .register_if (register_if),
    .bus_if      (bus_if),
    .i_valid     (i_valid),
    .i_address   (local_address),
    .o_read_data (o_read_data)
  );
endmodule

module adapter_flat (
  input  logic        i_valid,
  input  logic [15:0] i_address,
  output logic [31:0] o_read_data,
  output logic        register_if_0__valid,
  output logic [15:0] register_if_0__address,
  input  logic [31:0] register_if_0__read_data
);
  reg_if #(.ADDRESS_WIDTH(16), .BUS_WIDTH(32)) register_if_i [0:0] ();
  adapter #(.REGISTERS(1), .LOCAL_ADDRESS_WIDTH(16)) dut (.register_if(register_if_i), .i_valid(i_valid), .i_address(i_address), .o_read_data(o_read_data));
  assign register_if_0__valid       = register_if_i[0].valid;
  assign register_if_0__address     = register_if_i[0].address;
  assign register_if_i[0].read_data = register_if_0__read_data;
endmodule
