// YosysHQ/yosys#6393 (open): `write_btor`: an undriven run swallows the input-port bits that follow it in a signal; later bitwise readers of the port read the anonymous input
// https://github.com/YosysHQ/yosys/issues/6393
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// mon.pay is a public wire nothing reads: opt_clean removes the drivers of its computed bits (mon.nsize, mon.shift are
// read by nothing else), while its other bits alias the input ports addr and id. The register top.pay_q loads the same
// ports bit by bit.
module mon(input [7:0] addr, input [1:0] id, input [2:0] size);
  wire [2:0] nsize = (size > 3'd2) ? 3'd2 : size;
  wire [2:0] shift = (size > 3'd2) ? size - 3'd2 : 3'd0;
  wire [15:0] pay = {addr, id, nsize, shift};          // read by nothing
endmodule
module top(input clk, input [7:0] addr, input [1:0] id, input [2:0] size, input valid, output reg [15:0] pay_q);
  wire [2:0] nsize = (size > 3'd2) ? 3'd2 : size;
  wire [2:0] shift = (size > 3'd2) ? size - 3'd2 : 3'd0;
  always @(posedge clk) if (valid) pay_q <= {addr, id, nsize, shift};
  mon env(.addr(addr), .id(id), .size(size));
endmodule

