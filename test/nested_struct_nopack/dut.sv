// Nested struct test without packages - compatible with Verilog frontend
module nested_struct_nopack (
    input  logic [61:0] in_data,   // Flattened struct: [61:21]=top_fields, [20:0]=base_struct
    output logic [61:0] out_data,
    input  logic clk,
    input  logic rst
);
    // Define structs locally without packages
    typedef struct packed {
        logic [7:0] addr;      // bits [40:33]
        logic [31:0] data;     // bits [32:1]
        logic valid;           // bit [0]
    } base_struct_t;
    
    typedef struct packed {
        base_struct_t base;    // bits [40:0]
        logic [15:0] id;       // bits [56:41]
        logic [3:0] cmd;       // bits [60:57]
        logic ready;           // bit [61]
    } nested_struct_t;
    
    // Cast input/output to struct types
    nested_struct_t in_struct;
    nested_struct_t out_struct;
    nested_struct_t processed_data;
    
    assign in_struct = in_data;
    assign out_data = out_struct;
    
    // Sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            out_struct <= '0;
        end else begin
            out_struct <= processed_data;
        end
    end
    
    // Combinational processing - same logic as nested_struct
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