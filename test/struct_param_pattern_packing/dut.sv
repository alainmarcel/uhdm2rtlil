// A struct PARAMETER initialised by a named-field assignment pattern.
// Surelog strips the field tags on an ELABORATED parameter and emits BARE
// exprs in declaration order, so the named-field sizing path never ran and
// every field was sized to context/count -- 96/2 = 48 bits apiece for this
// {int unsigned, logic[63:0]} pair, packing {48'd3, 48'h1000} instead of
// {32'd3, 64'h1000}.  Every field then read at the wrong offset.
package p;
  typedef struct packed {
    int unsigned n;          // 32 bits
    logic [63:0] base;       // 64 bits  -- deliberately UNEQUAL widths
  } cfg_t;
  typedef struct packed {
    logic [7:0]  a;
    logic [15:0] b;
    logic        c;
  } three_t;                 // 3 members, 25 bits, none equal

  localparam cfg_t   LIT  = '{n: 3, base: 64'h1000};
  localparam three_t LIT3 = '{a: 8'hA5, b: 16'hBEEF, c: 1'b1};

  function automatic logic in_region(cfg_t C, logic [63:0] a);
    if (C.n != 0) return (a >= C.base);
    else          return 1'b1;
  endfunction
endpackage

module dut #(
    parameter p::cfg_t   CFG  = p::LIT,
    parameter p::three_t CFG3 = p::LIT3
) (
    input  logic [63:0] a_i,
    output logic        o_fn,      // struct param through a FUNCTION ARGUMENT
    output logic [31:0] o_n,       // direct field reads
    output logic [63:0] o_base,
    output logic [7:0]  o_a,
    output logic [15:0] o_b,
    output logic        o_c
);
  assign o_fn   = p::in_region(CFG, a_i);
  assign o_n    = CFG.n;
  assign o_base = CFG.base;
  assign o_a    = CFG3.a;
  assign o_b    = CFG3.b;
  assign o_c    = CFG3.c;
endmodule
