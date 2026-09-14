# Pavona small-peripherals set 3 per-module equivalence

Four OpenTitan IPs in ONE harness — `mbx` (DOE mailbox: host / SoC interfaces,
inbound / outbound mailboxes, SRAM read-write arbiter, FSM), `dma` (DMA
controller with its reg_top), `soc_dbg_ctrl` (SoC debug-policy controller:
core / JTAG reg_tops, decode) and `ascon` (Ascon AEAD accelerator core) — each
`hw/ip/<ip>/rtl` vendored UNMODIFIED under `rtl/<ip>`; `pwrmgr_pkg` and
`rom_ctrl_pkg` under `rtl/pkg`; prim / tlul / base packages from
`../pavona_tlul_equiv`, edn / lc / keymgr packages from `../pavona_acc_equiv`.
Per-module `read_uhdm` vs `read_slang` SAT miter plus the 3-way Verilator
co-sim, same layout as the first two peripheral sets (`run_periph3_equiv.sh`,
`periph3_modules.txt`, `scripts/periph3_cosim.py` with `CS_TRACE=1`,
`scripts/cs_vcd_diff.py`; every row gets `prim_assert.sv` first and read_slang
runs `--single-unit`).

## Status

- **18 / 18 manifest rows proven** (seq=4; `./run_periph3_equiv.sh`,
  2026-09-13): mbx 9 / 9 (incl. `mbx_soc_reg_top` through its flat wrapper and
  the `mbx` top), dma 2 / 2 (the `dma` top needs Surelog #4174, merged and bumped), soc_dbg_ctrl
  4 / 4, ascon 3 / 3.
- **Co-sim (300 cycles, seed 1): 18 / 18 `NO_DIVERGENCE`** (dma's row with the
  Surelog fix).  Real activity on the reg_tops, the mailbox datapath
  (mbx_imbx / mbx_ombx / mbx_sramrwarb), soc_dbg_ctrl_decode and ascon_core's
  `hw2reg`; the tops' interrupt / `sys_o` outputs stay idle under random TL-UL
  traffic in 300 cycles (no mailbox message or DMA transfer is ever
  configured) — those rows rest on their seq-4 proofs.
- `check` reports 0 problems on every read_uhdm netlist.

## Bugs found

1. **Surelog: package-qualified typedef element loses its outer packed
   dimension** — `top_racl_pkg::racl_role_t [SYS_NUM_REQ_CH-1:0] racl_vec` in
   `dma_pkg::sys_req_t`: the package-scope typespec branch only wrapped
   struct / enum / class typedefs, so a `pkg::t [N-1:0]` member of a logic /
   bit typedef measured one element (183 bits instead of 184 — `miter`
   reports that as "No matching port in gate module", a WIDTH mismatch).
   Surelog PR #4174 (tests/PkgTypedefMemberPackedDim); reader test
   `pkg_typedef_member_packed_dim`.
2. **Whole-vs-part pruning took struct MEMBER writes for whole writes** —
   dma's `sys_req_d.write_data = …` (a hier_path, registered un-flagged) was
   counted as a whole write of `sys_req_d`, and the set-1 pruning (meant for
   `arr[0] = x; arr[0].f = y`) dropped the sibling element writes
   (`sys_req_d.metadata_vec[SysCmdWrite] = …`): their bits never entered the
   written-bits scan and the process update carried [39:0] of 184 — every
   vld / metadata / opcode / iova / racl element stayed 0.  Only a bare
   ref_obj / element-name write counts as whole now.
   `struct_member_elem_writes_update_range`.
3. **Loop-indexed struct member write forced a full-wire update** —
   `hw2reg.sha2_digest[i].d = …` in a for loop (dma's hw2reg block): the
   written-bits scan cannot resolve the loop index and fell back to updating
   ALL of `hw2reg`, a second driver of `hw2reg.intr_state.*.d` (driven by the
   `prim_intr_hw` instances: "Driver-driver conflict … resolved using
   constant" — the dma error / done interrupts never fired).  A loop-indexed
   struct member is now bounded to the whole member's bits.
   `comb_loop_member_write_update_range`.

Harness / RTL-side notes: `mbx_soc_reg_top` has `tl_win_o/i [2]` unpacked
struct ports (flat wrapper, as for spi_host_reg_top); soc_dbg_ctrl needs the
top_dragonfly `pwrmgr_pkg` / `pwrmgr_reg_pkg` (the egret one lacks
`pwr_boot_status_t`) — and `run_periph3_equiv.sh` now re-elaborates when any
closure source is newer than the cached UHDM (a re-vendored package was read
stale while read_slang saw the new file); ascon_core assigns plain vectors to
enum-typed signals, so read_slang runs `--relax-enum-conversions` and Verilator
`-Wno-ENUMVALUE`.
