// A part-select bound taken from an ELEMENT of an UNPACKED-ARRAY parameter.
//
// `Widths[k]` must select the k-th ELEMENT of the array (8 and 4 here), not
// bit k of the parameter's folded packed value -- which is what UHDM's
// ExprEval does, because the folded constant has lost the unpacked dimension.
// Bit 0 of 8 is 0, so every bound folded to the degenerate `[-1:0]` and
// SigSpec::extract ABORTED the whole read (`Assert 'offset >= 0' failed`) --
// lowRISC Sonata's gpio, whose GPIO instances are sized by
//     parameter int unsigned GpiInstWidths[NumInstances] = {8}
//     .gp_i(gp_i[inst_idx][GpiInstWidths[inst_idx]-1:0])
//
// The CONCATENATION initializer is load-bearing: written `'{8, 4}` the
// parameter keeps enough annotation that ExprEval resolves the element
// correctly, and this test passes WITHOUT the fix.
module dut #(parameter int unsigned N = 2,
             parameter int unsigned Widths[N] = {8, 4})
  (input  logic [N-1:0][15:0] bus,
   output logic [N-1:0]       o);
  for (genvar k = 0; k < N; k++) begin : g
    assign o[k] = |bus[k][Widths[k]-1:0];
  end
endmodule
