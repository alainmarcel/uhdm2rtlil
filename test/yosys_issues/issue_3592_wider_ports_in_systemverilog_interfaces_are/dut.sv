// YosysHQ/yosys#3592 (open): Wider ports in SystemVerilog interfaces are treated as single bit wire
// https://github.com/YosysHQ/yosys/issues/3592
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
interface inf;
    logic [7:0] a;
    modport Slave(input a);
endinterface

module top (
    input clk,
    inf.Slave bus    
);

    logic [7:0] r;
    initial r = '0;
   
    always_ff @(posedge clk) begin
        r <= bus.a; 
    end

    always @(posedge clk) begin
        cover(r == 8'b0000_0001); // cover, since bus.a as treated as a one bit value
        cover(r == 8'b0000_0011); // not cover
    end
endmodule

