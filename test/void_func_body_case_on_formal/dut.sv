// A `case` and an `if` at the TOP level of a void function's body, keyed on
// formals and writing an output formal (RSD StoreQueue's GenerateStoreData:
// `case (mode.size) ... dataOut = ...`).  The inliner handed such statements
// to the generic comb path WITHOUT bridging the body's mapping (only `for`
// loops were bridged), so `s`, `dataIn`, `dataOut` resolved to nothing
// ("Reference to unknown signal") and the output never got a value.
module void_func_body_case_on_formal(input logic [31:0] d, input logic [31:0] b, input logic [1:0] sel, input logic flag, output logic [31:0] y);
  function automatic void Gen(output logic [31:0] dataOut, input logic [31:0] dataIn, input logic [31:0] blockDataIn, input logic [1:0] s, input logic f);
    case (s)
      2'd0: dataOut = blockDataIn;
      2'd1: dataOut = dataIn;
      default: dataOut = blockDataIn ^ dataIn;
    endcase
    if (f) dataOut = ~dataOut;
  endfunction
  always_comb Gen(y, d, b, sel, flag);
endmodule
