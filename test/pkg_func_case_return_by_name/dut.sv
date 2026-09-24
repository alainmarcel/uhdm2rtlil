// A PACKAGE function whose implicit return variable is assigned BY NAME inside
// a `case`, called from always_comb with a RUNTIME signal (so it has to be
// inlined as logic, not const-folded).
//
// The call spells the function `kp::compute_max_digest`, but every assignment
// in the body is a plain `compute_max_digest = ...` ref.  The combinational
// inliner keyed its result on the CALL's name, so the body's writes landed
// under a different key and the whole call collapsed to a constant X
// (`connect \max_o 3'x`), which `setundef -zero` then turned into 0.
//
// Pavona acc_alu_bignum hit this through kmac_pkg::compute_max_digest:
// max_digest_words read 5 in RTL and 0 in the read_uhdm netlist from cycle 0.
package sp;
  typedef enum logic [2:0] {
    L128 = 3'b000,
    L224 = 3'b001,
    L256 = 3'b010,
    L384 = 3'b011,
    L512 = 3'b100
  } strength_e;
endpackage

package kp;
  function automatic logic [2:0] compute_max_digest (sp::strength_e keccak_strength_i);
    case (keccak_strength_i)
      sp::L128: compute_max_digest = 3'h5;
      sp::L224: compute_max_digest = 3'h1;
      sp::L256: compute_max_digest = 3'h4;
      sp::L384: compute_max_digest = 3'h2;
      sp::L512: compute_max_digest = 3'h2;
      default:  compute_max_digest = 3'h0;
    endcase
  endfunction

  // Same shape with an if/else chain, to pin the other control-flow arm.
  function automatic logic [2:0] compute_min_digest (sp::strength_e s);
    if (s == sp::L128)      compute_min_digest = 3'h1;
    else if (s == sp::L256) compute_min_digest = 3'h3;
    else                    compute_min_digest = 3'h7;
  endfunction
endpackage

module pkg_func_case_return_by_name (
  input  sp::strength_e strength_i,
  output logic [2:0]    max_o,
  output logic [2:0]    min_o,
  output logic [3:0]    sum_o
);
  always_comb begin
    max_o = kp::compute_max_digest(strength_i);
    min_o = kp::compute_min_digest(strength_i);
    sum_o = {1'b0, kp::compute_max_digest(strength_i)} +
            {1'b0, kp::compute_min_digest(strength_i)};
  end
endmodule
