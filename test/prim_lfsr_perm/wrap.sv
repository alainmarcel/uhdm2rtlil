// prim_lfsr exactly as ibex_dummy_instr instantiates it (32-bit LFSR,
// 17-bit permuted state output slice, default seed + permutation).
module prim_lfsr_perm_wrap
  import ibex_pkg::*;
(
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        seed_en_i,
  input  logic [31:0] seed_i,
  input  logic        lfsr_en_i,
  output logic [16:0] state_o
);
  prim_lfsr #(
      .LfsrDw      ( 32 ),
      .StateOutDw  ( 17 ),
      .DefaultSeed ( RndCnstLfsrSeedDefault ),
      .StatePermEn ( 1'b1 ),
      .StatePerm   ( RndCnstLfsrPermDefault )
  ) lfsr_i (
      .clk_i,
      .rst_ni,
      .seed_en_i,
      .seed_i,
      .lfsr_en_i,
      .entropy_i ( '0 ),
      .state_o
  );
endmodule
