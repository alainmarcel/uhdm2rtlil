// Smallest reproducer that still TRIGGERS the array-interface-port path
// (interface with clk/rst ports → port width -2).  drv has an array of
// interface ports m[2]; its per-element m[i].dat must become ports.
interface myif (input logic clk, input logic rst);
  logic [7:0] dat;
  modport man (input clk, input rst, output dat);
  modport sub (input clk, input rst, input  dat);
endinterface

module drv (myif.man m [2-1:0]);
  assign m[0].dat = 8'd10;
  assign m[1].dat = 8'd20;
endmodule

module dut (input logic clk, input logic rst,
            output logic [7:0] o0, output logic [7:0] o1);
  myif arr [2-1:0] (.clk(clk), .rst(rst));
  drv  d (.m(arr));
  assign o0 = arr[0].dat;
  assign o1 = arr[1].dat;
endmodule
