// Simple test for nested struct handling
module simple_nested_struct_nopack (
    input  logic [61:0] in_data,
    output logic [61:0] out_data
);
    
    // Define packed structs
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
    
    // Struct signals
    nested_struct_t in_struct;
    nested_struct_t out_struct;
    
    // Connect input/output
    assign in_struct = in_data;
    assign out_data = out_struct;
    
    // Simple combinational logic on struct fields
    always_comb begin
        // Pass through most fields
        out_struct = in_struct;
        
        // Modify specific fields to test struct member access
        out_struct.base.addr = in_struct.base.addr + 8'd1;
        out_struct.base.data = in_struct.base.data ^ 32'hDEADBEEF;
        out_struct.base.valid = in_struct.base.valid & in_struct.ready;
        out_struct.id = in_struct.id + 16'd100;
        out_struct.cmd = in_struct.cmd | 4'b1010;
        out_struct.ready = in_struct.base.valid;
    end
    
endmodule