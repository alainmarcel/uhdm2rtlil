// YosysHQ/yosys#1592 (open): Clock in interface port mis-synthesized away (but accepted in modport)
// https://github.com/YosysHQ/yosys/issues/1592
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
interface dummybus(input clk, input rst);
    modport host(input clk, input rst);
    modport device(input clk, input rst);
endinterface

module top(input clk, input rst);
    dummybus bus(.clk, .rst); // bus driven here
    device dev(.bus);
    host host(.clk, .rst, .bus);
endmodule

module host(input clk, input rst, dummybus.host bus);
    // This page intentionally left blank
endmodule

module device(dummybus.device bus);
    (* keep *)
    logic [63:0] keep;
    always @(posedge bus.clk)
        if (bus.rst) begin
            keep <= 'b0;
        end else begin
            keep <= keep + 'b1;
        end
endmodule

