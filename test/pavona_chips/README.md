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
3. **Per-instance co-sim.** Every direct instance is also co-simulated on its
   own (`test/netlist_cosim.py`, run by `core_sweep.py egret|dragonfly`): its
   `read_uhdm` and `read_slang` netlists (from the split in step 1) vs the RTL
   module rebuilt with the instance's parameters (from the RTLIL paramod name
   `chip_flow.py` records in `work/<chip>/inst/instances.json`), so the
   report's co-sim and slang-baseline columns are filled for the instances as
   well as the top.  A `0 active` pass is vacuous; enum-typed parameters are
   cast, localparams stamped into the paramod name are dropped, and type
   parameters or interface-member ports make a row say `skip` rather than
   report a pass that never ran.

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
- pinmux_strap_sampling's `attr_padring_o[k] = jtag_en ? '{schmitt_en: 1'b1,
  default: '0} : attr_core_i[k]` folded the pattern to all-zeros: a pattern
  that is an arm of a conditional operator has the `?:` as its parent, and the
  element-selected port net carries its packed-struct-array typespec on the
  port, not the net (found by the per-instance co-sim of `u_pinmux_aon`,
  `mio_attr_o` bit 5 from cycle 26).

Both were invisible to the per-instance miters (bounded at 2 steps from reset)
and to the smaller per-IP campaigns; the full-chip co-sim caught them.
