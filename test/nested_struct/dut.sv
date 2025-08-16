// First package with base struct
package base_pkg;
    typedef struct packed {
        logic [7:0] addr;
        logic [31:0] data;
        logic valid;
    } base_struct_t;
endpackage

// Second package that uses struct from first package
package main_pkg;
    import base_pkg::*;
    
    typedef struct packed {
        base_struct_t base;
        logic [15:0] id;
        logic [3:0] cmd;
        logic ready;
    } nested_struct_t;
endpackage

// Top module using nested struct as ports
module nested_struct (
    input  main_pkg::nested_struct_t in_data,
    output main_pkg::nested_struct_t out_data,
    input  logic clk,
    input  logic rst
);
    import main_pkg::*;
    import base_pkg::*;
    
    // Internal signal
    nested_struct_t processed_data;
    
    // Sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            out_data <= '0;
        end else begin
            out_data <= processed_data;
        end
    end
    
    // Combinational processing
    always_comb begin
        processed_data = in_data;
        
        // Modify nested struct fields
        processed_data.base.addr = in_data.base.addr + 8'd1;
        processed_data.base.data = in_data.base.data ^ 32'hDEADBEEF;
        processed_data.base.valid = in_data.base.valid & in_data.ready;
        
        // Modify top-level fields
        processed_data.id = in_data.id + 16'd100;
        processed_data.cmd = in_data.cmd | 4'b1010;
        processed_data.ready = in_data.base.valid;
    end
    
endmodule