// YosysHQ/yosys#5286 (closed): Multiple synthesis issues with SystemVerilog designs: hanging, frontend detection, memory handling, and security assertion limitations
// https://github.com/YosysHQ/yosys/issues/5286
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module memory_test (
    input wire clk_i,
    input wire reset_n_i,
    input wire [15:0] addr_i,
    input wire [31:0] data_i,
    input wire write_en_i,
    output reg [31:0] data_o
);

// Large memory array that causes hanging
reg [31:0] memory [0:65535]; // 64K x 32-bit

always @(posedge clk_i or negedge reset_n_i) begin
    if (!reset_n_i) begin
        data_o <= 32'h0;
    end else if (write_en_i) begin
        memory[addr_i] <= data_i;
        data_o <= data_i;
    end else begin
        data_o <= memory[addr_i];
    end
end

endmodule

// ---- b1.sv
module secure_memory_interface (
    input wire clk_i,
    input wire reset_n_i,
    input wire [31:0] addr_i,
    input wire [31:0] data_i,
    input wire write_en_i,
    output reg [31:0] data_o
);

parameter MAX_ADDR = 32'h0000FFFF;

// Yosys-compatible security (limited effectiveness)
`ifdef YOSYS_SYNTHESIS
    wire security_violation;
    assign security_violation = (addr_i >= MAX_ADDR);
    
    always @(posedge clk_i) begin
        if (write_en_i && !security_violation) begin
            // Normal operation
            data_o <= data_i;
        end else if (security_violation) begin
            // Security violation - but Yosys can't detect this properly
            data_o <= 32'hDEADBEEF;
        end
    end
`else
    // Full SystemVerilog security validation
    property addr_bounds;
        @(posedge clk_i) addr_i < MAX_ADDR;
    endproperty
    
    property write_security;
        @(posedge clk_i) write_en_i |-> addr_i < MAX_ADDR;
    endproperty
    
    // These assertions fail with Yosys
    assert property (addr_bounds) else $error("Address out of bounds");
    assert property (write_security) else $error("Write to invalid address");
    
    always @(posedge clk_i) begin
        if (write_en_i) begin
            assert (addr_i < MAX_ADDR) else $error("Security violation: write to invalid address");
            data_o <= data_i;
        end
    end
`endif

endmodule

