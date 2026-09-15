package pkg_packed2d_localparam_elem_addr_decode_pkg;
  localparam logic [1:0][31:0] ADDR_SPACE_PERI = {
    32'h 40400000,
    32'h 40000000
  };
  localparam logic [1:0][31:0] ADDR_MASK_PERI = {
    32'h 003fffff,
    32'h 001fffff
  };
  localparam logic [31:0] ADDR_SPACE_SPI = 32'h 40300000;
  localparam logic [31:0] ADDR_MASK_SPI  = 32'h 0000003f;
endpackage

module pkg_packed2d_localparam_elem_addr_decode
  import pkg_packed2d_localparam_elem_addr_decode_pkg::*;
(
  input  logic [31:0] addr_i,
  output logic [2:0]  sel_o,
  output logic [31:0] space0_o,
  output logic [31:0] mask1_o
);
  always_comb begin
    sel_o = 3'd7;
    if (((addr_i & ~(ADDR_MASK_PERI[0])) == ADDR_SPACE_PERI[0]) ||
        ((addr_i & ~(ADDR_MASK_PERI[1])) == ADDR_SPACE_PERI[1])) begin
      sel_o = 3'd5;
    end else if ((addr_i & ~(ADDR_MASK_SPI)) == ADDR_SPACE_SPI) begin
      sel_o = 3'd6;
    end
  end
  assign space0_o = ADDR_SPACE_PERI[0];
  assign mask1_o  = ADDR_MASK_PERI[1];
endmodule
