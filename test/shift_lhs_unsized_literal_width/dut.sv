// The shifted value of `(out_size+1)>>1` into a 3-bit target: the sum is
// context-determined, and the context is the widest of the target and the
// operands -- 32 bits for the unsized `1` -- so 7+1 = 8 does NOT wrap before
// the shift (LRM 11.8.2): the result is 4.  Imported under the target width
// alone it wrapped to 0 first: NVDLA's read-ingress `slot_needed` said 0 slots
// for a 7-beat request (NV_NVDLA_CVIF_READ_IG_bpt, NV_NVDLA_MCIF_READ_IG_bpt).
// read_verilog and read_slang both give 4.
module dut (input wire [2:0] out_size, input wire sel, output reg [2:0] slot_needed, output reg [2:0] s2);
  always @(*) begin
    if (sel) slot_needed = (out_size+1)>>1;
    else     slot_needed = (out_size>>1) + 1;
  end
  always @(*) s2 = ((out_size+out_size)>>1) + 1;
endmodule
