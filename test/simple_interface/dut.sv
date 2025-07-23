// Simple interface to group input signals
interface data_bus_if #(
    parameter WIDTH = 8
);
    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [WIDTH-1:0] c;
    
    // Modport for module that uses the interface
    modport user (
        input a, b, c
    );
    
    // Modport for testbench or top-level connections
    modport driver (
        output a, b, c
    );
endinterface

module submodule #(
    parameter WIDTH = 8
) (
    data_bus_if.user bus,
    output logic [WIDTH-1:0] out
);
    // Bitwise AND of three signals from interface
    assign out = bus.a & bus.b & bus.c;
endmodule

module simple_interface (
    input  logic [7:0]  a1, b1, c1,
    input  logic [7:0]  a2, b2, c2,
    input  logic [15:0] a3, b3, c3,
    output logic [7:0]  out1,
    output logic [7:0]  out2,
    output logic [15:0] out3
);

    // Create interface instances
    data_bus_if #(.WIDTH(8))  bus1();
    data_bus_if #(.WIDTH(8))  bus2();
    data_bus_if #(.WIDTH(16)) bus3();
    
    // Connect inputs to interface signals
    assign bus1.a = a1;
    assign bus1.b = b1;
    assign bus1.c = c1;
    
    assign bus2.a = a2;
    assign bus2.b = b2;
    assign bus2.c = c2;
    
    assign bus3.a = a3;
    assign bus3.b = b3;
    assign bus3.c = c3;

    // First instance using interface with WIDTH=8
    submodule #(.WIDTH(8)) inst1 (
        .bus(bus1),
        .out(out1)
    );

    // Second instance using interface with WIDTH=8
    submodule #(.WIDTH(8)) inst2 (
        .bus(bus2),
        .out(out2)
    );

    // Third instance using interface with WIDTH=16
    submodule #(.WIDTH(16)) inst3 (
        .bus(bus3),
        .out(out3)
    );

endmodule
