// Simplified test case for arrays of packed structs
typedef struct packed {
    logic [7:0] data;
    logic [3:0] tag;
} packet_t;

// Simple module that uses struct arrays
module struct_array_simple (
    input  packet_t packets_in[4],
    output packet_t packets_out[4]
);
    // Simple pass-through with modification
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_loop
            assign packets_out[i].data = packets_in[i].data + 8'd1;
            assign packets_out[i].tag = packets_in[i].tag ^ 4'b1010;
        end
    endgenerate
endmodule