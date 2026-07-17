# Ibex RISC-V core — imported RTL

Source: https://github.com/lowRISC/ibex (commit `8ed87e0`), imported verbatim as
shared source for the per-module tests `test/ibex_<module>/`.

Layout (mirrors the upstream tree, flattened per dependency group):

- `rtl/`          — the Ibex core RTL (`ibex_*.sv`, incl. `ibex_pkg.sv`,
                    `ibex_tracer_pkg.sv`).  30 files.
- `prim/`         — lowRISC `prim` library from `vendor/lowrisc_ip/ip/prim/rtl/`
                    (packages, `prim_assert.sv` + `.svh` macro headers, and the
                    higher-level primitives).  Used via `-I../ibex/prim`.
- `prim_generic/` — the generic (technology-independent) primitive
                    implementations from `vendor/lowrisc_ip/ip/prim_generic/rtl/`
                    (`prim_buf`, `prim_flop`, `prim_clock_gating`, `prim_ram_1p`,
                    …), which define the plain `prim_*` module names.

## Per-module tests

Generated with the reusable `test/import_design.py`:

```
python3 test/import_design.py --design test/ibex --prefix ibex \
    --incdir ibex/prim --incdir ibex/rtl \
    --skip-glob '*/prim/*' --skip-glob '*/prim_generic/*'
```

This writes one `test/ibex_<module>/project.f` per synthesizable Ibex module (the
ordered package deps + the module + the `-I` include dirs); the `prim*` library is
skipped as a test *top* (it stays available as submodule dependencies).  Each
module is elaborated in isolation — instantiated submodules it does not list are
treated as blackboxes — and checked the same way as the rest of the suite (formal
equivalence where the Yosys Verilog frontend can read the source, else UHDM-only
Verilator co-simulation against the RTL).
