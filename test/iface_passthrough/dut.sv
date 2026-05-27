// Minimal repro for: a module passes a received interface PORT through to
// another submodule.  This is the "inherited interface" pattern that
// `svinterface1.sv` exercises (SubModule1's `u_MyInterface` port forwarded
// into SubModule2's `u_MyInterfaceInSub2`).
//
// Without the fix, the cell-side connection emits a single bare wire name
// (e.g. `connect \bus \bus`) rather than per-field connections — the
// submodule's flattened ports (`\bus.a`, `\bus.b`) have no driver and the
// hierarchy pass errors out with
// "does not have a port named 'bus'".

interface my_iface;
    logic a;
    logic b;
endinterface

module leaf (my_iface bus);
    assign bus.b = bus.a;
endmodule

// mid receives `bus` as a port (interface inherited from top) and forwards
// it to leaf.  The cell `leaf u_leaf(.bus(bus))` needs per-field connects.
module mid (my_iface bus);
    leaf u_leaf(.bus(bus));
endmodule

module top (input logic in_a, output logic out_b);
    my_iface bus();
    assign bus.a = in_a;
    mid u_mid(.bus(bus));
    assign out_b = bus.b;
endmodule
