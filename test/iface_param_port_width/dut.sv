// Reproducer for: port width that references an interface parameter
// via the modport prefix (`input wire [bus.DATA_WIDTH-1:0] din`).
// `bus` is `bus_if.master`; `bus.DATA_WIDTH` must resolve to the
// interface instance's elaborated parameter value (8 here).
//
// Added `output [DATA_WIDTH-1:0] dout` to `top` so co-sim can observe
// the bus traffic.
interface bus_if #(parameter DATA_WIDTH = 16);
    logic [DATA_WIDTH-1:0] data;
    modport master(output data);
endinterface

module bus_master (bus_if.master bus,
                   input wire [bus.DATA_WIDTH-1:0] din);
    assign bus.data = din;
endmodule

module top (
    input  logic [7:0] din,
    output logic [7:0] dout
);
    bus_if #(.DATA_WIDTH(8)) bus();
    bus_master m0(bus, din);
    assign dout = bus.data;
endmodule
