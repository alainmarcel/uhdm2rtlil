# Caliptra full-chip equivalence (caliptra_top)

Whole-chip check of the UHDM frontend against
[chipsalliance/caliptra-rtl](https://github.com/chipsalliance/caliptra-rtl),
the same way `test/pavona_chips` checks the Pavona tops.

Surelog elaborates the chip, `read_uhdm` imports it and `read_slang
--keep-hierarchy` elaborates the same sources; every DIRECT instance of
`caliptra_top` is then paired between the two netlists and SAT-mitered from
reset (`scripts/chip_flow.py`).  read_slang is the adjudication baseline: a
difference both frontends share is not a UHDM bug, one only `read_uhdm` shows
is.

## The flat wrapper

`caliptra_top` exposes six SystemVerilog **interface** ports — four `axi_if`
modports plus the VeeR (`el2_mem_if`) and ABR (`abr_mem_if`) memory exports.
read_slang refuses to elaborate a top-level module with an unconnected
interface port, and a miter or co-sim needs real ports anyway, so the flow runs
both frontends against a generated wrapper instead:

    scripts/gen_wrapper.py work/caliptra_top_bare.il work/caliptra_top_flat.sv

`gen_wrapper.py` takes the port widths from an RTLIL netlist of the bare chip
rather than re-parsing SystemVerilog, because that netlist is the one place
`axi_if`'s `AW`/`DW`/`IW`/`UW`, `el2_mem_if`'s `pt` parameter struct and
`abr_mem_if`'s macro-generated widths are all already resolved.  The result is
254 flat ports over 4 interface instances.  `chip_flow.py` regenerates it
automatically as its first pass.

## Sources

`srcs.txt` and `incs.txt` are the `caliptra_top.vf` file list (547 sources, 54
include directories) with the checkout root written as `${CALIPTRA}`:

| `.vf` variable | value |
| --- | --- |
| `CALIPTRA_ROOT` | the checkout |
| `CALIPTRA_PRIM_ROOT` | `$CALIPTRA_ROOT/src/caliptra_prim_generic` |
| `CALIPTRA_PRIM_MODULE_PREFIX` | `caliptra_prim_generic` |

`caliptra.commit` pins the upstream commit; `scripts/fetch_caliptra.sh` makes a
shallow clone at that commit into `caliptra-rtl/` (override with `$CALIPTRA`).

## Running

```bash
cd test/caliptra_chip
scripts/fetch_caliptra.sh                 # once
scripts/chip_flow.py                      # every common instance
scripts/chip_flow.py soc_ifc_top          # just one
SKIP_IMPORT=1 scripts/chip_flow.py …      # reuse work/*.il
```

`SEQ` (miter depth, default 2), `TIMEOUT`, `JOBS` and `MEMSIZE` (bounded RAM
depth) tune the run, as in the Pavona harness.

## Getting the chip to elaborate

Five fixes were needed before `caliptra_top` read cleanly (35 errors → 0);
they are listed in the campaign notes and shipped as
[Surelog #4179](https://github.com/chipsalliance/Surelog/pull/4179) (three
preprocessor fixes, each with its own Surelog test) plus two frontend fixes in
this repo.  Timings on the reference machine: Surelog parse 55 s, `read_uhdm`
of the bare chip 2:24 (327k cells, 867 modules, 172 top-level instances),
`read_uhdm` of the wrapper 2:51, `read_slang` of the wrapper 17 s.
