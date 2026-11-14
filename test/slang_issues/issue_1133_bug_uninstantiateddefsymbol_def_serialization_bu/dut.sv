// MikePopoloski/slang#1133 (closed): [bug] UninstantiatedDefSymbol def serialization bug  
// https://github.com/MikePopoloski/slang/issues/1133
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module debug_rom (
  input  logic         clk_i,
  input  logic         req_i,
  input  logic [63:0]  addr_i,
  output logic [63:0]  rdata_o
);

endmodule

module top (
    input logic clk_i,
    input logic req_i,
    input  logic [63:0]  rom_addr,
    output logic [63:0]  rom_rdata
);

    localparam bit P = 0;

    if (P) begin
        debug_rom i_debug_rom (
            .clk_i,
            .req_i,
            .addr_i  ( rom_addr  ),
            .rdata_o ( rom_rdata )
        );
    end

endmodule

