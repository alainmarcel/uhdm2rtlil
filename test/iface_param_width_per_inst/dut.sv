// Minimal repro for: a submodule receives a parameterised interface
// port whose WIDTH was overridden at the instance site.  Our
// `import_interface_instances` reads the field width from the
// AllModules form (default `W=3`) and creates `\bus.data` as width 3
// — but the parent passes `my_iface #(.W(22)) bus()` (width 22).
// The hierarchy pass then sees a width mismatch and the design
// breaks.
//
// The right fix is to flatten the interface port using the
// *elaborated* width per-instance, mirroring how Yosys generates
// `$paramod\Sub\...` variants.

interface my_iface #(parameter W = 3);
    logic [W-1:0] data;
endinterface

module sub (my_iface bus);
    always_comb begin
        bus.data = '0;
    end
endmodule

module top (output logic [21:0] out);
    my_iface #(.W(22)) bus();
    sub u_sub(.bus(bus));
    assign out = bus.data;
endmodule
