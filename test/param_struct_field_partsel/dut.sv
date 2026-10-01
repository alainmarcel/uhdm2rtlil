// A SELECT on a struct-parameter field is part of the path, and dropping it
// returns the whole field at its declared width.
//
// `{Xs, P.BIAS[P.NE-1:0], {P.NF{1'b0}}}` -- CORE-V Wally's fround, rounding to
// +/- 1 -- then put a 64-bit `1023` in the middle of a 64-bit concatenation, so
// the result was `1023 << 52` and the SIGN fell off the top: every round-to-one
// came out POSITIVE.  `FRound` read 0x3c00 where the RTL says 0xbc00, and the
// formal miter against read_slang caught it too.
package cfg;
  typedef struct packed {
    int          NE;    // exponent bits
    int          NF;    // fraction bits
    logic [63:0] BIAS;  // exponent bias, declared 64 bits wide
  } cfg_t;
endpackage

module leaf import cfg::*; #(parameter cfg_t P) (
  input  logic        s,
  input  logic        up,
  output logic [63:0] w,
  output logic [10:0] e,
  output logic        b0
);
  always_comb begin
    if (up) w = {s, P.BIAS[P.NE-1:0], {P.NF{1'b0}}};   // part-select on the field
    else    w = {s, {(64-1){1'b0}}};
  end
  assign e  = P.BIAS[P.NE-1:0];                        // the select on its own
  assign b0 = P.BIAS[0];                               // a bit-select
endmodule

module dut (
  input  logic        s,
  input  logic        up,
  output logic [63:0] w,
  output logic [10:0] e,
  output logic        b0
);
  localparam int          NE   = 11;
  localparam int          NF   = 52;
  localparam logic [63:0] BIAS = 64'd1023;
  localparam cfg::cfg_t   P    = '{NE: NE, NF: NF, BIAS: BIAS};
  leaf #(P) u (.s(s), .up(up), .w(w), .e(e), .b0(b0));
endmodule
