# Pavona CSRNG per-module equivalence

CTR-DRBG random number generator (OpenTitan `hw/ip/csrng`), vendored
UNMODIFIED from /home/alain/pavona. Per-module `read_uhdm` vs `read_slang` SAT
miter, mirroring the EDN / HMAC / KMAC / ACC / TL-UL campaigns.

- `rtl/csrng` — vendored CSRNG RTL (12 files).
- `rtl/aes` — the 21-file closure of `aes_cipher_core` that
  `csrng_block_encrypt` instantiates (AES192Enable=0, CiphOpFwdOnly=1,
  SecMasking=0; SBoxImpl = Canright from the csrng top, LUT by default in
  csrng_core / csrng_block_encrypt), vendored from `hw/ip/aes/rtl`.
- prim / tlul / base packages from `../pavona_tlul_equiv/rtl/{prim,tlul,pkg}`,
  entropy_src / edn packages from `../pavona_acc_equiv/rtl/pkg`.
- `./run_csrng_equiv.sh [module]` — surelog → read_uhdm vs read_slang miter.
  `csrng_modules.txt` = manifest (csrng modules + the AES sub-blocks).
- `scripts/csrng_cosim.py <mod> [cycles] [seed]` — Verilator co-sim with the
  per-output ACTIVITY line and the `DIRECTED[mod]` stimulus table.

## Status
- **All 18 manifest modules proven** (seq=4): the 8 AES sub-blocks
  (aes_sbox_lut, aes_sbox_canright, aes_shift_rows, aes_mix_single_column,
  aes_mix_columns, aes_key_expand, aes_cipher_control_fsm, aes_cipher_control)
  and the 10 csrng modules (csrng_main_sm, csrng_cmd_stage, csrng_state_db,
  csrng_ctr_drbg_cmd, csrng_ctr_drbg_upd, csrng_ctr_drbg_gen,
  csrng_block_encrypt, csrng_core, csrng_reg_top, csrng).
- Co-sim (1000 cycles, seed 1): NO_DIVERGENCE on all 18 with real activity
  (csrng_block_encrypt rsp_data_o 815 changes, aes_key_expand key_o 1000,
  csrng_ctr_drbg_gen cmd_rsp_data_o 793, csrng tl_o 481 / cs_aes_halt_o 250);
  only csrng_main_sm (a sparse FSM under random control) and
  aes_cipher_control_fsm move little.

## Frontend bugs found here (all fixed)
`csrng_block_encrypt`'s co-sim was UHDM_WRONG at cycle 0 although the csrng
TOP's seq=4 miter "proved" — the top never reaches key expansion in 4 cycles.
Splitting the AES cipher core into its sub-blocks localized five bugs:

1. `regular[s][7:4] = key_i[s][3:0]` (aes_key_expand, `logic [7:0][31:0]
   regular [NumShares]`): a packed-ROW RANGE on an unpacked-array element was
   applied as BITS — 7 of 8 key words latched.
2. `aes_mvm(vec_b, logic [7:0] mat_a [8])`: an unpacked-array function
   argument was staged at the ELEMENT width (the io_decl's unpacked Ranges()
   were ignored), so `mat_a[j][i]` found nothing and the Canright S-box result
   was empty; a `'{}`-folded ascending parameter table actual (A2X/S2X/X2S)
   is reversed to the elem0@LSB layout the formal uses.
3. `vec_c[i] = vec_c[i] ^ …` (aes_mvm): a constant bit-select write on a
   function local wrote the mapped wire in place — the unrolled accumulator
   read the wire it drives, a combinational loop the SAT miter still proved.
   Now SSA-renamed like the dynamic-index path.
4. `key_i[s][3]` on `logic [7:0][31:0] key_i [NumShares]` (an unpacked-array
   PORT of packed words): the packed-dim paths only knew the element's dims
   and folded it as bit 3 of the flat wire; the unpacked dim is now prepended
   whenever alias elements exist (also for a one-element array) and a
   trailing part-select addresses a range of the next dim.
5. `aes_circ_byte_shift`'s local `s` in `8*((7-s)%4)`, called from
   `for (genvar s …)`: the ExprEval fold resolved `s` to the GENVAR (rotate by
   the share index instead of 3).  Operations on function locals/args are no
   longer folded against the instance scope.

Still open: Surelog SEGFAULTs elaborating `aes_sub_bytes` with its default
`SecSBoxImpl = SBoxImplDom` (masked DOM S-box) — not on csrng's path (LUT /
Canright), tracked for the AES campaign.
