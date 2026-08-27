// An UNCONDITIONAL write that comes after a CONDITIONAL one to the same signal
// must win.  RTLIL runs a case's actions before its switches, which inverts
// that order, so the unconditional write has to supersede the earlier
// conditional one.
// CVA6 issue_read_operands.sv: the loop sets `stall_raw[i] = 1'b1` on a RAW
// hazard, then the trailing
//   stall_raw[0] = x_transaction_rejected ? 1'b0 : stall_rs1[0] || ...
// recomputes it — losing that made the issue port stall spuriously.
module dut (
    input  logic       cond,
    input  logic       dflt,
    input  logic       final_a,
    input  logic       final_b,
    input  logic       sel,
    output logic       y_o,
    output logic [3:0] loop_o
);
  logic y;
  always_comb begin
    y = dflt;
    if (cond) y = 1'b1;      // conditional
    y = sel ? final_a : final_b;   // unconditional, LAST — must win
  end
  assign y_o = y;

  //  Same shape with the conditional write inside a loop, as CVA6 has it.
  logic [3:0] v;
  always_comb begin
    for (int unsigned i = 0; i < 4; i++) begin
      v[i] = dflt;
      if (cond) v[i] = 1'b1;
    end
    v[0] = sel ? final_a : final_b;
  end
  assign loop_o = v;
endmodule
