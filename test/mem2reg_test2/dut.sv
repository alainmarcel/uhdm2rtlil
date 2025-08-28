module mem2reg_test2(clk, reset, mode, addr, data);

input clk, reset, mode;
input [2:0] addr;
output [3:0] data;

(* mem2reg *)
reg [3:0] mem [0:7];

assign data = mem[addr];

integer i;

always @(posedge clk) begin
	if (reset) begin
		for (i=0; i<8; i=i+1)
			mem[i] <= i;
	end else
	if (mode) begin
		for (i=0; i<8; i=i+1)
			mem[i] <= mem[i]+1;
	end else begin
		mem[addr] <= 0;
	end
end

endmodule