// `$clog2` inside a function that OUR compile-time evaluator has to run.
// Surelog folds most constant function calls itself, but not one whose
// argument is a parameter overridden with `$bits(t)` (it cannot evaluate
// that actual); the evaluator's system-function operand knew only `$signed`
// / `$unsigned`, so `$clog2` produced an empty constant and common_cells
// cc_pkg::idx_width returned 0 (cc_id_queue's index widths collapsed).
// `w_direct` is the same function on a plain constant, folded by Surelog
// and already right.  Relies on the override-scope fix for `$bits(t)`.
package p;
  function automatic int unsigned idx_width (input int unsigned num_idx);
    if (num_idx > 32'd1) begin
      return unsigned'($clog2(num_idx));
    end else begin
      return 32'd1;
    end
  endfunction
endpackage

module func_clog2_const_eval (
  input  logic [7:0] a,
  output logic [7:0] w_ovr,
  output logic [7:0] w_direct
);
  mid #(.t(logic [7:0])) u (.a(a), .w_ovr(w_ovr), .w_direct(w_direct));
endmodule

module mid #(
  parameter type t = logic
) (
  input  logic [7:0] a,
  output logic [7:0] w_ovr,
  output logic [7:0] w_direct
);
  leaf #(.N($bits(t))) i_leaf (.a(a), .w_ovr(w_ovr), .w_direct(w_direct));
endmodule

module leaf #(
  parameter int unsigned N = 1
) (
  input  logic [7:0] a,
  output logic [7:0] w_ovr,
  output logic [7:0] w_direct
);
  localparam int unsigned W_OVR    = p::idx_width(N);   // 8 -> 3, via our evaluator
  localparam int unsigned W_DIRECT = p::idx_width(8);   // folded by Surelog
  assign w_ovr    = W_OVR + a;
  assign w_direct = W_DIRECT + a;
endmodule
