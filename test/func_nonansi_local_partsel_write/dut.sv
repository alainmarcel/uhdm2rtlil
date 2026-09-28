// A full-range part-select write to a function LOCAL (`size[1:0] = ...`) in a
// function declared with NON-ANSI arguments (`input logic [7:0] byteen;` in
// the body) was dropped: with that header shape Surelog lists `size` on the
// function's Variables() rather than on the begin block, the part-select LHS
// handler found no mapping for it ("out of bounds (base_size=0)"), and the
// function returned 0.  `size = ...` and the ANSI header both worked, which is
// what hid it.  VeeR EL2 css_mcu0_axi4_to_ahb get_write_size / get_write_addr
// (caliptra-ss): every unaligned AXI write was issued as a byte at offset 0.
module dut (
  input  logic [7:0] byteen,
  output logic [1:0] size_o,
  output logic [2:0] addr_o,
  output logic [1:0] size_ansi_o
);
   function automatic logic [1:0] get_write_size;
      input logic [7:0] byteen;
      logic [1:0]       size;
      size[1:0] = (2'b11 & {2{(byteen[7:0] == 8'hff)}}) |
                  (2'b10 & {2{((byteen[7:0] == 8'hf0) | (byteen[7:0] == 8'h0f))}}) |
                  (2'b01 & {2{((byteen[7:0] == 8'hc0) | (byteen[7:0] == 8'h30) | (byteen[7:0] == 8'h0c) | (byteen[7:0] == 8'h03))}});
      return size[1:0];
   endfunction

   function automatic logic [2:0] get_write_addr;
      input logic [7:0] byteen;
      logic [2:0]       addr;
      addr[2:0] = (3'h0 & {3{((byteen[7:0] == 8'hff) | (byteen[7:0] == 8'h0f) | (byteen[7:0] == 8'h03))}}) |
                  (3'h2 & {3{(byteen[7:0] == 8'h0c)}}) |
                  (3'h4 & {3{((byteen[7:0] == 8'hf0) | (byteen[7:0] == 8'h03))}}) |
                  (3'h6 & {3{(byteen[7:0] == 8'hc0)}});
      return addr[2:0];
   endfunction

   // Same body with an ANSI header: must agree with the non-ANSI one.
   function automatic logic [1:0] get_write_size_ansi(input logic [7:0] byteen);
      logic [1:0]       size;
      size[1:0] = (2'b11 & {2{(byteen[7:0] == 8'hff)}}) |
                  (2'b10 & {2{((byteen[7:0] == 8'hf0) | (byteen[7:0] == 8'h0f))}}) |
                  (2'b01 & {2{((byteen[7:0] == 8'hc0) | (byteen[7:0] == 8'h30) | (byteen[7:0] == 8'h0c) | (byteen[7:0] == 8'h03))}});
      return size[1:0];
   endfunction

   assign size_o      = get_write_size(byteen);
   assign addr_o      = get_write_addr(byteen);
   assign size_ansi_o = get_write_size_ansi(byteen);
endmodule
