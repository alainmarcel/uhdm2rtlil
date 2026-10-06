// Compilation-unit ($unit) parameters: declarations outside any package or
// module, the way scr1's src/includes/*.svh writes every width.  Surelog hangs
// them off the DESIGN and a reference to one is a bare ref_obj with no
// vpiActual, so read_uhdm resolved none of them:
//   * a bare name became a fabricated 1-bit wire, so a 22-bit slice of
//     RST_VAL read ONE X bit;
//   * a parameter whose own value Surelog left unfolded returned an EMPTY
//     value that callers read as a constant 0, so MTRIG_NUM came out 0 and
//     $clog2(ALL_NUM+1) collapsed a size cast to zero width;
//   * read_uhdm then SEGFAULTED on scr1_pipe_top, scr1_core_top,
//     scr1_top_ahb and scr1_top_axi.
// Every value here is checked against read_slang by test_slang_equiv.ys.
parameter int unsigned TRIG_NUM  = 2;
parameter int unsigned MTRIG_NUM = TRIG_NUM;            // bare reference
parameter int unsigned ALL_NUM   = MTRIG_NUM + 1'b1;    // an operation over one
parameter int unsigned ALL_W     = $clog2(ALL_NUM + 1); // a system call over that
parameter int unsigned ZERO_BITS = 6;
parameter int unsigned WR_BITS   = 4;
parameter int unsigned RO_BITS   = (32 - (ZERO_BITS + WR_BITS));
// declared over a NON-zero-based range: a select writes bit NUMBERS
parameter bit [31:ZERO_BITS] RST_VAL = 26'h0123456;

module dut (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  upd,
    input  logic [31:0]           wd,
    output logic [31:ZERO_BITS]   y,
    output logic [ALL_W-1:0]      sel,
    output logic [7:0]            n_mtrig,
    output logic [7:0]            n_all
);
  logic [31:(32-WR_BITS)] base_reg;

  if (WR_BITS == 0) begin : ro_only
    assign y = RST_VAL;
  end else begin : base_ro_rw
    always_ff @(negedge rst_n, posedge clk)
      if (!rst_n) base_reg <= RST_VAL[31 -: WR_BITS];
      else if (upd) base_reg <= wd[31 -: WR_BITS];
    // the slice that read one X bit: bit NUMBERS 6 .. 6+RO_BITS-1
    assign y = {base_reg, RST_VAL[ZERO_BITS +: RO_BITS]};
  end

  // a size cast whose width comes from a $unit parameter, next to a compare
  // against a slice of the same width -- zero width if ALL_W folded to 0
  assign sel     = (wd[ALL_W-1:0] < ALL_W'(ALL_NUM)) ? ALL_W'(ALL_NUM) : '0;
  assign n_mtrig = MTRIG_NUM;
  assign n_all   = ALL_NUM;
endmodule
