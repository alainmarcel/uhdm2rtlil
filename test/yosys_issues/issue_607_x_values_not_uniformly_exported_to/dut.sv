// YosysHQ/yosys#607 (closed): 'x' values not uniformly exported to JSON in init values for memories
// https://github.com/YosysHQ/yosys/issues/607
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module rom(input [N-1:0] addr, output [3:0] data);

parameter N = 4;

integer i;

logic [3:0] mem[(1<<N)-1:0];

initial begin
    for (i = 0; i < (1<<N); i = i+1) mem[i] = 4'b1x1x;
end

assign data = mem[addr];

endmodule

