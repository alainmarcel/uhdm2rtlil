module dut(a, o);
input  [2:0] a;
output [2:0] o;

assign o = a << 1;

endmodule
