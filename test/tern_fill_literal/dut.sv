// CVA6 cva6_ptw repro (adjudicated with iverilog, not just the miter):
// an UNBASED UNSIZED fill literal (`'1`) as a ternary branch must REPLICATE
// to the context width.  Two separate bugs made `assign wide = cond ? f(x)
// : '1;` produce 1 (or the narrow branch's width) instead of all-ones:
//   1. SURELOG ExprEval::reduceExpr's vpiConditionOp fold pushed the picked
//      branch through get_value(), turning `'1` into INT:1 — so with a
//      CONSTANT condition the fill identity was destroyed before import.
//   2. The importer's own ternary path zero-extended the 1-bit fill instead
//      of replicating it to the (context-determined, LRM 11.4.11) width.
// In cva6_ptw: `req_port_o.data_be = CVA6Cfg.IS_XLEN32 ? be_gen_32(…) : '1;`
// yielded data_be = 8'h01 instead of 8'hff.
function automatic logic [3:0] narrow(logic [1:0] a);
  narrow = {2'b0, a};
endfunction

module tern_fill_literal #(
  parameter bit IS32 = 1'b0
)(
  input  logic       sel,
  input  logic [1:0] a,
  output logic [7:0] o_constcond,  // constant condition (the Surelog half)
  output logic [7:0] o_dyncond,    // dynamic condition (the importer half)
  output logic [7:0] o_fill_true,  // fill in the TRUE branch
  output logic [7:0] o_zero_fill   // '0 fill
);
  assign o_constcond = IS32 ? narrow(a) : '1;
  assign o_dyncond   = sel  ? narrow(a) : '1;
  assign o_fill_true = sel  ? '1 : 8'h5a;
  assign o_zero_fill = sel  ? narrow(a) : '0;
endmodule
