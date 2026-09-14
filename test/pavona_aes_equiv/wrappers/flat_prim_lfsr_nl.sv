// prim_lfsr exactly as aes_prng_clearing instantiates it: GAL_XOR 64-bit,
// StatePermEn=1 with the AES clearing permutation, NonLinearOut=1 (the PRINCE
// S-box output layer — the only OpenTitan user of that layer).  Wrapper-only
// top (no RTL module of this name): aes_srcs.py seeds the closure from here.
module prim_lfsr_nl_flat import aes_pkg::*; (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        seed_en_i,
  input  logic [63:0] seed_i,
  input  logic        lfsr_en_i,
  output logic [63:0] state_o
);
  prim_lfsr #(
    .LfsrType     ( "GAL_XOR"                        ),
    .LfsrDw       ( 64                               ),
    .StateOutDw   ( 64                               ),
    .DefaultSeed  ( RndCnstClearingLfsrSeedDefault   ),
    .StatePermEn  ( 1'b1                             ),
    .StatePerm    ( RndCnstClearingLfsrPermDefault   ),
    .NonLinearOut ( 1'b1                             )
  ) u_lfsr (
    .clk_i, .rst_ni, .seed_en_i, .seed_i, .lfsr_en_i, .entropy_i('0), .state_o
  );
endmodule
