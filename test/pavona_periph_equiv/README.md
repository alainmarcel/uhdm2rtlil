# Pavona small-peripherals per-module equivalence

Six small OpenTitan IPs in ONE harness — `rom_ctrl` (scrambled ROM controller
with its KMAC digest check), `uart`, `aon_timer`, `rv_timer`, `pattgen`,
`sram_ctrl` (scrambled SRAM controller with the TL-UL life-cycle gate) — each
`hw/ip/<ip>/rtl` vendored UNMODIFIED under `rtl/<ip>`; prim / tlul / base
packages from `../pavona_tlul_equiv`, edn / lc / keymgr packages from
`../pavona_acc_equiv`, `kmac_pkg` from `../pavona_kmac_equiv`.  Per-module
`read_uhdm` vs `read_slang` SAT miter plus the 3-way Verilator co-sim, same
layout as the AES / entropy_src / keymgr campaigns (`run_periph_equiv.sh`,
`periph_modules.txt`, `scripts/periph_cosim.py` with `CS_TRACE=1`,
`scripts/cs_vcd_diff.py`).

## Status

- **29 manifest rows: 26 proven (seq=4), 2 `error` by design, 1 SAT-hard**
  (`./run_periph_equiv.sh`, 2026-09-13):
  - rom_ctrl 7 / 7 (compare, counter, fsm, mux, regs_reg_top, the
    `rom_ctrl` top at 900 s, and `rom_ctrl_scrambled_rom_init` with its
    16×40 image); uart 5 / 5; aon_timer 3 / 3; rv_timer 3 / 3 (timer_core,
    reg_top, top); pattgen 4 / 4; sram_ctrl 2 / 2 (regs_reg_top, the
    `sram_ctrl` top at 1800 s); `tlul_lc_gate` and `prim_subst_perm_r2`
    proven.
  - `rom_ctrl_rom_reg_top` / `sram_ctrl_ram_reg_top`: window-only generated
    reg_tops whose `tl_o` is undriven in the RTL itself — read_slang rejects
    them (`error` rows, not frontend bugs).
  - `prim_prince_hw` (64/128, 3 half rounds, halfway registers, as rom_ctrl
    and sram_ctrl instantiate it): SAT-hard once the S-boxes are live (1500 s
    without a verdict; a 32/64 one-half-round variant does not finish either)
    — `timeout` row, adjudicated by the co-sim.
