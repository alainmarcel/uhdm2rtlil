// A function that stages its result in nothing but assigns package ENUM
// constants to its own name (`f = RA_S0`), called from a continuous assign --
// cv32e40x_pkg::pushpop_reg_length, the register-list decoder of the
// push/pop sequencer.  The inliner collected every name on the right of
// `f = <name>` as a "return variable" to alias onto the result wire, skipping
// parameters and formals but not enum constants: `f = RA_S0` became
// `result = result` and the result had no driver (cv32e40x / cv32e40s
// sequencer: decode.registers_saved read 0, formal `differs`, co-sim PASS).
package p;
  typedef enum logic [3:0] { R_NONE = 4'd0, RA_S0 = 4'd1, RA_S0_S1 = 4'd2 } rl_e;
  function automatic rl_e f(logic [3:0] a);
    case (a)
      4'd5: f = RA_S0;
      4'd6: f = RA_S0_S1;
      default: f = R_NONE;
    endcase
  endfunction
endpackage
module dut import p::*; (input logic [3:0] r_i, output rl_e y_o);
  assign y_o = f(r_i);
endmodule
