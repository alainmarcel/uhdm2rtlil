# Pavona small-peripherals set 4 per-module equivalence

Three OpenTitan IPs in ONE harness — `keymgr_dpe` (DPE key manager: control
FSM, operation-state control, reg_top and top), `lc_ctrl` (life-cycle
controller: FSM, state decode / transition, signal decode, KMAC interface,
regs / DMI reg_tops and top) and `rv_dm` (RISC-V debug module: DMI gate,
dbg / mem / regs reg_tops and the `rv_dm` top over the pulp_riscv_dbg
`dm_top` / `dmi_jtag` vendor sources) — each `hw/ip/<ip>/rtl` vendored
UNMODIFIED under `rtl/<ip>`, `hw/vendor/pulp_riscv_dbg/src` (+ `debug_rom`)
under `rtl/riscv_dbg`; `lc_ctrl_token_pkg`, `otp_macro_pkg`, `rom_ctrl_pkg`
under `rtl/pkg`; prim / tlul / base packages from `../pavona_tlul_equiv`,
edn / lc / keymgr / otp packages from `../pavona_acc_equiv`.  Per-module
`read_uhdm` vs `read_slang` SAT miter plus the 3-way Verilator co-sim, same
layout as the earlier peripheral sets (`run_periph4_equiv.sh`,
`periph4_modules.txt`, `scripts/periph4_cosim.py` with `CS_TRACE=1`,
`scripts/cs_vcd_diff.py`).

## Status

- **17 / 17 manifest rows proven** (seq=4; `./run_periph4_equiv.sh`,
  2026-09-14): keymgr_dpe 4 / 4 (keymgr_dpe_ctrl's key-slot array RMW is
  SAT-hard and carries an 1800 s budget), lc_ctrl 8 / 8, rv_dm 5 / 5 — the
  lc_ctrl rows and the rv_dm top need Surelog #4175 (merged and bumped).
- **Co-sim (300 cycles, seed 1): 17 / 17 `NO_DIVERGENCE`**.  Real activity on
  the reg_tops, lc_ctrl_kmac_if / signal_decode / state_decode, rv_dm's DMI
  gate and keymgr_dpe_ctrl (`op_done_o` 154, `error_o` 254); the tops' key /
  interrupt outputs stay idle under random TL-UL traffic in 300 cycles and
  rest on their seq-4 proofs.
- `check` reports 0 problems on every read_uhdm netlist.

## Bugs found

1. **Surelog: enum members wider than 64 bits had no value** —
   lc_ctrl_state_pkg's 320-bit `lc_state_e` / 384-bit `lc_cnt_e` members
   (`{A11, B10, …}` concatenations of 16-bit parameters): the 64-bit value
   evaluator left `VpiValue` empty, so every `case` arm on those states
   compared against 0 and never matched (state decode / transition / FSM,
   the lc_ctrl top).  Surelog #4175 folds the member expression through the
   expression compiler; the reader parses wide `BIN:` values at the member's
   typespec width.  `enum_wide_concat_member_values`
   (tests/EnumWideConcatValue in Surelog).
2. **Enum members of a function-sized enum stamped 64 bits wide** —
   `enum logic [vbits(NumLcStates)-1:0]` (`dec_lc_state_e`): Surelog cannot
   size the base and stamps vpiSize 64, so ExprEval folded
   `{DecLcStateNumRep{DecLcStInvalid}}` with 64-bit members and the 30-bit
   result held ONE copy (lc_ctrl_state_decode), and
   `trans_target_i == {6{DecLcStScrap}}` never matched (state_transition).
   The reader sizes enum members from the enum's base typespec and keeps
   operations with mis-sized members out of ExprEval.
   `enum_funcsized_member_replication`.
3. **Surelog: an attribute instance dropped the whole always block** —
   `always_comb (* xprop_off *) begin … end` (pulp_riscv_dbg dm_csrs /
   dm_mem, as vendored by rv_dm): the attribute was taken as the statement
   (UH0701 "Unsupported statement Attr_spec") and the block vanished from
   the UHDM — rv_dm's CSR read / write logic was missing while the raw
   miter still "proved" the empty side.  Surelog #4175 skips leading
   attribute instances.  `always_comb_attribute_instance`
   (tests/AlwaysAttrInstance in Surelog).
4. **Dynamic slot writes into a packed array of structs** (keymgr_dpe_ctrl's
   `key_slots_d[slot_dst_sel_i]`): `.key[j][cnt*EntropyWidth +: EntropyWidth]
   = …` (Surelog: the member ref followed by an unnamed var_select carrying
   both indices) fell through to the hier_path READ path and a `$shiftx` aux
   became the write target ("Cell $procmux … already driven"); the compound
   `.key[0] ^= root_key_i[0]` stored the bare RHS.  The element-field writer
   now handles that encoding, adds a dynamic tail base to the shift amount,
   folds compound operators, and the dynamic hier_path read uses the block's
   in-flight value of the base.  `dyn_elem_member_slice_compound_write`.

Harness / RTL-side notes: rv_dm needs the pulp_riscv_dbg vendor sources
(`rtl/riscv_dbg`, minus the DMI testbench package / interface and the Xilinx
BSCANE2 TAP); keymgr_dpe and lc_ctrl pull `sha3_pkg` (KMAC root) and the
keymgr sub-blocks (keymgr root); `run_periph4_equiv.sh` also re-elaborates
when the closure's file list changes (adding a root leaves every mtime
untouched, so the earlier check kept a stale UHDM).
