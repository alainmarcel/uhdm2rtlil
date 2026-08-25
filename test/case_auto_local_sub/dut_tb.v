`timescale 1ns/1ps
module tb;
  reg [11:0] addr; reg [63:0] cfg;
  wire exc; wire [31:0] rd;
  case_auto_local_sub d(.addr(addr), .cfg_all(cfg), .exc(exc), .rdata(rd));
  integer a;
  initial begin
    cfg = 64'hDEADBEEF_12345678;
    for (a=12'h39E; a<=12'h3AA; a=a+1) begin
      addr=a[11:0]; #1;
      $display("addr=%03h exc=%b rd=%h", a, exc, rd);
    end
    $finish;
  end
endmodule
