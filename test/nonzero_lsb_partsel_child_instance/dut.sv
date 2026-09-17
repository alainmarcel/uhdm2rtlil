// A part-select of a vector declared with a NON-ZERO LSB (`input [31:1] pc`)
// inside a CHILD instance.  import_part_select maps `pc[31:13]` through the
// net's declared range, but the elaborated child instance's net carries no
// range (port-vs-net typespec inconsistency), so the raw HDL indexes were
// used against a wire created with start_offset 1: `pc[31:13]` read bits
// [30:13] plus an X bit and `pc[12:1]` read [12:1] — off by one, only in
// non-top instances (the same module as a top elaborates correctly).
//
// VeeR EL2's branch adder (rvbradder, instantiated by the ALU, the decoder
// and the branch predictor) is exactly this module; Caliptra rvtop's
// counterexample was its pc_inc/pc_dec reading the wrong pc bits.
//
// The fix falls back to the RTLIL wire's own start_offset/upto geometry.
module bradder
  (
    input [31:1] pc,
    input [12:1] offset,
    output [31:1] dout
    );
   logic          cout;
   logic          sign;
   logic [31:13]  pc_inc;
   logic [31:13]  pc_dec;
   assign {cout,dout[12:1]} = {1'b0,pc[12:1]} + {1'b0,offset[12:1]};
   assign pc_inc[31:13] = pc[31:13] + 1;
   assign pc_dec[31:13] = pc[31:13] - 1;
   assign sign = offset[12];
   assign dout[31:13] = ({19{  sign ^~  cout}} &     pc[31:13]) |
                        ({19{ ~sign &   cout}}  & pc_inc[31:13]) |
                        ({19{  sign &  ~cout}}  & pc_dec[31:13]);
endmodule

module dut (input [31:1] pc, input [12:1] offset, output [31:1] dout, output [31:1] dout2);
  bradder a (.pc(pc), .offset(offset), .dout(dout));
  bradder b (.pc(pc[31:1]), .offset(offset[12:1]), .dout(dout2[31:1]));
endmodule
