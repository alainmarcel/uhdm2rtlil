// YosysHQ/yosys#589 (closed): Regression in synthesis for synchronous memory (ice40)
// https://github.com/YosysHQ/yosys/issues/589
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module coreir_mem #(parameter depth=1, parameter has_init=1, parameter width=1) (
  input clk,
  input [width-1:0] wdata,
  input [$clog2(depth)-1:0] waddr,
  input wen,
  output reg [width-1:0] rdata,
  input [$clog2(depth)-1:0] raddr
);
  reg [width-1:0] data[depth-1:0];
  always @(posedge clk) begin
    if (wen) begin
      data[waddr] <= wdata;
    end
    rdata <= data[raddr];
  end

endmodule //coreir_mem

module main (output [4:0] J3, input  CLKIN);
  wire [7:0] mem__rdata;
  coreir_mem #(.depth(16),.has_init(0),.width(8)) mem(
    .clk(CLKIN),
    .raddr(0),
    .rdata(mem__rdata),
    .waddr(0),
    .wdata(mem__rdata),
    .wen(1)
  );
  assign J3 = mem__rdata[4:0];
endmodule

