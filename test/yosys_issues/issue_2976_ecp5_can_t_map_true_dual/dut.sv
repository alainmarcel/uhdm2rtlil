// YosysHQ/yosys#2976 (closed): ecp5: can't map true dual port RAM
// https://github.com/YosysHQ/yosys/issues/2976
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// bram_2r2w.sv
`timescale 1 ns / 1 ps
`default_nettype none

module bram_2r2w
  # ( parameter DATA_WIDTH = 32
    , parameter ADDR_WIDTH = 5
    )
    ( input wire logic clk

    , input  wire logic                  wen_1
    , input  wire logic                  wwr_1
    , input  wire logic [ADDR_WIDTH-1:0] addr_1
    , input  wire logic [DATA_WIDTH-1:0] wdata_1
    , output reg        [DATA_WIDTH-1:0] rdata_1

    , input  wire logic                  wen_2
    , input  wire logic                  wwr_2
    , input  wire logic [ADDR_WIDTH-1:0] addr_2
    , input  wire logic [DATA_WIDTH-1:0] wdata_2
    , output reg        [DATA_WIDTH-1:0] rdata_2
    );

  (* syn_ramstyle = "block_ram" *)
  reg [DATA_WIDTH-1:0] ram[0:(1 << ADDR_WIDTH)-1];

  always_ff @(posedge clk) begin
    if (wen_1) begin
      if (wwr_1) begin
        ram[addr_1] <= wdata_1;
        rdata_1     <= wdata_1;
      end else begin
        rdata_1 <= ram[addr_1];
      end
    end
  end

  always_ff @(posedge clk) begin
    if (wen_2) begin
      if (wwr_2) begin
        ram[addr_2] <= wdata_2;
        rdata_2     <= wdata_2;
      end else begin
        rdata_2 <= ram[addr_2];
      end
    end
  end
endmodule

