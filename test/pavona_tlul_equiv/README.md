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

Status: 6 proven, 4 cex (integrity ECC path), 11 SAT-timeout.  4 modules deferred
(need jtag/dmi/lc packages).  Refresh the RTL from an upstream checkout with the
top-level `vendor_pavona.sh` conventions.
