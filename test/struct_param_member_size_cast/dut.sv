// A size cast whose size is a MEMBER of a packed-struct parameter, written
// inside a generate block -- VeeR EL2 ifu_bp_ctl's
//   assign wr0 = pt.BHT_ARRAY_DEPTH'(bht_wr_en0[i] << bht_wr_addr0);
// under `for (genvar i...) begin : BANKS`.  Surelog compiled the casting type
// as a TYPE: inside the generate scope `pt` was not visible at all
// (unsupported_typespec), and on the elaborated instance the member's own
// 15-bit logic type came back instead of its value 256 -- so the 256-bit
// write enable was cast to 15 bits (caliptra: BHT entries >= 15 never
// written; caliptra-ss: a 539033795-bit wire that bad_alloc'd proc).
// Fixed in Surelog (CompileExpression dotted-cast trigger); the miter
// against read_slang is the gate.
package pk;
  typedef struct packed { logic [14:0] DEPTH; logic [7:0] ADDR_HI; } cfg_t;
  localparam cfg_t CFG = '{DEPTH: 15'd256, ADDR_HI: 8'd9};
endpackage
module dut import pk::*; #(parameter cfg_t pt = CFG) (
  input  logic [1:0] en,
  input  logic [7:0] addr,
  output logic [511:0] wr
);
  for (genvar i = 0; i < 2; i++) begin : BANKS
    wire [255:0] wr0;
    assign wr0 = pt.DEPTH'(en[i] << addr);
    assign wr[i*256 +: 256] = wr0;
  end
endmodule
module top import pk::*; (input logic [1:0] en, input logic [7:0] addr, output logic [511:0] wr);
  dut #(.pt(CFG)) u (.en(en), .addr(addr), .wr(wr));
endmodule
