// An if-condition inside an inlined function is SELF-DETERMINED (LRM 11.6.1):
// `if (~found)` tests the 1-bit local, whatever width the caller's assignment
// context has.  read_uhdm inlined the body while the CALL SITE's context width
// (3 here, from `assign ptr0 = ...`) was still active, built `~{2'b00, found}`
// = 3'b111 and matched the arm against exactly 3'b001 -- the arm never ran and
// the function folded to a constant 0.  VeeR EL2 css_mcu0_axi4_to_ahb's
// get_nxtbyte_ptr (caliptra-ss, differs + ahb_haddr bit 0 wrong).
module dut (
  input  logic [2:0] cur,
  input  logic [7:0] byteen,
  input  logic       get_next,
  output logic [2:0] ptr0,
  output logic [2:0] ptr1,
  output logic [7:0] wide,
  output logic       one
);
   function automatic logic [2:0] get_nxtbyte_ptr (logic [2:0] current_byte_ptr, logic [7:0] byteen, logic get_next);
      logic [2:0] start_ptr;
      logic       found;
      found = '0;
      get_nxtbyte_ptr[2:0] = 3'd0;
      start_ptr[2:0] = get_next ? (current_byte_ptr[2:0] + 3'b1) : current_byte_ptr[2:0];
      for (int j=0; j<8; j++) begin
         if (~found) begin
            get_nxtbyte_ptr[2:0] = 3'(j);
            found |= (byteen[j] & (3'(j) >= start_ptr[2:0])) ;
         end
      end
   endfunction

   // A 1-bit local negated in the condition, at an 8-bit and a 1-bit call
   // site; the else arm must run when the bit is set.
   function automatic logic [7:0] pick (input logic [7:0] b);
      logic sel;
      sel = b[0];
      if (~sel) pick = {b[7:1], 1'b1};
      else      pick = 8'h5a;
   endfunction

   assign ptr0 = get_nxtbyte_ptr(3'b0, byteen, 1'b0);
   assign ptr1 = get_nxtbyte_ptr(cur, byteen, get_next);
   assign wide = pick(byteen);
   assign one  = pick(byteen) == 8'h5a;
endmodule
