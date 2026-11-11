// A function LOCAL written through a DYNAMIC indexed part-select
// (`be[offset +: 2] = '1`): CVA6 wt_dcache_wbuffer's to_byte_enable8, whose
// half-word and word arms select the byte-enable slice at the store's offset.
// The write was dropped and the local kept its '0 initializer, so the write
// buffer never transferred a dirty half-word or word to the cache.
module dut (input logic [2:0] offset, input logic [1:0] size,
            output logic [7:0] be_o, output logic [7:0] fill_o, output logic [7:0] cmp_o, output logic [7:0] down_o);
  function automatic logic [7:0] to_byte_enable8(input logic [2:0] offset, input logic [1:0] size);
    logic [7:0] be;
    be = '0;
    unique case (size)
      2'b00:   be[offset] = '1;      // byte
      2'b01:   be[offset+:2] = '1;   // hword
      2'b10:   be[offset+:4] = '1;   // word
      default: be = '1;              // dword
    endcase
    return be;
  endfunction
  function automatic logic [7:0] f_fill(input logic [2:0] offset);
    logic [7:0] be;
    be = '0;
    be[offset+:2] = 2'b11;
    return be;
  endfunction
  function automatic logic [7:0] f_cmp(input logic [2:0] offset);
    logic [7:0] be;
    be = 8'h0f;
    be[offset+:2] ^= 2'b11;         // compound operator on the slice
    return be;
  endfunction
  function automatic logic [7:0] f_down(input logic [2:0] offset);
    logic [7:0] be;
    be = '0;
    be[offset-:2] = 2'b11;          // [base -: width]
    return be;
  endfunction
  assign be_o   = to_byte_enable8(offset, size);
  assign fill_o = f_fill(offset);
  assign cmp_o  = f_cmp(offset);
  // offset 0 would select [0:-1]: an out-of-range write the LRM leaves
  // undefined and the simulators disagree on (Verilator wraps the 3-bit
  // index to bit 7, read_slang keeps the in-range bit) -- not asserted.
  assign down_o = (offset != 3'd0) ? f_down(offset) : 8'h00;
endmodule
