# Pavona full-chip equivalence (top_egret, top_dragonfly)

Whole-chip check of the UHDM frontend against the Pavona OpenTitan-family
tops, run nightly by the `pavona - egret` / `pavona - dragonfly` jobs of
`.github/workflows/sweep-pavona.yml` (via `test/core_sweep.py egret|dragonfly`).

Two independent checks per chip:

1. **Per-instance formal.** Surelog elaborates the top, `read_uhdm` imports it
   and `read_slang --keep-hierarchy` elaborates the same sources.  Every DIRECT
   instance of the top is paired between the two netlists and SAT-mitered from
   reset (`scripts/chip_flow.py`).  47 instances for Egret, 51 for Dragonfly.
2. **Full-chip co-sim.** The behavioural RTL, the `read_uhdm` netlist and the
   `read_slang` netlist run in Verilator under one generated testbench with
   identical pseudo-random pad stimulus; all top-level outputs are compared
   every cycle (`scripts/chip_cosim.py`).  read_slang is the baseline: a
   divergence both netlists share is a netlist-simulation artefact, one only
   read_uhdm shows is a frontend bug.

## Sources

`<chip>/srcs.txt` and `<chip>/incs.txt` are the fusesoc file list (generated
with `scripts/eda_srcs.py` from the `syn-icarus` EDA description), with the
Pavona checkout root written as `${PAVONA}`.  `pavona.commit` pins the
upstream commit; `scripts/fetch_pavona.sh` makes a sparse clone of `hw/`.
Set `PAVONA=<checkout>` to use a local one.

## Running locally

```bash
export PAVONA=/path/to/pavona
python3 scripts/chip_flow.py egret         # elaborate + per-instance miters
python3 scripts/chip_cosim.py egret 2000   # full-chip co-sim, 2000 cycles
```

`SKIP_IMPORT=1` reuses `work/<chip>/*.il`; `JOBS`, `SEQ`, `TIMEOUT` and
`MEMSIZE` tune the miters.  Both scripts write under `work/<chip>/`
(git-ignored).

## Bugs this found

- `rstmgr_por`'s `rst_filter_n[0 +: FilterStages-1]` folded to an empty slice
  for a child imported from inside the parent's generate scope: the chip never
  released its power-on reset.
- pinmux's power-on pad attributes `'{pull_en: 1'b1, default: '0}` were written
  as a single bit, so the TAP strap sampled without its pull-down.

Both were invisible to the per-instance miters (bounded at 2 steps from reset)
and to the smaller per-IP campaigns; the full-chip co-sim caught them.
