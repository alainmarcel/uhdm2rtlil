// Converted from chipsalliance/sv-tests (define-directive).
// Upstream runs a whole define/undef/ifdef/elsif/undefineall chain and then declares an EMPTY module, so none of the chain's effects are ever read back.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`define XXX 1
`ifdef XXX
`undef XXX
`elsif YYY
`define XXX 0
`endif
`ifndef YYY
`define YYY 0
`else
`define XXX 0
`endif
`undefineall
module d(input logic [7:0] a, input logic [7:0] b, output logic [8:0] o,
         output logic [1:0] state);
  // The chain is kept verbatim.  By the end of it `undefineall has cleared BOTH
  // names, whatever the chain did on the way, and `ifdef reads that back: a chain
  // that left either name defined compiles a different arm and a different code.
`ifdef XXX
  assign state = 2'd1;
`elsif YYY
  assign state = 2'd2;
`else
  assign state = 2'd3;
`endif
  assign o = a + b;
endmodule
