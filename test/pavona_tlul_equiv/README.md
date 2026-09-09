# Pavona TL-UL equivalence (`pavona_tlul_equiv`)

Per-module UHDM-vs-`read_slang` equivalence for the Pavona (OpenTitan) TileLink-UL
bus library — the next Pavona-family target after the Ibex core, and the
dependency every Pavona IP (ACC, KMAC, …) sits on.

- `rtl/tlul/`  — `hw/ip/tlul/rtl` (vendored verbatim)
- `rtl/prim/`  — the prim library + `prim_generic` implementations
- `rtl/pkg/`   — `top_pkg`, `top_racl_pkg`, `jtag_pkg`, `lc_ctrl_pkg`
- `scripts/tlul_srcs.py` — prints the per-module dependency **closure** (only the
  files a module needs, packages first) so slang/surelog get a self-consistent set
- `run_tlul_equiv.sh` — surelog → `read_uhdm` vs `read_slang` → SAT miter, checked
  against `tlul_modules.txt` (a shrink-only ratchet)
- `wrappers/flat_<module>.sv` — optional flat shim: when present, the runner tops
  at `<module>_flat` instead.  Used for `tlul_socket_1n`/`_m1`, whose
  unpacked-array-of-struct ports (`tl_d_o[N]`/`tl_d_i[N]`, `tl_h_i[M]`/`tl_h_o[M]`)
  are flattened by `read_uhdm` (elem0@LSB) and `read_slang` (elem0@MSB) in opposite
  element order — a pure flattening-convention difference, not a logic bug.  The
  shim wires each element explicitly so both frontends agree, and the socket
  datapath then proves equivalent.

- `scripts/tlul_cosim.py <module> [cycles]` — multi-clock Verilator co-sim
  (RTL vs read_uhdm vs read_slang).  Adjudicates modules the SAT miter cannot
  reach, notably the dual-clock CDC `tlul_fifo_async`: it auto-detects every
  `clk_*` / `rst_*_ni` port, drives each clock at a distinct period so the CDC
  actually crosses domains, and reports per-cycle divergence.

Status: 20 formally proven; `tlul_fifo_async` (dual-clock CDC) is beyond the
SAT `-seq` dual-clock limit but is **proven equivalent by co-sim**
(`scripts/tlul_cosim.py`, NO_DIVERGENCE over 400 cycles).  4 modules deferred
(need jtag/dmi/lc packages).  This suite runs in CI under the **Sweep pavona**
workflow (`core_sweep.py tlul`).  Refresh the RTL from an upstream checkout
with the top-level `vendor_pavona.sh` conventions.
