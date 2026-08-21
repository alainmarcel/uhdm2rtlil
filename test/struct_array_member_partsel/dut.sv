// A trailing bit range on an ARRAY ELEMENT of a struct member:
//     hpdcache_rsp_i.rdata[0][32 +: 32]
// (CVA6 cva6_hpdcache_if_adapter's AMO response forwarding).
//
// The range was left inside the member NAME, so the member resolver returned
// the element's FULL width and the range was dropped — the resulting chunk ran
// past the end of the struct wire and aborted yosys outright:
//     Assert `chunk_.offset + chunk_.width <= chunk_.wire->width' failed
package pk;
  typedef struct packed {
    logic [1:0]        tag;
    logic [1:0][63:0]  rdata;    // array member, 64-bit elements
    logic              err;
  } rsp_t;
endpackage

module dut (
    input  pk::rsp_t   rsp_i,
    output logic [31:0] hi_o,
    output logic [31:0] lo_o,
    output logic [63:0] whole_o,
    output logic [31:0] elem1_hi_o
);
  assign hi_o       = rsp_i.rdata[0][32 +: 32];   // upper half of element 0
  assign lo_o       = rsp_i.rdata[0][0  +: 32];   // lower half of element 0
  assign whole_o    = rsp_i.rdata[0];             // whole element (control)
  assign elem1_hi_o = rsp_i.rdata[1][32 +: 32];   // upper half of element 1
endmodule
