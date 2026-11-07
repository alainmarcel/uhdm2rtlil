// YosysHQ/yosys#2020 (closed): ROM memories initialized with $readmemh not using $memrd cells
// https://github.com/YosysHQ/yosys/issues/2020
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module ram(input clk, wr, input [7:0] idata, input [3:0] addr, output [7:0] data);
    logic [7:0] mem[0:15];
    assign data = mem[addr];
    initial $readmemh("image.hex", mem);
    always_ff @(posedge clk)
        if (wr) mem[addr] <= idata;
endmodule

// ---- b1.sv
module rom(input [3:0] addr, output [7:0] data);
    logic [7:0] mem[0:15];
    assign data = mem[addr];
    initial $readmemh("image.hex", mem);
endmodule

// ---- b2.sv
module test(input [3:0] addr, output [7:0] data);
    logic [7:0] mem[0:15];
    assign data = mem[addr];
    integer i;
    initial for(i = 0; i < 16; i = i + 1) mem[i] = i;
endmodule

