// Test case for SystemVerilog package with struct and parameter

// Define a package with struct and parameter
package my_pkg;
    // Parameter definition
    parameter int DATA_WIDTH = 32;
    parameter int ADDR_WIDTH = 16;
    
    // Struct definition
    typedef struct packed {
        logic [DATA_WIDTH-1:0] data;
        logic [ADDR_WIDTH-1:0] addr;
        logic                  valid;
        logic                  ready;
    } bus_transaction_t;
    
    // Function in package
    function automatic logic [DATA_WIDTH-1:0] increment_data(logic [DATA_WIDTH-1:0] input_data);
        return input_data + 1;
    endfunction
    
endpackage

// Module that imports and uses the package
module simple_package 
    import my_pkg::*;
(
    input  logic                     clk,
    input  logic                     rst_n,
    input  bus_transaction_t         bus_in,
    output bus_transaction_t         bus_out
);
    
    // Internal signal using package struct
    bus_transaction_t internal_bus;
    
    // Register to hold transaction
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            internal_bus.data  <= '0;
            internal_bus.addr  <= '0;
            internal_bus.valid <= '0;
            internal_bus.ready <= '0;
        end else begin
            internal_bus <= bus_in;
            // Use package function
            internal_bus.data <= increment_data(bus_in.data);
        end
    end
    
    // Instance of sub-module that also uses the package
    sub_module sub_inst (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(internal_bus),
        .data_out(bus_out)
    );
    
endmodule

// Sub-module that also imports the package
module sub_module 
    import my_pkg::*;
(
    input  logic                     clk,
    input  logic                     rst_n,
    input  bus_transaction_t         data_in,
    output bus_transaction_t         data_out
);
    
    // Local parameter using package parameter
    localparam int COUNTER_WIDTH = $clog2(DATA_WIDTH);
    
    // Counter for demonstration
    logic [COUNTER_WIDTH-1:0] counter;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
            data_out.data  <= '0;
            data_out.addr  <= '0;
            data_out.valid <= '0;
            data_out.ready <= '0;
        end else begin
            counter <= counter + 1;
            
            // Process the transaction
            data_out <= data_in;
            
            // Modify based on counter
            if (counter == 0) begin
                data_out.ready <= 1'b1;
            end else begin
                data_out.ready <= data_in.valid;
            end
        end
    end
    
endmodule