- **Co-sim (300 cycles, seed 1): 27 / 27 `NO_DIVERGENCE`**.  Activity is real
  on the datapath rows (rom_ctrl_mux `bus_rdata_o` 300 changes, rom_ctrl_fsm
  `digest_o` 300, timer_core `intr` 118, aon_timer_core `wdog_intr_o` /
  `wdog_reset_req_o`, pattgen_core `pda*/pcl*` 60-93, sram_ctrl `ram_tl_o`
  151, prim_prince `data_o` 164, prim_subst_perm `data_o` 300) and on every
  top's `tl_o`; under random stimulus the tops' slow outputs stay idle in 300
  cycles (uart_rx never assembles a frame — `rx_valid` 0, pattgen's `cio_*`
  pins, the timers' interrupt lines) — those rows rest on their seq-4 proofs.
  The sram_ctrl / rom_ctrl co-sims are also VACUOUS for the scrambler
  keystream (a wrong keystream cancels on write-then-read); the ROM-image
  row and the miters are what check it — bugs 8 and 9 below were found by
  the seq-4 miter only.
- `check` reports 0 problems on every read_uhdm netlist (the rom_ctrl /
  sram_ctrl scramblers had logic loops and the sram_ctrl `ram_tl_i` input a
  conflicting driver before this campaign).

## Bugs found (all fixed, each with an internal test or a manifest row)

1. **Struct member shadowed by a module signal** — pattgen_chan's
   `logic enable; assign enable = ctrl_i.enable;`: Surelog binds the `enable`
   path element to the module-scope signal and the hier_path importer followed
   that binding, producing `assign enable = enable` (a self-loop folded to 0 —
   neither pattgen channel ever enabled).  The base `ctrl_i` is a struct PORT
   with no binding of its own; the importer now resolves its typespec by name
   and never binds later path elements by module name.
   `hier_path_struct_member_shadow`.
2. **`$readmemh` inside a named block** — OpenTitan's
   `prim_util_memload.svh` (`if (MemInitFile != "") begin : gen_meminit
   $readmemh(…)`) reached through a paramod: the scanner cast the
   `named_begin` to `begin` and got nothing, so every prim_rom / prim_ram
   image was dropped and rom_ctrl's scrambled ROM read 0.
   `rom_named_begin_readmemh`.  The manifest row `rom_ctrl_scrambled_rom_init`
   wraps the ROM with a deterministic 16×40 image (`rom_init.vmem`): without
   an image the ROM content is a free variable in the miter and uninitialised
   memory in the RTL sim, so nothing is compared.
3. **Field write on a constant-indexed element after a whole-element write**
   (`tl_h2d_int[0] = tl_h2d_i; … tl_h2d_int[0].a_valid = 1'b0;` in
   tlul_lc_gate, the gate sram_ctrl puts in front of its RAM window): the
   assigned-signal scanner stripped the element index, booked the field write
   against the array base with its own ranged temp, and the process update
   never carried it — proc_dlatch made a latch of it whose Q, through the
   whole-write alias, drove the module INPUT (`check`: conflicting driver on
   sram_ctrl's `ram_tl_i.a_valid`).  Two fixes: the element is named as the
   target, and a signal written whole and by a part in one process keeps a
   single temp.  Then the hier_path write target itself was resolved at the
   element's in-flight value (the input port): hier_path targets now keep
   their base like every other partial write.  Coverage: manifest row
   `tlul_lc_gate` (not in the TL-UL campaign's manifest).

4. **In-place slice rewrite of a generate-parent local from a nested scope**
   (`prim_subst_perm`, the substitution-permutation scrambler rom_ctrl and
   sram_ctrl use: `data_state_sbox` is declared in `gen_round[r]`, the
   always_comb sits in `gen_round[r].gen_enc`, and it rewrites
   `data_state_sbox[k*4 +: 4]` from its own value): the for-loop-written
   local was looked up one scope level only and dropped from the process's
   temp setup, and the part-select read never threaded the in-flight value
   by the resolved wire name — the rewrite read the wire the process drives.
   `check` reported logic loops in every scrambler, the ROM co-sim did not
   converge and the proofs were vacuous.  `genscope_parent_local_inplace_slice`;
   manifest row `prim_subst_perm`.

5. **Package table element + trailing part-select dropped** —
   `prim_cipher_pkg::PRINCE_ROUND_CONST[k][DataWidth-1:0]` (prim_prince,
   every round): Surelog emits a var_select with no binding (the parameter
   lives in the package), the importer's parameter branch was skipped, the
   wire paths found nothing ("vpiVarSelect: element … not found") and the
   whole XOR term was dropped.  The var_select handler now slices the folded
   package table and applies the trailing part / indexed / bit select.
   `pkg_param_table_varselect_partsel`.
6. **Dynamic bit-select on a packed 2-D function formal folded to element 0**
   — `sbox4[state_in[k*4 +: 4]]` in `prim_cipher_pkg::sbox4_8bit`
   (`logic [15:0][3:0] sbox4` bound to PRINCE_SBOX4): the function-parameter
   branch of the bit_select handler only sliced a CONSTANT index and returned
   the whole mapped value otherwise, which the caller truncated to the low
   nibble — every S-box output was `sbox4[0]`, the PRINCE cipher a constant,
   and rom_ctrl / sram_ctrl scrambling wrong (the PRINCE proofs in earlier
   campaigns never exercised the S-box with a live index).  A dynamic index
   now extracts the element with a `$shiftx` sized by the formal's outer
   dimension.  `func_formal_packed_dyn_bitselect`; manifest row
   `prim_prince_hw` (64/128, 3 half rounds, as rom_ctrl instantiates it).

7. **Assignment-pattern parameter re-folded at the caller's width** —
   `prince_shiftrows_32bit(state, PRINCE_SHIFT_ROWS64)` inside a 32-bit
   assignment: the `'{…}` fold preferred the surrounding context width over
   the parameter's own `logic [15:0][3:0]` type and packed the 16-entry table
   at 2 bits per entry, truncating every shift index (the 64-bit variant
   matched its context by luck).  The pattern's own type now wins.
   `pkg_pattern_param_func_actual_width`.
8. **Genvar resolved on an ancestor by the ExprEval fold** — prim_prince's
   `PRINCE_ROUND_CONST[10-NumRoundsHalf+k]` in `gen_bwd_pass[k]`, with
   prim_prince sitting inside prim_ram_1p_scr's `gen_par_scr[k]`: the
   operation was pre-folded by Surelog's ExprEval from the MODULE instance,
   whose name walk misses the generate scope and finds the ancestor's `k`
   (= 0) — every backward-pass round constant was RC[7] and the sram_ctrl
   keystream wrong.  A write-then-read co-sim cannot see this (the same wrong
   keystream cancels); the seq-4 miter did.  Operations with a generate-scope
   parameter operand are no longer handed to ExprEval.
   `genvar_exprfold_ancestor_shadow` (needs the two-level paramod nesting);
   the `sram_ctrl` row.

Harness: `run_periph_equiv.sh` classifies verdicts with herestrings — under
`pipefail`, `echo "$out" | grep -q` on a large output got a SIGPIPE and every
read_slang elaboration error was reported as "timeout".

Not bugs: `rom_ctrl_rom_reg_top` and `sram_ctrl_ram_reg_top` are generated
window-only register tops that never drive `tl_reg_d2h` — `tl_o` is undriven
in the RTL itself and read_slang rejects them; both rows are `error`.
