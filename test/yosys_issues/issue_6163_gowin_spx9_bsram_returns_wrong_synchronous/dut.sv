// YosysHQ/yosys#6163 (open): Gowin SPX9 BSRAM returns wrong synchronous-read data when read output is cleared while idle
// https://github.com/YosysHQ/yosys/issues/6163
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module ram (
    input  logic        clk,
    input  logic [7:0]  address,
    input  logic        store_enable,
    input  logic [15:0] store_data,
    input  logic        load_enable,
    output logic [15:0] load_data,
    input  logic        capture_enable,
    output logic [15:0] captured_data
);
    logic [15:0] memory [0:255];
    always_ff @(posedge clk) begin
        if (store_enable) begin
            memory[address] <= store_data;
        end
        if (load_enable) begin
            load_data <= memory[address];
        end else begin
            load_data <= 16'h0000;
        end
    end
    // Samples the previous value of load_data on this clock edge.
    always_ff @(posedge clk) begin
        if (capture_enable) begin
            captured_data <= load_data;
        end
    end
endmodule

