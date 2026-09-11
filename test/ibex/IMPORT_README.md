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
- `dv/`           — `dv_fcov_macros.svh` from
                    `vendor/lowrisc_ip/dv/sv/dv_utils/`.  Several Ibex modules
                    (`ibex_core`, `ibex_id_stage`, `ibex_pmp`, …) unconditionally
                    `` `include "dv_fcov_macros.svh" `` for functional-coverage
                    macros.  The file no-ops those macros for synthesis (its own
                    `` `ifdef SYNTHESIS `` → `DV_FCOV_DISABLE`); the frontend
                    defines `SYNTHESIS`, so the coverage regions are excluded.
                    Used via `-I../ibex/dv`.

## Per-module tests

Generated with the reusable `test/import_design.py`:

```
python3 test/import_design.py --design test/ibex --prefix ibex \
    --incdir ibex/prim --incdir ibex/rtl --incdir ibex/dv \
    --skip-glob '*/prim/*' --skip-glob '*/prim_generic/*' \
    --verilator=--no-assert --module-define ibex_top_tracing:RVFI
```

This writes one `test/ibex_<module>/project.f` per synthesizable Ibex module.
Each project.f lists, in order: the package deps (from both `import pkg::*` AND
`pkg::name` scope references), then the module **and the full transitive set of
submodules it instantiates** — so a parent module (`ibex_core`, `ibex_if_stage`,
`ibex_top`, `ibex_lockstep`, ...) elaborates completely instead of treating its
children as blackboxes, and can be formally mitered against `read_slang` and
co-simulated.  The `prim*` library is skipped as a test *top* (`--skip-glob`) but
is still pulled in as a submodule **dependency**.  `--module-define` adds a
per-module define (`ibex_top_tracing` fatals without `RVFI`).

A few parents still can't be slang-mitered — `ibex_top` / `ibex_tracer` /
`ibex_top_tracing` use the lowRISC `logic unused_x = <net>;` lint-sink pattern,
which `read_slang` rejects ("reading net state during design initialization
unsupported") — so the sweep labels those `slang net-init` and falls back to the
UHDM-vs-RTL co-sim.  Modules the Yosys Verilog frontend can otherwise read are
checked by formal equivalence; the rest by Verilator co-simulation.
