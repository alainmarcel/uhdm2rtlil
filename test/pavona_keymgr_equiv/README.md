# Pavona keymgr per-module equivalence

OpenTitan key manager (`hw/ip/keymgr`: identity / key derivation through
KMAC, sideload keys for AES / KMAC / ACC, the operation and data-enable state
machines, reseed control, input checks) from `/home/alain/pavona`, vendored
UNMODIFIED under `rtl/keymgr` (all 14 files); `flash_ctrl_pkg` and
`rom_ctrl_pkg` (the seed / digest struct types it imports) under `rtl/pkg`;
`kmac_pkg` from `../pavona_kmac_equiv`, prim / tlul / base packages from
`../pavona_tlul_equiv`, edn / lc packages from `../pavona_acc_equiv`.
Per-module `read_uhdm` vs `read_slang` SAT miter plus the 3-way Verilator
co-sim, same layout as the AES / entropy_src campaigns
(`run_keymgr_equiv.sh`, `keymgr_modules.txt`, `scripts/keymgr_cosim.py` with
`CS_TRACE=1`, `scripts/cs_vcd_diff.py`).

## Status

- **12 manifest rows, 11 formally proven** (seq=4, read_uhdm vs read_slang):
  the `keymgr` top (1800 s), `keymgr_reg_top`, `keymgr_kmac_if`,
  `keymgr_sideload_key_ctrl` / `keymgr_sideload_key`, `keymgr_reseed_ctrl`,
  `keymgr_input_checks`, `keymgr_err`, `keymgr_data_en_state`,
  `keymgr_op_state_ctrl`, `keymgr_cfg_en`.  `keymgr_ctrl` is SAT-hard (times
  out at 1800 s) and marked `timeout`, adjudicated by the co-sim.
- Co-sim (400 cycles, seed 1): **12 / 12 NO_DIVERGENCE**.
- No self-driving deep test yet: an end-to-end advance / generate operation
  needs a KMAC responder behind `kmac_data_i`, which the random co-sim only
  approximates (the top's sideload keys barely move under random stimulus).
  The two bugs below were both cycle-0 divergences, caught by the plain
  co-sim's FIRST-UHDM line.

## Bugs found (both fixed, each with an internal test)

1. **Function formal bound to a CONSTANT packed 2-D table**
   (`perm_data(data, RndCnstRandPerm)` with `rand_perm_t perm_sel` =
   `logic [31:0][4:0]`): the constant-argument fast path of the bit-select
   importer returned ONE BIT of the table for `perm_sel[k]` instead of the
   5-bit entry, so every permutation index folded to 0/1 — keymgr_kmac_if's
   decoy data and the sideload keys were wrong from cycle 0.
   `func_const_table_packed_elem_select`.
2. **`arr[k].member` on a PACKED array of packed structs**
   (`rom_ctrl_pkg::keymgr_data_t [NumRomDigestInputs-1:0] rom_digest_i`,
   `rom_digest_i[k].data` / `.valid` in keymgr_input_checks, also as a
   `prim_msb_extend` actual and inside `$bits()`): Surelog elaborates the
   port as a `packed_array_net` without a typespec of its own and a
   `struct_net` element; the element-struct resolver had no case for it, the
   read fell to the generic walker and produced one bit at the member's
   offset (`rom_digest_vld_o` read 0).  `packed_struct_array_member_read`.

Harness: the co-sim's `sh()` now decodes tool output with
`errors="replace"` — Verilator printed non-UTF-8 bytes on keymgr_ctrl and the
harness died with `UnicodeDecodeError` instead of a verdict.
