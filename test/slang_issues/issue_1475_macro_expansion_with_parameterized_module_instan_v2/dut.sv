// MikePopoloski/slang#1475 (closed): Macro expansion with parameterized module instantiation fails unless preprocessed first
// https://github.com/MikePopoloski/slang/issues/1475
// Code block(s) from the issue (variant v2); harvested by test/slang_issues/harvest.py

// ---- b0.sv
// demo.v
module demo_tb;
    reg clk, reset;
    reg [3:0] do_fill;
    wire [3:0] rdw_fill;

    demo dut (
        .clk(clk),
        .reset(reset),
        .do_fill(do_fill),
        .rdw_fill(rdw_fill)
    );

    always begin
        #1;
        clk = ~clk;
    end

    integer i;

    initial begin
        $monitor("%t: do_fill = %d, rdw_fill = %d", $time, do_fill, rdw_fill);
        clk = 1'b0;
        reset = 1'b1;
        #2;
        reset = 1'b0;
        for (i = 0; i < (1 << $bits(do_fill)); i++) begin
            do_fill = i[3:0];
            #2;
        end
        $finish;
    end

endmodule

`define BUFFER(dst, src) `BUFFER_EX(dst, src, 1'b1, $bits(dst), 1)
`define BUFFER_EX(dst, src, ena, resetw, latency) \
    VX_pipe_register #( \
        .DATAW  ($bits(dst)), \
        .RESETW (resetw), \
        .DEPTH  (latency) \
    ) __buffer_ex`__LINE__ ( \
        .clk      (clk), \
        .reset    (reset), \
        .enable   (ena), \
        .data_in  (src), \
        .data_out (dst) \
    )
`define UP(x)       (((x) > 0) ? (x) : 1)

module demo(
    input   clk,
    input   reset,
    input   [3:0] do_fill,
    output  [3:0] rdw_fill
);
    `BUFFER(rdw_fill, do_fill);
endmodule

module VX_pipe_register #(
    parameter DATAW  = 1,
    parameter RESETW = 0,
    parameter DEPTH  = 1,
    parameter [`UP(RESETW)-1:0] INIT_VALUE = {`UP(RESETW){1'b0}}
) (
    input wire              clk,
    input wire              reset,
    input wire              enable,
    input wire [DATAW-1:0]  data_in,
    output reg [DATAW-1:0]  data_out
);

    always @(posedge clk) begin
        if (reset)
            data_out <= INIT_VALUE;
        else if (enable)
            data_out <= data_in;
    end

endmodule

