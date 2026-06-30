// XMR (cross-module reference) read: the top reaches into a submodule INSTANCE
// to grab an internal signal — `assign monitor_flag = u_processor.internal_ready`
// (github issue #450).  The UHDM frontend silently dropped it (monitor_flag
// undriven); the Verilog frontend implicitly declares \u_processor.internal_ready
// and lets flatten resolve it.
module DataProcessor (
    input  wire       clk,
    input  wire [7:0] data_in,
    output reg  [7:0] data_out
);
    reg internal_ready;
    always @(posedge clk) begin
        data_out <= data_in + 8'h01;
        internal_ready <= (data_in > 8'h0A);
    end
endmodule

module dut (
    input  wire       clk,
    input  wire [7:0] system_in,
    output wire [7:0] system_out,
    output wire       monitor_flag
);
    DataProcessor u_processor (
        .clk(clk),
        .data_in(system_in),
        .data_out(system_out)
    );
    assign monitor_flag = u_processor.internal_ready;
endmodule
