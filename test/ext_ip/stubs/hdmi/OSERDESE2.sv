// Behavioural stand-in for Xilinx's OSERDESE2 output serializer, for the hdmi
// family (hdl-util/hdmi serializer.sv instantiates it unconditionally).  No
// frontend and no simulator can build that module without a model of the
// primitive, so without this file the row measured nothing about any tool.
//
// NOT the primitive: a single-clock, SDR approximation.  The parallel word
// (D1..D8, then SHIFTIN1/SHIFTIN2 for the two extra bits of a 10-bit
// MASTER/SLAVE pair) is loaded on the rising edge of CLKDIV and shifted out
// on OQ one bit per CLK, D1 first; the slave passes its D3/D4 up as
// SHIFTOUT1/SHIFTOUT2 as the real pair does.  Both sides of every comparison
// (RTL simulation, read_uhdm, read_slang) see this same model.
module OSERDESE2 #(
    parameter DATA_RATE_OQ = "DDR",
    parameter DATA_RATE_TQ = "SDR",
    parameter integer DATA_WIDTH = 4,
    parameter INIT_OQ = 1'b0,
    parameter INIT_TQ = 1'b0,
    parameter SERDES_MODE = "MASTER",
    parameter SRVAL_OQ = 1'b0,
    parameter SRVAL_TQ = 1'b0,
    parameter TBYTE_CTL = "FALSE",
    parameter TBYTE_SRC = "FALSE",
    parameter integer TRISTATE_WIDTH = 4
) (
    output OFB,
    output OQ,
    output SHIFTOUT1,
    output SHIFTOUT2,
    output TBYTEOUT,
    output TFB,
    output TQ,
    input  CLK,
    input  CLKDIV,
    input  D1, D2, D3, D4, D5, D6, D7, D8,
    input  OCE,
    input  RST,
    input  SHIFTIN1,
    input  SHIFTIN2,
    input  T1, T2, T3, T4,
    input  TBYTEIN,
    input  TCE
);
  reg [9:0] sr = 10'b0;
  reg clkdiv_q = 1'b0;
  always @(posedge CLK) begin
    clkdiv_q <= CLKDIV;
    if (RST)
      sr <= 10'b0;
    else if (CLKDIV && !clkdiv_q)
      sr <= {SHIFTIN2, SHIFTIN1, D8, D7, D6, D5, D4, D3, D2, D1};
    else if (OCE)
      sr <= {1'b0, sr[9:1]};
  end
  assign OQ        = sr[0];
  assign OFB       = sr[0];
  assign SHIFTOUT1 = D3;
  assign SHIFTOUT2 = D4;
  assign TQ        = T1;
  assign TFB       = T1;
  assign TBYTEOUT  = TBYTEIN;
endmodule
