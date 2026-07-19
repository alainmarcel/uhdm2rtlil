// A `logic` parameter defaulting to 'x (a don't-care) arrives from UHDM as
// VpiValue "BIN:X".  The $paramod cell-type encoder used std::stoi, which
// throws on "X" — the old code logged a spurious "Failed to convert parameter
// value 'X'" warning and fell back to encoding the value as 0.  The value is
// now encoded preserving the x bit.  Two children (one overriding the param to
// a real value, one keeping the 'x default) exercise both paths.
module child #(parameter logic [3:0] ILL = 4'bxxxx) (
  input  logic [3:0] a,
  input  logic       sel,
  output logic [3:0] o
);
  assign o = sel ? a : ILL;
endmodule

module param_x_default (
  input  logic [3:0] a,
  input  logic       sel,
  output logic [3:0] o_def,   // ILL stays 'x (don't-care)
  output logic [3:0] o_set    // ILL overridden to 4'hA
);
  child           u_def (.a(a), .sel(sel), .o(o_def));
  child #(4'hA)   u_set (.a(a), .sel(sel), .o(o_set));
endmodule
