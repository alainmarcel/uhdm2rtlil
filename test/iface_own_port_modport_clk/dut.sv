// `.clk(port.clk)` where `clk` is one of the INTERFACE'S OWN PORTS, in a module
// that has TWO interface ports whose types BOTH declare `clk` -- the shape of
// RSD's MulDivUnit (`MulDivUnitIF.MulDivUnit port, RecoveryManagerIF.MulDivUnit
// recovery`) and FPDivSqrtUnit.
//
// The elaborated actual is a bare net named `clk`, so the member has to be
// matched back to one of the module's interface ports by TYPE.  Every interface
// here declares `clk` as an own port, so that test alone is ambiguous -- and the
// resolution used to give up, dropping the connection entirely ("Port clk has
// empty connection").  The child's pipeline register then had no clock and its
// output stayed 0 forever.
//
// The modport is what disambiguates: only `BusIF.Sub` exposes `clk`;
// `CtrlIF.Sub` lists `flush` alone, so it is not a candidate for `clk` at all.
interface BusIF(input logic clk, rst);
    logic [31:0] din;
    logic [31:0] dout;
    modport Sub(input clk, rst, din, output dout);
endinterface

interface CtrlIF(input logic clk, rst);
    logic flush;
    modport Sub(input flush);
endinterface

module child(
    input  logic        clk,
    input  logic [31:0] din,
    output logic [31:0] dout
);
    always_ff @(posedge clk) dout <= din;
endmodule

module mid(BusIF.Sub port, CtrlIF.Sub ctrl);
    for (genvar i = 0; i < 1; i++) begin : BlockUnit
        child u_child (
            .clk  (port.clk),
            .din  (port.din),
            .dout (port.dout)
        );
    end
    logic unused;
    assign unused = ctrl.flush;
endmodule

module dut(
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] din,
    output logic [31:0] dout
);
    BusIF  bus  (.clk(clk), .rst(rst));
    CtrlIF ctl  (.clk(clk), .rst(rst));
    mid u_mid (.port(bus), .ctrl(ctl));
    assign bus.din = din;
    assign dout    = bus.dout;
endmodule
