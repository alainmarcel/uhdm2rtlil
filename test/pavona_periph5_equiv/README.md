# Pavona small-peripherals set 5 per-module equivalence

The last two OpenTitan IPs with RTL in the Pavona tree — `usbdev` (USB 2.0
full-speed device: line-state / PHY-level RX / TX engines, packet buffer,
endpoint FSMs, reg_top and the `usbdev` top) and `spi_device` (SPI flash /
passthrough / TPM device: command parser, flash read / status / JEDEC / upload
engines, TPM, passthrough, reg_top and the `spi_device` top) — each
`hw/ip/<ip>/rtl` vendored UNMODIFIED under `rtl/<ip>`; prim / tlul / base
packages from `../pavona_tlul_equiv`.  Per-module `read_uhdm` vs `read_slang`
SAT miter plus the 3-way Verilator co-sim, same layout as the earlier
peripheral sets (`run_periph5_equiv.sh`, `periph5_modules.txt`,
`scripts/periph5_cosim.py` with `CS_TRACE=1`, `scripts/cs_vcd_diff.py`).

## Status

- **30 manifest rows: 29 proven, 1 SAT-hard**
  (`./run_periph5_equiv.sh`, 2026-09-14): usbdev 12 / 12 sub-modules proven
  (the `usbdev` top gives no verdict in 1800 s — `timeout` row, co-sim
  adjudicated); spi_device 17 / 17 proven (incl. `spi_device_reg_top`
  through its flat wrapper, and `spid_dpram` + the `spi_device` top through
  the global-clock flow for their dual-clock RAM, see below — seq=8 global
  steps, 282 s for the top).
- **Co-sim (300 cycles, seed 1): 30 / 30 `NO_DIVERGENCE`** except
  `spid_status`, where both netlists differ identically from the RTL (an
  RTL-side artefact, see below).  Real activity on the USB engines
  (usb_fs_nb_in_pe `in_xact_start_ep_o` 255), the SPI command / read / status
  / upload engines, both tops' `tl_o` and spi_device's `passthrough_o`.
- `check` reports 0 problems on every read_uhdm netlist.

## Bugs found

One frontend bug, found only once the `spi_device` top could be mitered:

- **Nested NAMED assignment pattern into a struct MEMBER** — `assign
  hw2reg.tpm_cap = '{ rev: '{de: 1'b1, d: tpm_cap.rev}, locality: …,
  max_wr_size: …, max_rd_size: … }` names the fields in a different order
  than `spi_device_hw2reg_tpm_cap_reg_t` declares them (and the inner
  `'{de, d}` the reverse of the `{d, de}` sub-structs).  The pattern op
  carries no typespec and the LHS is a `hier_path`, not a `ref_obj`, so the
  reader found no target type and packed the fields in SOURCE order at both
  levels: `rev.d` landed in `max_rd_size`, every `de` bit was misplaced and a
  TL read of TPM_CAP returned garbage.  The 15 clocked rows never see it
  (the reg_top gets `hw2reg` as an input; `spi_tpm` only emits `tpm_cap`)
  and the 300-cycle co-sim never reads TPM_CAP.  Fixed: the member's struct
  typespec is resolved from the hier_path (`hier_path_member_typespec`) and
  threaded to nested fields (test `cont_assign_nested_named_pattern_member`).

Notes:

- **Dual-clock 2-port RAM (was `nosat`)** — `spid_dpram` (and therefore the
  `spi_device` top) instantiates `prim_ram_2p` with its two write ports on
  different clocks (system and SPI).  In the clocked flow `memory_map`
  refuses that memory on BOTH sides ("write clock 1 is incompatible with
  other clocks"), the `$mem_v2` reaches the solver and it has no model for
  it.  `wrappers/clk_excl_<m>.txt` (the clock port names, plus a
  `memsize <cell glob> <words>` line) switches the row to a global-clock
  flow: `memory -nordff -nomap` (read ports stay combinational),
  `setparam -set SIZE 64` on the RAM cell (a bounded-address abstraction,
  identical on both sides — the 1024x36 RAM as FFs is 25M SAT variables and
  gives no verdict in 1800 s even at seq=4; 64 words with free clocks still
  needs 723 s at seq=4), `clk2fflogic`, `memory_map -formal` (accepts the
  now-unclocked write ports), then `scripts/add_clk_excl.py` adds an
  assumption to the miter that no two clocks toggle in the same global step
  (both write ports hitting one address in one step is an RTL race that
  `memory_map` resolves by port ORDER, which differs between the two
  frontends — a false cex), and `sat -set-assumes` runs with the clocks on a
  fixed two-phase schedule (`-set-at`: sys toggles every step, SPI every two
  steps, scan held 0), so seq=8 covers 4 sys / 2 SPI cycles with a sys write
  read back on the SPI side and vice versa.  Everything else (the tied-clock
  wrapper, `expose -evert` cuts) either timed out, failed on the read_slang
  side or paired the read ports in a different order.  Co-sim of both rows
  at the full depth: NO_DIVERGENCE with real activity (`sys_rvalid_o` 125,
  `spi_rvalid_o` 76; spi_device `tl_o` 146, `passthrough_o` 297).
- **Unpacked window ports** — `spi_device_reg_top` has `tl_win_o/i [2]`
  (flat wrapper, as for the other reg_tops with windows).
- **spid_status co-sim** — both netlists differ from the behavioural RTL at
  the same cycle on the same signal (`cmd_sync_status_wel_o`, cycle 5;
  uhdm == slang throughout) while the row PROVES: a simulation artefact of
  the clock-domain-crossing status sync under the single-clock random
  testbench, not a frontend difference.
- The manifest generator picked up a `module should …` line from a comment
  block in spi_readcmd.sv; that row was dropped by hand.
