// A POSITIONAL type-parameter override `inner #(logic [31:0]) i1 (...)` must
// bind T exactly as the named `inner #(.T(logic [31:0])) i2 (...)` does.
// Surelog never bound the positional form (chipsalliance/Surelog #4247), so
// the instance kept the default `logic` and its 32-bit ports were resized to
// 1 bit: common_cells test wrappers written `cdc_2phase #(logic [31:0]) i_cdc (.*)`
// truncated every word crossing the CDC (core-v-mcu cdc_2phase_synth, synth_bench).
// read_verilog cannot parse `parameter type`, so the gates are the read_slang
// miter and a structural width check.
module inner #(parameter type T = logic) (input T d, output T q, output logic [7:0] w);
  assign q = d;
  assign w = $bits(T);
endmodule
module dut(input logic [31:0] d, output logic [31:0] q1, output logic [7:0] w1, output logic [31:0] q2, output logic [7:0] w2);
  inner #(logic [31:0]) i1 (.d(d), .q(q1), .w(w1));      // POSITIONAL type parameter
  inner #(.T(logic [31:0])) i2 (.d(d), .q(q2), .w(w2));  // named, the control
endmodule
