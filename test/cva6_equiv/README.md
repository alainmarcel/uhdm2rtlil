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

## Expectations

`cva6_modules.txt` lists each module with its BMC depth, timeout and expected
outcome:

| status | meaning |
| --- | --- |
| `proven` | SAT proves the miter unsatisfiable to the given depth. The goal. |
| `cex` | A real counterexample survives — a frontend bug still to fix. |
| `timeout` | SAT capacity, **not** a known bug: no model found within budget. |
| `elabfail` | The *wrapper* does not elaborate yet — a harness gap. |

Treat the non-`proven` entries as a shrink-only backlog: a module that starts
proving should be promoted in the same commit, and a module that stops proving
is a regression to investigate, never to downgrade.

`timeout` deserves care. It means the miter found **no** counterexample, only
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
