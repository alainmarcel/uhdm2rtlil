// YosysHQ/yosys#3592 (open): Wider ports in SystemVerilog interfaces are treated as single bit wire
// https://github.com/YosysHQ/yosys/issues/3592
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): r exposed as an output + wrapper top (the interface-port module cannot be a co-sim top)

// ---- b0.sv
interface inf;
    logic [7:0] a;
    modport Slave(input a);
endinterface

module top (
    input clk,
    inf.Slave bus,
    output logic [7:0] r_o
);

    logic [7:0] r;
    initial r = '0;
    assign r_o = r;
   
    always_ff @(posedge clk) begin
        r <= bus.a; 
    end

    always @(posedge clk) begin
        cover(r == 8'b0000_0001); // cover, since bus.a as treated as a one bit value
        cover(r == 8'b0000_0011); // not cover
    end
endmodule

module harness_top (input clk, input [7:0] a, output [7:0] r_o);
    inf bus();
    assign bus.a = a;
    top u (.clk(clk), .bus(bus.Slave), .r_o(r_o));
endmodule
