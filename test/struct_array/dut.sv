// Simple test case for struct member access
typedef struct packed {
    logic [7:0] data;
    logic [3:0] tag;
} packet_t;

module struct_array (
    input  logic [7:0] data_in,
    input  logic [3:0] tag_in,
    output logic [7:0] data_out,
    output logic [3:0] tag_out
);
    // Local struct variable
    packet_t packet;
    
    // Pack input into struct
    always_comb begin
        packet.data = data_in;
        packet.tag = tag_in;
    end
    
    // Process the packet
    always_comb begin
        data_out = packet.data + 8'd1;
        tag_out = packet.tag ^ 4'b1010;
    end
endmodule