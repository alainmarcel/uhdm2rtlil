// Test case for arrays of packed structs
typedef struct packed {
    logic [7:0] data;
    logic [3:0] tag;
    logic       valid;
} packet_t;

// Module that processes an array of packets
module packet_processor (
    input  packet_t packets_in[0:3],
    output packet_t packets_out[0:3]
);
    // Process each packet - increment data and invert valid
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : proc_loop
            assign packets_out[i].data = packets_in[i].data + 8'd1;
            assign packets_out[i].tag = packets_in[i].tag;
            assign packets_out[i].valid = ~packets_in[i].valid;
        end
    endgenerate
endmodule

// Module that filters packets based on valid flag
module packet_filter (
    input  packet_t packets_in[0:3],
    output logic [7:0] valid_data[0:3],
    output logic [3:0] valid_count
);
    always_comb begin
        valid_count = 4'd0;
        for (int i = 0; i < 4; i++) begin
            if (packets_in[i].valid) begin
                valid_data[i] = packets_in[i].data;
                valid_count = valid_count + 4'd1;
            end else begin
                valid_data[i] = 8'd0;
            end
        end
    end
endmodule

// Top module that instantiates both
module struct_array (
    input  logic [7:0] data_in[0:3],
    input  logic [3:0] tag_in[0:3],
    input  logic       valid_in[0:3],
    output logic [7:0] data_out[0:3],
    output logic [3:0] tag_out[0:3],
    output logic       valid_out[0:3],
    output logic [7:0] filtered_data[0:3],
    output logic [3:0] valid_count
);
    // Create packet arrays
    packet_t input_packets[0:3];
    packet_t processed_packets[0:3];
    
    // Pack input data into structs
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            input_packets[i].data = data_in[i];
            input_packets[i].tag = tag_in[i];
            input_packets[i].valid = valid_in[i];
        end
    end
    
    // Instantiate packet processor
    packet_processor proc_inst (
        .packets_in(input_packets),
        .packets_out(processed_packets)
    );
    
    // Instantiate packet filter on processed packets
    packet_filter filter_inst (
        .packets_in(processed_packets),
        .valid_data(filtered_data),
        .valid_count(valid_count)
    );
    
    // Unpack output structs
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            data_out[i] = processed_packets[i].data;
            tag_out[i] = processed_packets[i].tag;
            valid_out[i] = processed_packets[i].valid;
        end
    end
endmodule