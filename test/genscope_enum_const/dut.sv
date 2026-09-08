// A gen-scope-local `typedef enum` whose CONSTANTS are used as RHS values
// (`st_d = MULL`).  Before the enum-const-map fix the bare ref to MULL had no
// Actual_group, so it fabricated an undriven wire (`Reference to unknown
// signal: MULL`) — the ibex_multdiv_fast gen_mult_single_cycle
// `typedef enum {MULL,MULH}` gap the whole-core `check` flagged.
module genscope_enum_const(input logic clk, input logic sel, output logic o);
  if (1) begin : g
    typedef enum logic { MULL, MULH } fsm_e;
    fsm_e st_q, st_d;
    always_comb begin
      st_d = MULL;
      if (sel) st_d = MULH;
    end
    always_ff @(posedge clk) st_q <= st_d;
    assign o = (st_q == MULL);
  end
endmodule
