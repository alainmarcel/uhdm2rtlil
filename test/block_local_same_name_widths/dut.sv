// Regression for Caliptra soc_ifc_reg: 20 registers never latched their
// written value, and the chip co-sim diverged on `m_axi_w_if_awuser`.
//
// PeakRDL register files declare `automatic logic next_c` in the 1-bit fields
// and `automatic logic [31:0] next_c` in the 32-bit ones.  The begin-block
// handler reused the wire an EARLIER process had promoted under that bare name
// — a 1-bit wire — so every wide field's reads and writes were truncated to a
// single bit.  Each process's own promoted wire (name_map) must win.
module dut (
  input  logic        sel,
  input  logic        bit_in,
  input  logic [31:0] wide_in,
  output logic        bit_o,
  output logic [31:0] wide_o,
  output logic [15:0] mid_o
);
  // Promoted FIRST, one bit wide.
  always_comb begin
    automatic logic next_c;
    next_c = 1'b0;
    if (sel) next_c = bit_in;
    bit_o = next_c;
  end

  // Same local NAME, 32 bits: must not inherit the 1-bit wire above.
  always_comb begin
    automatic logic [31:0] next_c;
    next_c = 32'h0;
    if (sel) next_c = wide_in;
    wide_o = next_c;
  end

  // And a third width, for good measure.
  always_comb begin
    automatic logic [15:0] next_c;
    next_c = 16'h0;
    if (!sel) next_c = wide_in[15:0];
    mid_o = next_c;
  end
endmodule
