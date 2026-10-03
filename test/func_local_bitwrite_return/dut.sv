// A function LOCAL assembled by constant BIT-SELECT writes and then returned.
// VeeR's one-hot encoder, verbatim in shape:
//
//   function automatic logic [2:0] f_Enc8to3;  input logic [7:0] Dec_value;
//     logic [2:0] Enc_value;
//     Enc_value[0] = Dec_value[1] | Dec_value[3] | Dec_value[5] | Dec_value[7];
//     Enc_value[1] = ...;  Enc_value[2] = ...;
//     return Enc_value[2:0];
//
// A declared local that is never assigned WHOLE was not in the inlined
// function's name map, so the bit-select-LHS branch fell through to the
// generic path, which resolved the bare name against the MODULE and fabricated
// a 1-bit wire `\e` for it: every `e[k] = ...` wrote that stray wire, the
// function's own local stayed at x, and the return was a constant 0.
// css_mcu0_el2_lsu_bus_buffer's CmdPtr0 was permanently 0 -- every bus command
// picked buffer slot 0 -- and it diverged from the RTL on 164 of 301 co-sim
// cycles while the bounded miter still passed (a second CMD entry takes more
// cycles to reach than it explores).
module dut (
  input  logic [3:0] d,
  output logic [1:0] o_sel,     // return of a PART-SELECT of the local
  output logic [2:0] o_whole,   // return of the WHOLE local
  output logic [2:0] o_nocast   // argument built by concatenation, no size cast
);
  function automatic logic [2:0] enc_sel;
    input logic [7:0] v;
    logic [2:0] e;
    e[0] = v[1] | v[3] | v[5] | v[7];
    e[1] = v[2] | v[3] | v[6] | v[7];
    e[2] = v[4] | v[5] | v[6] | v[7];
    return e[2:0];
  endfunction
  function automatic logic [2:0] enc_whole;
    input logic [7:0] v;
    logic [2:0] e;
    e[0] = v[1] | v[3] | v[5] | v[7];
    e[1] = v[2] | v[3] | v[6] | v[7];
    e[2] = v[4] | v[5] | v[6] | v[7];
    return e;
  endfunction
  assign o_sel    = enc_sel(8'(d));
  assign o_whole  = enc_whole(8'(d));
  assign o_nocast = enc_sel({4'b0, d});
endmodule
