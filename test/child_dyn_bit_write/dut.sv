// A dynamic bit write to a packed vector inside a process, in a module that
// is instantiated as a CHILD.
//
// A module body is imported from the AllModules DEFINITION when the module is
// a child, and there the select carries NO Actual_group while the definition's
// own net/variable for the base carries no range either.  Every geometry probe
// in emit_dynamic_packed_select_write therefore had nothing to measure, the
// handler declined, and the write fell through to the generic LHS import's
// READ path: it was assigned to the $shiftx aux, so the next-state temp never
// saw it.  The register then self-looped from its reset value and `opt` folded
// it to a constant -- the write was simply gone.
//
// The same module read as its own TOP was correct, which is what hid this:
// scr1_ipic passes standalone while its IER / IMR / IINVR / ISVR registers are
// all dead inside every scr1 top, and scr1_pipe_top hard-errored in
// opt_muxtree because the five struct-field $shiftx reads of those dead
// registers optimised into one cell driving several bits of the struct.
module leaf (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wr_req,
    input  logic [3:0]  idx,
    input  logic        d,
    input  logic [1:0]  widx,
    input  logic [3:0]  wd,
    output logic [15:0] q,
    output logic [15:0] qw
);
  // one-bit elements: the plain packed vector
  logic [15:0] ier_ff, ier_next;
  // the same shape through an indexed part-select, so the write's offset
  // arithmetic is exercised and not just the single-bit case
  logic [15:0] mode_ff, mode_next;

  always_comb begin
    ier_next = ier_ff;
    if (wr_req) ier_next[idx] = d;
  end

  always_comb begin
    mode_next = mode_ff;
    if (wr_req) mode_next[widx*4 +: 4] = wd;
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      ier_ff  <= '0;
      mode_ff <= '0;
    end else if (wr_req) begin
      ier_ff  <= ier_next;
      mode_ff <= mode_next;
    end
  end

  assign q  = ier_ff;
  assign qw = mode_ff;
endmodule

module dut (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wr_req,
    input  logic [3:0]  idx,
    input  logic        d,
    input  logic [1:0]  widx,
    input  logic [3:0]  wd,
    output logic [15:0] q,
    output logic [15:0] qw
);
  leaf u_leaf (.clk(clk), .rst_n(rst_n), .wr_req(wr_req), .idx(idx), .d(d),
               .widx(widx), .wd(wd), .q(q), .qw(qw));
endmodule
