// YosysHQ/yosys#1592 (open): Clock in interface port mis-synthesized away (but accepted in modport)
// https://github.com/YosysHQ/yosys/issues/1592
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
interface dummybus();
    logic clk;
    logic rst;
    modport host(output clk, output rst);
    modport device(input clk, input rst);
endinterface

module top(input clk, input rst);
    dummybus bus();
    device dev(.bus);
    host host(.clk, .rst, .bus);
endmodule

module host(input clk, input rst, dummybus.host bus);
    // This works, the clock is recognized
    assign bus.clk = clk;
    assign bus.rst = rst;
endmodule

module device (dummybus.device bus);
    (* keep *)
    logic [63:0] keep;
    always @(posedge bus.clk)
        if (bus.rst) begin
            keep <= 'b0;
        end else begin
            keep <= keep + 'b1;
        end
endmodule

