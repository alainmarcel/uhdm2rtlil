// Reproducer for SystemVerilog interface-with-modport handling.
// A child module receives a `bus_if.master` modport port; the parent
// instantiates the interface, drives one side of the modport from an
// input, and routes the other side back out so co-sim / equivalence
// can observe the bus traffic.
//
// Originally `read_systemverilog` (UHDM frontend) produced an empty
// `bus_if` module, an `inout bus` wire on `bus_master`, and emitted
// "implicitly declared" warnings for `bus.in` / `bus.out`, breaking
// the connection between `top.bus.in` and `bus_master.bus.in`.
interface bus_if;
    logic in;
    logic out;
    modport master(input in, output out);
endinterface

module bus_master (bus_if.master bus);
    assign bus.out = bus.in;
endmodule

module top (
    input  logic din,
    output logic dout
);
    bus_if bus();
    assign bus.in = din;
    bus_master m0(bus);
    assign dout = bus.out;
endmodule
