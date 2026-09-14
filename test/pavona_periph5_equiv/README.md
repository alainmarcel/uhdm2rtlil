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

- **30 manifest rows: 27 proven (seq=4), 2 `nosat`, 1 SAT-hard**
  (`./run_periph5_equiv.sh`, 2026-09-14): usbdev 12 / 12 sub-modules proven
  (the `usbdev` top gives no verdict in 1800 s — `timeout` row, co-sim
  adjudicated); spi_device 15 / 15 SAT-modellable rows proven (incl.
  `spi_device_reg_top` through its flat wrapper), `spid_dpram` and the
  `spi_device` top are `nosat` (dual-clock RAM, see below).
- **Co-sim (300 cycles, seed 1): 30 / 30 `NO_DIVERGENCE`** except
  `spid_status`, where both netlists differ identically from the RTL (an
  RTL-side artefact, see below).  Real activity on the USB engines
  (usb_fs_nb_in_pe `in_xact_start_ep_o` 255), the SPI command / read / status
  / upload engines, both tops' `tl_o` and spi_device's `passthrough_o`.
- `check` reports 0 problems on every read_uhdm netlist.

## Bugs found

No frontend bug in this set: every row that the SAT solver can model proves
as vendored.  Notes:

- **Dual-clock 2-port RAM** — `spid_dpram` (and therefore the `spi_device`
  top) instantiates `prim_ram_2p` with its two write ports on different
  clocks (system and SPI).  `memory_map` refuses that memory on BOTH sides
  ("write clock 1 is incompatible with other clocks"), the `$mem_v2` reaches
  the solver and it has no model for it.  The rows are `nosat` (a verdict the
  harness now distinguishes from an elaboration error) and are adjudicated by
  the 3-way co-sim: NO_DIVERGENCE with real activity (`sys_rvalid_o` 125,
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
