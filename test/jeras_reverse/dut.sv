module test_reverse #(
  int unsigned XLEN = 32
)(
  // data input/output
  input  logic [XLEN-1:0] dti,
  output logic [XLEN-1:0] dto
);

// reverse bit order
function automatic logic [XLEN-1:0] bitrev (logic [XLEN-1:0] val);
`ifdef LANGUAGE_UNSUPPORTED_STREAM_OPERATOR
  for (int unsigned i=0; i<XLEN; i++)  bitrev[i] = val[XLEN-1-i];
`else
  bitrev = {<<{val}};
`endif
endfunction: bitrev

assign dto = bitrev(dti);

endmodule: test_reverse

