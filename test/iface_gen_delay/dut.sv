// Minimal repro for interface generate-scope import.
//
// The interface builds a delay line inside a `generate for` block: each stage
// declares local regs, drives the interface array element `dly[i]` via a
// continuous assign, and clocks it through an always_ff.  The frontend must
// descend into the interface's Gen_scope_arrays to import those nets, cont
// assigns and processes — otherwise `dly[1]` is undriven and `dout` is X.
//
// Mirrors the jeras/rp32 tcb_lite_if handshake/request delay line.

interface delay_if #(parameter int DLY = 2) (input logic clk, input logic rst);
    logic din;
    logic dly [0:DLY];

    assign dly[0] = din;

    generate
        for (genvar i = 1; i <= DLY; i++) begin : dstage
            logic tmp;
            assign dly[i] = tmp;
            always_ff @(posedge clk or posedge rst)
                if (rst) tmp <= 1'b0;
                else     tmp <= dly[i-1];
        end
    endgenerate
endinterface

module top (
    input  logic clk,
    input  logic rst,
    input  logic din,
    output logic dout
);
    delay_if #(.DLY(2)) intf (.clk(clk), .rst(rst));
    assign intf.din = din;
    assign dout = intf.dly[2];   // reads the last delay stage
endmodule
