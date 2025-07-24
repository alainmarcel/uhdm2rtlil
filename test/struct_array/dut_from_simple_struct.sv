// Simple struct to group input signals
typedef struct packed {
    logic [7:0] a;
    logic [7:0] b;
    logic [7:0] c;
} data_bus_8bit_t;

typedef struct packed {
    logic [15:0] a;
    logic [15:0] b;
    logic [15:0] c;
} data_bus_16bit_t;

module submodule_8bit (
    input  data_bus_8bit_t bus,
    output logic [7:0] out
);
    // Bitwise AND of three signals from struct
    assign out = bus.a & bus.b & bus.c;
endmodule

module submodule_16bit (
    input  data_bus_16bit_t bus,
    output logic [15:0] out
);
    // Bitwise AND of three signals from struct
    assign out = bus.a & bus.b & bus.c;
endmodule

module simple_struct (
    input  logic [7:0]  a1, b1, c1,
    input  logic [7:0]  a2, b2, c2,
    input  logic [15:0] a3, b3, c3,
    output logic [7:0]  out1,
    output logic [7:0]  out2,
    output logic [15:0] out3
);

    // Create struct instances
    data_bus_8bit_t  bus1;
    data_bus_8bit_t  bus2;
    data_bus_16bit_t bus3;
    
    // Connect inputs to struct members
    always_comb begin
        bus1.a = a1;
        bus1.b = b1;
        bus1.c = c1;
        
        bus2.a = a2;
        bus2.b = b2;
        bus2.c = c2;
        
        bus3.a = a3;
        bus3.b = b3;
        bus3.c = c3;
    end

    // First instance using 8-bit struct
    submodule_8bit inst1 (
        .bus(bus1),
        .out(out1)
    );

    // Second instance using 8-bit struct
    submodule_8bit inst2 (
        .bus(bus2),
        .out(out2)
    );

    // Third instance using 16-bit struct
    submodule_16bit inst3 (
        .bus(bus3),
        .out(out3)
    );

endmodule