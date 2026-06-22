module dut(a, o);
input  signed [3:0] a;
output signed [3:0] o;

assign o = a >>> 2;

endmodule
