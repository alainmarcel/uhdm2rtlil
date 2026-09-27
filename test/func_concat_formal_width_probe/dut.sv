// A package function whose return value is an XOR of CONCATENATIONS of
// selects of its formal -- caliptra's sha512_masked_defines_pkg::ROT1 /
// ROT14 -- called on struct members from an always_comb.
//
// While the enclosing XOR resolves its context width it sizes each operand
// with self_determined_width; the concat case walked its operands WITHOUT
// the function-argument mapping, so the leaf bit-select probe of `x` found
// no wire named x and hard-errored ("Could not find wire 'x' for bit
// select").  The whole caliptra_top read died on it (nightly caliptra sweep
// of 2026-09-27: 0/0 instances, "elaboration failed").  Reading this file
// is the test: before the fix read_uhdm errors out.
package rot_pkg;
  typedef struct packed { logic [63:0] masked; logic [63:0] random; } mw_t;
  function automatic reg [63:0] ROT1 (input reg [63:0] x);
    return {x[0],       x[63 : 1]} ^   // ROTR1
           {x[7 : 0],   x[63 : 8]} ^   // ROTR8
           {7'b0000000, x[63 : 7]};    // SHR7
  endfunction
  function automatic reg [63:0] ROT14 (input reg [63:0] x);
    return {x[18 : 0], x[63 : 19]} ^
           {x[60 : 0], x[63 : 61]} ^
           {6'b000000, x[63 : 6]};
  endfunction
endpackage
module func_concat_formal_width_probe import rot_pkg::*; (
  input  logic [127:0] a,
  input  logic [127:0] b,
  output logic [127:0] d0,
  output logic [127:0] d1
);
  mw_t w_1, w_14;
  always_comb begin
    w_1  = a;
    w_14 = b;
    d0 = {ROT1(w_1.masked),   ROT1(w_1.random)};
    d1 = {ROT14(w_14.masked), ROT14(w_14.random)};
  end
endmodule
