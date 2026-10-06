// A function FORMAL that SHADOWS a module signal of the same name, read
// through a BIT-SELECT.
//
// The bit-select read path searched the MODULE for the base name first and
// consulted the function's own mapping only when nothing was found, so
// `case (haddr[1])` inside a function whose formal is `haddr` switched on the
// module's 32-bit `haddr` instead of the 2-bit formal.  A plain
// `case (haddr)` was already correct -- it does not come through that path --
// which is what made the bug so selective.
//
// This is scr1_dmem_ahb's scr1_conv_ahb2mem_rdata: its 8-bit arm selects on
// the whole formal and read it correctly, while its 16-bit arm selects on
// `haddr[1]` and read the AHB address output instead.  A halfword load
// therefore returned the WRONG HALF of the bus word (dmem_rdata 0x2001 where
// 0x0001 was correct), and nothing warned.
module dut (
    input  logic [1:0]  sel,          // drives the formal
    input  logic [31:0] bus,
    input  logic        pick,         // drives the module-level `haddr`
    output logic [31:0] half,         // via the shadowed bit-select
    output logic [31:0] byte_sel,     // via the whole formal (always worked)
    output logic [31:0] haddr         // the module signal being shadowed
);
  // The module's own `haddr`: deliberately a DIFFERENT width and a different
  // value from the formal, so reading the wrong one is visible.
  assign haddr = pick ? 32'hFFFF_FFFF : 32'h0000_0000;

  function automatic logic [31:0] conv (
      input logic [1:0]  haddr,       // shadows the module signal above
      input logic [31:0] d,
      input logic        wide
  );
      logic [31:0] tmp;
  begin
      tmp = '0;
      if (wide) begin
          case (haddr[1])             // bit-select of the shadowing formal
            1'b0: tmp[15:0] = d[15:0];
            1'b1: tmp[15:0] = d[31:16];
            default: begin end
          endcase
      end else begin
          case (haddr)                // whole formal: the working path
            2'b00: tmp[7:0] = d[7:0];
            2'b01: tmp[7:0] = d[15:8];
            2'b10: tmp[7:0] = d[23:16];
            2'b11: tmp[7:0] = d[31:24];
            default: begin end
          endcase
      end
      return tmp;
  end
  endfunction

  assign half     = conv(sel, bus, 1'b1);
  assign byte_sel = conv(sel, bus, 1'b0);
endmodule
