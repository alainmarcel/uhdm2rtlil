// Test case for generate loops and if-else generate blocks

// Simple adder module
module adder #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] sum
);
    assign sum = a + b;
endmodule

// Simple subtractor module
module subtractor #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] diff
);
    assign diff = a - b;
endmodule

// Main module with generate constructs
module generate_test #(
    parameter NUM_UNITS = 4,
    parameter DATA_WIDTH = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [NUM_UNITS*DATA_WIDTH-1:0] data_in,  // Flattened array
    input  logic [NUM_UNITS*DATA_WIDTH-1:0] operand,  // Flattened array
    input  logic mode,  // 0=add, 1=subtract
    output logic [NUM_UNITS*DATA_WIDTH-1:0] result,   // Flattened array
    output logic [DATA_WIDTH-1:0] extra_result         // Extra result for conditional logic
);
    
    // Generate for loop to create multiple processing units
    genvar i;
    generate
        for (i = 0; i < NUM_UNITS; i = i + 1) begin : gen_units
            // Local wires for this unit
            logic [DATA_WIDTH-1:0] unit_result;
            
            // If-else generate based on unit index
            if (i % 2 == 0) begin : even_unit
                // Even units use adder
                adder #(
                    .WIDTH(DATA_WIDTH)
                ) adder_inst (
                    .a(data_in[i*DATA_WIDTH +: DATA_WIDTH]),
                    .b(operand[i*DATA_WIDTH +: DATA_WIDTH]),
                    .sum(unit_result)
                );
            end else begin : odd_unit
                // Odd units use subtractor
                subtractor #(
                    .WIDTH(DATA_WIDTH)
                ) subtractor_inst (
                    .a(data_in[i*DATA_WIDTH +: DATA_WIDTH]),
                    .b(operand[i*DATA_WIDTH +: DATA_WIDTH]),
                    .diff(unit_result)
                );
            end
            
            // Register the output
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result[i*DATA_WIDTH +: DATA_WIDTH] <= '0;
                end else begin
                    result[i*DATA_WIDTH +: DATA_WIDTH] <= unit_result;
                end
            end
        end
    endgenerate
    
    // Another generate block with conditional instantiation
    generate
        if (NUM_UNITS > 2) begin : extra_logic
            // Extra adder for units 0 and 1 when we have more than 2 units
            logic [DATA_WIDTH-1:0] extra_sum;
            
            adder #(
                .WIDTH(DATA_WIDTH)
            ) extra_adder (
                .a(result[0*DATA_WIDTH +: DATA_WIDTH]),
                .b(result[1*DATA_WIDTH +: DATA_WIDTH]),
                .sum(extra_sum)
            );
            
            // Store extra sum in the extra_result output
            if (NUM_UNITS > 3) begin : store_extra
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        extra_result <= '0;
                    end else if (mode) begin
                        extra_result <= extra_sum;
                    end
                end
            end else begin : no_extra
                assign extra_result = '0;
            end
        end else begin : no_extra_logic
            // When NUM_UNITS <= 2, extra_result is always 0
            assign extra_result = '0;
        end
    endgenerate
    
endmodule