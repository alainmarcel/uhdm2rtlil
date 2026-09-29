// An unbased-unsized fill literal as an INSTANCE PORT actual (`.be_i('1)`) is
// sized by the formal (LRM 5.7.1).  At module scope it was; for an instance
// inside a GENERATE LOOP read_uhdm connected a 1-bit constant, so only
// be_i[0] was set -- CVA6 wt_dcache_mem's `gen_tag_srams[i].i_tag_sram
// (.be_i('1))` wrote one byte lane of every tag SRAM word (the miter differs,
// the cache mis-tags lines).  The port width is a localparam of the leaf
// derived from its parameters, as in tc_sram_wrapper.
module leaf #(parameter int unsigned DataWidth = 32, parameter int unsigned ByteWidth = 8,
              localparam int unsigned BeWidth = (DataWidth + ByteWidth - 32'd1) / ByteWidth) (
  input  logic [BeWidth-1:0]   be_i,
  input  logic [BeWidth-1:0]   mask_i,
  input  logic [DataWidth-1:0] d_i,
  output logic [DataWidth-1:0] q_o,
  output logic [BeWidth-1:0]   be_o
);
  for (genvar b = 0; b < BeWidth; b++) begin : g
    assign q_o[b*ByteWidth +: ByteWidth] = be_i[b] ? d_i[b*ByteWidth +: ByteWidth]
                                                   : (mask_i[b] ? {ByteWidth{1'b1}} : '0);
  end
  assign be_o = be_i;
endmodule

module dut #(parameter int N = 3) (
  input  logic [N-1:0][47:0] d_i,
  output logic [N-1:0][47:0] q_gen,
  output logic [N-1:0][5:0]  be_gen,
  output logic [47:0]        q_top,
  output logic [5:0]         be_top
);
  for (genvar i = 0; i < N; i++) begin : gen_tag
    leaf #(.DataWidth(48), .ByteWidth(8)) u (.be_i('1), .mask_i('0), .d_i(d_i[i]), .q_o(q_gen[i]), .be_o(be_gen[i]));
  end
  leaf #(.DataWidth(48), .ByteWidth(8)) u_top (.be_i('0), .mask_i('1), .d_i(d_i[0]), .q_o(q_top), .be_o(be_top));
endmodule
