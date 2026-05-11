module pass_through(
    input [63:0] inp,
    output [63:0] out
);
    assign out = inp;
endmodule

module set_param #(
    parameter logic [63:0] VALUE
) (
    output logic [63:0] out
);
    assign out = VALUE;
endmodule

module top (
    // Forward all 20 internal observables so an external co-sim can
    // sample them.  Co-sim will mismatch on the x/z signals — that's
    // recorded in test/sim_equiv_analyzed.txt as a known RTL-vs-synth
    // four-state divergence (synth legalises 'x and 'z to '0).
    output logic [63:0] o01_o, o02_o, o03_o, o04_o,
    output logic [63:0] o05_o, o06_o, o07_o, o08_o,
    output logic [63:0] o09_o, o10_o, o11_o, o12_o,
    output logic [63:0] o13_o, o14_o, o15_o, o16_o,
    output logic [63:0] l01_o, l02_o, l03_o, l04_o
);
    localparam logic [63:0]
        l01 = '0,
        l02 = '1,
        l03 = 'x,
        l04 = 'z;
    logic [63:0]
        o01, o02, o03, o04,
        o05, o06, o07, o08,
        o09, o10, o11, o12,
        o13, o14, o15, o16;
    assign o01 = '0;
    assign o02 = '1;
    assign o03 = 'x;
    assign o04 = 'z;
    assign o05 = 3'('0);
    assign o06 = 3'('1);
    assign o07 = 3'('x);
    assign o08 = 3'('z);
    pass_through pt09('0, o09);
    pass_through pt10('1, o10);
    pass_through pt11('x, o11);
    pass_through pt12('z, o12);
    set_param #('0) sp13(o13);
    set_param #('1) sp14(o14);
    set_param #('x) sp15(o15);
    set_param #('z) sp16(o16);

    assign o01_o = o01; assign o02_o = o02; assign o03_o = o03; assign o04_o = o04;
    assign o05_o = o05; assign o06_o = o06; assign o07_o = o07; assign o08_o = o08;
    assign o09_o = o09; assign o10_o = o10; assign o11_o = o11; assign o12_o = o12;
    assign o13_o = o13; assign o14_o = o14; assign o15_o = o15; assign o16_o = o16;
    assign l01_o = l01; assign l02_o = l02; assign l03_o = l03; assign l04_o = l04;

`ifndef VERILATOR
    always @* begin
        assert (o01 === {64 {1'b0}});
        assert (o02 === {64 {1'b1}});
        assert (o03 === {64 {1'bx}});
        assert (o04 === {64 {1'bz}});
        assert (o05 === {61'b0, 3'b000});
        assert (o06 === {61'b0, 3'b111});
        assert (o07 === {61'b0, 3'bxxx});
        assert (o08 === {61'b0, 3'bzzz});
        assert (o09 === {64 {1'b0}});
        assert (o10 === {64 {1'b1}});
        assert (o11 === {64 {1'bx}});
        assert (o12 === {64 {1'bz}});
        assert (l01 === {64 {1'b0}});
        assert (l02 === {64 {1'b1}});
        assert (l03 === {64 {1'bx}});
        assert (l04 === {64 {1'bz}});
        assert (o13 === {64 {1'b0}});
        assert (o14 === {64 {1'b1}});
        assert (o15 === {64 {1'bx}});
        assert (o16 === {64 {1'bz}});
    end
`endif
endmodule
