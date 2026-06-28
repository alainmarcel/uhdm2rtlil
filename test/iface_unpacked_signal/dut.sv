// Minimal repro: an UNPACKED-ARRAY interface signal with internal assigns
// (like tcb_lite_if's `trn_dly [0:DLY]`).
interface myif (input logic clk, input logic rst);
  logic a;
  logic d [0:1];
  assign d[0] = a;
  assign d[1] = d[0];
  modport sub (input clk, input rst, output a, input d);
endinterface
module rd (myif.sub s, input logic g, output logic o);
  assign s.a = g;
  assign o = s.d[1];            // read unpacked-array element
endmodule
module dut (input logic clk, input logic rst, input logic g, output logic o);
  myif inst (.clk(clk), .rst(rst));
  rd r (.s(inst), .g(g), .o(o));
endmodule
