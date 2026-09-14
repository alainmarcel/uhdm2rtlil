# Pavona small-peripherals set 2 per-module equivalence

Four OpenTitan IPs in ONE harness — `sysrst_ctrl` (system-reset controller:
key-combo / ultra-low-power detection, pin overrides, auto-block),
`i2c` (controller + target FSMs, FIFOs over a 1p SRAM adapter, bus monitor),
`spi_host` (command queue, byte select / merge, shift register, FSM, data
FIFOs, window) and `adc_ctrl` (ADC sampling FSM, filters, interrupts) — each
`hw/ip/<ip>/rtl` vendored UNMODIFIED under `rtl/<ip>`; `spi_device_pkg` and
`ast_pkg` under `rtl/pkg`; prim / tlul / base packages from
`../pavona_tlul_equiv`, edn / lc / keymgr packages from `../pavona_acc_equiv`.
Per-module `read_uhdm` vs `read_slang` SAT miter plus the 3-way Verilator
co-sim, same layout as the first peripherals set (`run_periph2_equiv.sh`,
`periph2_modules.txt`, `scripts/periph2_cosim.py` with `CS_TRACE=1`,
`scripts/cs_vcd_diff.py`).

## Status

- **33 / 33 manifest rows proven** (seq=4; `./run_periph2_equiv.sh`,
  2026-09-13): sysrst_ctrl 10 / 10, i2c 8 / 8, spi_host 10 / 10, adc_ctrl
  5 / 5 — every RTL module including the four tops (900 s rows) and
  `spi_host_reg_top` through its flat wrapper.
- **Co-sim (300 cycles, seed 1): 33 / 33 `NO_DIVERGENCE`**.  Datapath rows
  move for real (i2c_core `scl_o` / `sda_o` 122 / 131 and its interrupts,
  spi_host `cio_sd_o` 201 / `cio_sck_o` 112, spi_host_shift_register 8 / 9
  outputs, adc_ctrl_fsm `adc_pd_o` 158 / `aon_fsm_state_o` 165, every top's
  `tl_o`).  The sysrst_ctrl debounce blocks (detect, combo, keyintr, ulp) were
  VACUOUS under random stimulus (random inputs never hold a level for the
  configured debounce + detect time): `DIRECTED[...]` entries in
  `scripts/periph2_cosim.py` drive slow square waves with small timer
  configs and all enables set — detect 13 events, combo 12 interrupts,
  keyintr 54 / 51 edges, ulp 6 wake-ups, all clean.  The spi_host_fsm /
  spi_host_core / i2c_controller_fsm rows stay mostly idle under random
  command inputs; their tops exercise them (spi_host `cio_*` activity above)
  and the rows rest on their proofs.
- `check` reports 0 problems on every read_uhdm netlist.

## Bugs found

No frontend bug in this set: all 33 rows prove as vendored.  Three harness /
RTL-side notes:

- **Shared compilation unit** — `spi_host_fsm.sv` and `spi_host_core.sv` use
  `` `ASSERT `` without including `prim_assert.sv` (only `spi_host.sv` does);
  both Surelog (PP0102) and read_slang rejected them as separate units.  The
  harness feeds `prim_assert.sv` first and runs read_slang `--single-unit`
  (Surelog is single-unit by default) for every row.
- **`spi_device_pkg` dependency** — spi_host imports `spi_device_pkg`, which in
  turn needs `spi_device_reg_pkg`; both are vendored from `hw/ip/spi_device/rtl`
  under `rtl/pkg` together with `ast_pkg` (adc_ctrl, from
  `hw/top_dragonfly/ip/ast/rtl`).
- **Unpacked window ports** — `spi_host_reg_top` has `tl_win_o[2]` /
  `tl_win_i[2]` unpacked struct ports; the raw miter compared the two windows
  swapped (read_uhdm flattens unpacked PORTS elem0@LSB, read_slang elem0@MSB)
  and reported a spurious cex at step 1 inside `tlul_socket_1n`.  The
  `flat_spi_host_reg_top` wrapper flattens them explicitly; the row proves.
