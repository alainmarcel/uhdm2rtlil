// Reproducer for: output-only modport on a 1-bit interface signal.
// Original report: `read_systemverilog` warned that `\bus.out` is
// implicitly declared in `bus_master`, emitted `bus` as `inout` (no
// real direction), and left `top` with no connection at all.
//
// Added `output dout` to `top` so co-sim can observe `bus.out`.
interface bus_if;
    logic out;
    modport master(output out);
endinterface

module bus_master (bus_if.master bus, input logic din);
    assign bus.out = din;
endmodule

module top (
    input  logic din,
    output logic dout
);
    bus_if bus();
    bus_master m0(bus, din);
    assign dout = bus.out;
endmodule
