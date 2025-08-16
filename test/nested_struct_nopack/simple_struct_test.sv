// Simple test focused on nested struct handling
module simple_struct_test (
    input  logic [61:0] in_data,
    output logic [61:0] out_data
);
    
    // Same struct definitions as the original
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
    nested_struct_t out_struct;
    
    assign in_struct = in_data;
    assign out_data = out_struct;
    
    // Simple combinational logic - just pass through with modifications
    assign out_struct.base.addr = in_struct.base.addr + 8'd1;
    assign out_struct.base.data = in_struct.base.data ^ 32'hDEADBEEF;
    assign out_struct.base.valid = in_struct.base.valid & in_struct.ready;
    assign out_struct.id = in_struct.id + 16'd100;
    assign out_struct.cmd = in_struct.cmd | 4'b1010;
    assign out_struct.ready = in_struct.base.valid;
    
endmodule