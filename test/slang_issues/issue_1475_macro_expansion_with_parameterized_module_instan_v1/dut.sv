// MikePopoloski/slang#1475 (closed): Macro expansion with parameterized module instantiation fails unless preprocessed first
// https://github.com/MikePopoloski/slang/issues/1475
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module demo(
    input   clk,
    input   reset,
    input   do_fill,
    output  rdw_fill
);
    
    VX_pipe_register #( 
        .DATAW  ($bits(rdw_fill)), 
        .RESETW ($bits(rdw_fill)), 
        .DEPTH  (1) 
    ) __buffer_ex22 ( 
        .clk      (clk), 
        .reset    (reset), 
        .enable   (1'b1), 
        .data_in  (do_fill), 
        .data_out (rdw_fill) 
    );
endmodule
module VX_pipe_register #(
    parameter DATAW  = 1,
    parameter RESETW = 0,
    parameter DEPTH  = 1,
    parameter [(((RESETW) > 0) ? (RESETW) : 1)-1:0] INIT_VALUE = {(((RESETW) > 0) ? (RESETW) : 1){1'b0}}
) (
    input wire              clk,
    input wire              reset,
    input wire              enable,
    input wire [DATAW-1:0]  data_in,
    output reg [DATAW-1:0] data_out
);
    always @(posedge clk) begin
        if (reset)
            data_out <= INIT_VALUE;
        else if (enable)
            data_out <= data_in;
    end
endmodule

