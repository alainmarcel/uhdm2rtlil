// MikePopoloski/slang#1354 (closed): Macro definitions (`ifdef`, ``define`) deal with the problem
// https://github.com/MikePopoloski/slang/issues/1354
// Code block(s) from the issue (variant v0_tc); harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define ENABLE_FEATURE_X // Define a macro for conditional compilation

module comment_example #(
    parameter WIDTH = 8 // Parameter for data width, with a line-end comment
) (
    input  logic clk,       
    input  logic rst_n     
);

    // This is a comment starting at the beginning of a line, before any code.
    logic [WIDTH-1:0] internal_reg; // An internal register

`ifndef DISABLE_DEBUG_MESSAGES
    // This block is active if DISABLE_DEBUG_MESSAGES is NOT defined
    always_comb begin
        // Combinational logic for debugging (if enabled)
        if (data_in > 100) begin
            $display("Debug: data_in (%0d) is greater than 100 at time %0t", data_in, $time); // Line-end comment
        end
    end
`endif


endmodule // End of module comment_example

