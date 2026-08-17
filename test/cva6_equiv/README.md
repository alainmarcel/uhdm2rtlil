# CVA6 per-module formal equivalence

Proves, module by module, that the UHDM frontend (`read_uhdm`) and the
SystemVerilog reference frontend built into this Yosys (`read_slang`) produce
equivalent hardware for the [CVA6](https://github.com/openhwgroup/cva6) core.

This is part of the regular regression, not a side flow:

```bash
make test-cva6            # this suite only
make test-all             # internal + upstream-Yosys + this suite
cd test && ./run_all_tests.sh --cva6            # same as make test-cva6
cd test && ./run_all_tests.sh --cva6 alu        # one module
cd test && ./run_all_tests.sh --all --no-cva6   # opt out
```

A regression here fails the whole suite.

## Why per-module, and why a wrapper

Reading all of CVA6 and mitering it in one piece is not tractable for SAT, and
a bug in one unit would be buried. Instead each module is proved on its own —
but a module proved with *default* parameters proves nothing about the design
that actually ships, because CVA6 is configured almost entirely through the
`CVA6Cfg` struct and a raft of `parameter type`s.

So `wrappers/wrapper_<mod>.sv` reproduces the parameter environment the module
really sees in `cva6.sv`: the `build_config()`-computed `CVA6Cfg`, the shared
type parameters, and `cva6.sv`'s body localparams, all copied verbatim. The
wrapper mirrors the module's port list and instantiates it with same-name
parameter bindings. `wrappers/extras_<mod>.svh`, when present, supplies types
that are local to the module's *parent* rather than to `cva6.sv` (for example
`frontend.sv`'s `ras_t`); those are injected into the wrapper's parameter block
because the port list needs them.

The generator also re-declares the target's **own** `#()` parameters when
nothing else supplies them. Generic library modules parameterise their ports
(`hpdcache_fifo_reg #(parameter int WIDTH = 8) (input logic [WIDTH-1:0] …)`),
and since the port list is copied verbatim those names must be declared before
it — otherwise slang reports `use of undeclared identifier 'WIDTH'`. Names that
cva6.sv or an `extras_*.svh` provides always win, so the real hierarchy's values
are never shadowed by a module's own default.

Regenerate a wrapper after a CVA6 update with:

```bash
python3 scripts/gen_wrapper.py <module>
```

It prints which parameters it bound and which kept their defaults — check the
kept-default list against the real instantiation site.

## Vendored RTL

`rtl/` holds exactly the sources the flow needs (~4 MB), and `cva6.flist`
refers to them through a `__CVA6_RTL__` placeholder that the runner
substitutes, so nothing depends on a checkout outside this repository.
`CVA6_VERSION` records the upstream revision.

To follow CVA6 as it evolves:

```bash
./vendor_cva6.sh ~/cva6                 # re-copy from a CVA6 working tree
./vendor_cva6.sh ~/cva6 path/to.flist   # ... using a specific file list
make test-cva6                          # then re-run and update expectations
```

Anything whose status changes should be updated in `cva6_modules.txt` in the
same commit as the refresh.

## In CI

A full pass does not fit one GitHub runner's budget — a single job gets
SIGTERM'd part-way through — so `.github/workflows/cva6-equiv.yml` builds once
and fans the module list across 8 shards, then merges the per-shard result
files into one report:

```bash
./run_cva6_equiv.sh --shard 3/8 --results shard3.txt   # what a shard runs
python3 scripts/combine_report.py shards/              # what combine runs
```

The combine step counts the shards it received and flags the report as PARTIAL
if any are missing, because a killed shard cannot upload its results and the
merged numbers would otherwise look complete.

The main CI job therefore runs `run_all_tests.sh --all --no-cva6`; this suite
covers CVA6 on the same push/PR events. `make test-all` still includes it
locally.

## Expectations

`cva6_modules.txt` lists each module with its BMC depth, timeout and expected
outcome:

| status | meaning |
| --- | --- |
| `proven` | SAT proves the miter unsatisfiable to the given depth. The goal. |
| `cex` | A real counterexample survives — a frontend bug still to fix. |
| `timeout` | SAT capacity, **not** a known bug: no model found within budget. |
| `crash` | yosys itself died on the miter (SIGSEGV/SIGFPE) — a real problem, not a budget outcome. |
| `elabfail` | The *wrapper* does not elaborate yet — a harness gap. |

Treat the non-`proven` entries as a shrink-only backlog: a module that starts
proving should be promoted in the same commit, and a module that stops proving
is a regression to investigate, never to downgrade.

A slow-elaborating module can be misfiled as `timeout` when the budget is
tight: the classifier only sees that no model was produced. `wt_dcache` and
`wt_cache_subsystem` were recorded as `timeout` from a 150 s sweep and turned
out to be `elabfail` once given 400 s. When (re)classifying, give the sweep a
generous budget, or re-check anything new that lands on `timeout`.

`crash` and `timeout` are easy to confuse and must not be. When the classifier
was first written it lumped both together, and 21 modules that actually
segfault yosys sat quietly under `timeout` looking like harmless SAT capacity.
A non-zero exit that is not the timeout's own signal is now reported as
`crash`, and an unexpected crash fails the suite.

`timeout` deserves care too. It means the miter found **no** counterexample, only
that it ran out of budget — every divergence ever found in those modules was
fixed. `cva6_ptw` is the extreme case at 4233 cells: it proves at depth 1 and
additionally passes a 20,000-cycle randomised co-simulation with zero
mismatches, but deeper BMC does not finish.

## Triage tools

When a module reports `cex`, these turn the counterexample into a diagnosis:

- `scripts/gen_replay.py <mod>` — writes both netlists to Verilog, builds a
  testbench that applies the counterexample cycle by cycle to both, and prints
  the first differing output. Add `$dumpvars` and diff the VCDs to find the
  first differing *internal* signal, which is usually the actual root.
- `scripts/long_cosim.py <mod> [cycles] [seed]` — random co-simulation of the
  two netlists over many thousands of cycles, reporting mismatches and an
  activity count so a quiet pass cannot masquerade as a result. This is the
  right instrument when SAT will not scale.
- `scripts/triage_module.py <mod>` — combinational evaluation of a
  counterexample (blind to sequential state).

One hard-won rule: **the miter says the two frontends differ, not which one is
wrong.** Before changing the UHDM frontend, adjudicate the disputed vectors
against an independent simulator — instantiate the UHDM netlist next to the
behavioural RTL under `iverilog` and compare. That check has repeatedly shown
the UHDM side to be correct and the other side at fault, and it is what keeps
this suite from encoding someone else's bug as our expectation.
