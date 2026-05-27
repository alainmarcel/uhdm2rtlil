// Minimal repro for: a submodule receives an interface PORT typed with
// modport A, and forwards it into a deeper submodule whose port is
// typed with modport B (compatible but with opposite directions).
// PR3's `import_port` swap replaces the receiver's `mp` with the
// outer-side modport (A), so the per-field port directions on the
// receiver are set from A's view — broken: a signal that should be
// INPUT on the receiver becomes OUTPUT.

interface my_iface;
    logic [1:0] data;
    modport drv (output data);   // producer view
    modport rcv (input  data);   // consumer view
endinterface

// `consumer` declares its port with the `rcv` modport.  `data` must be
// an INPUT here.
module consumer (my_iface.rcv bus, output logic [1:0] out);
    assign out = bus.data;
endmodule

// `mid` receives an interface port typed with `.drv` (the producer
// view).  It drives bus.data, then forwards `bus` into `consumer`.
// Without PR3 the swap, `consumer`'s `bus.data` direction comes from
// the `.rcv` modport (INPUT).  With PR3's bug, it inherits from
// `mid`'s `.drv` view (OUTPUT) — direction broken.
module mid (my_iface.drv bus, output logic [1:0] out);
    assign bus.data = 2'b10;
    consumer u_cons(.bus(bus), .out(out));
endmodule

module top (output logic [1:0] out);
    my_iface bus();
    mid u_mid(.bus(bus), .out(out));
endmodule
