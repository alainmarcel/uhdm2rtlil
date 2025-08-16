module debug_test (
    input  logic [61:0] in_data,
    output logic [61:0] out_data
);
    
    // Same struct definitions
    typedef struct packed {
        logic [7:0]  addr;
        logic [31:0] data;
        logic        valid;
    } base_struct_t;
    
    typedef struct packed {
        base_struct_t base;
        logic [15:0]  id;
        logic [3:0]   cmd;
        logic         ready;
    } nested_struct_t;
    
    nested_struct_t in_struct;
    nested_struct_t processed_data;
    
    assign in_struct = in_data;
    assign out_data = processed_data;
    
    // Test just the combinational logic
    always_comb begin
        processed_data = in_struct;
        
        // Modify nested struct fields
        processed_data.base.addr = in_struct.base.addr + 8'd1;
        processed_data.base.data = in_struct.base.data ^ 32'hDEADBEEF;
        processed_data.base.valid = in_struct.base.valid & in_struct.ready;
        
        // Modify top-level fields
        processed_data.id = in_struct.id + 16'd100;
        processed_data.cmd = in_struct.cmd | 4'b1010;
        processed_data.ready = in_struct.base.valid;
    end
    
endmodule