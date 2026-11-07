// YosysHQ/yosys#5802 (closed): ABC regression
// https://github.com/YosysHQ/yosys/issues/5802
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// carry_test.v
// Reproducer for ABC &if required-time regression (YosysHQ/abc b4a657e7 vs de0ebae1)
// A 32-bit accumulator fed by several levels of control logic,
// mimicking the decode->datapath->carry-chain structure of a J-Core CPU.
// Target: synth_ice40

module carry_test (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [7:0]  op,
    output reg  [32:0] result,
    output reg  [31:0] acc
);
    // Decode stage: several LUT levels selecting operation
    wire [31:0] sel0 = op[0] ? a          : b;
    wire [31:0] sel1 = op[1] ? (a ^ b)    : (a & b);
    wire [31:0] sel2 = op[2] ? (a | b)    : (~a & b);
    wire [31:0] mux0 = op[3] ? sel0       : sel1;
    wire [31:0] mux1 = op[4] ? mux0       : sel2;

    // More logic mixing accumulated value back in (creates feedback-like depth)
    wire [31:0] t0 = mux1 ^ acc;
    wire [31:0] t1 = (t0 & ~mux0) | (mux0 & ~t0);
    wire [31:0] t2 = t1 ^ {t1[30:0], 1'b0};
    wire [31:0] t3 = t2 ^ {op[7:0], op[7:0], op[7:0], op[7:0]};
    wire [31:0] t4 = t3 & (mux1 | acc);
    wire [31:0] t5 = mux1 ^ t4;

    // 32-bit adder: the carry chain abc9 boxes
    wire [32:0] sum = {1'b0, t4} + {1'b0, t5};

    always @(posedge clk) begin
        if (rst) begin
            result <= 0;
            acc    <= 0;
        end else begin
            result <= sum;
            acc    <= sum[31:0];
        end
    end
endmodule

