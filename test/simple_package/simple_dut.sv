// Simpler test case for package with just parameter

package simple_pkg;
    parameter int WIDTH = 8;
    parameter int DEPTH = 16;
endpackage

module simple_package_test 
    import simple_pkg::*;
(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    
    // Use package parameter
    logic [WIDTH-1:0] data_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= '0;
        end else begin
            data_reg <= data_in;
        end
    end
    
    assign data_out = data_reg;
    
endmodule