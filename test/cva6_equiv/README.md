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

A parameter's own default is the last thing the generator wants. Defaults exist
to keep a file standalone-parsable, not to describe the design: `parameter type
axi_req_t = logic` makes every field access illegal, and
`hpdcache_data_downsize`'s `DEPTH = 0` trips the module's own `$fatal`. So for
each parameter the generator asks, in order:

1. **What does the instantiation site bind?** `cva6.sv` says
   `.axi_req_t(noc_req_t)`, which same-name binding can never find. One level up
   is rarely enough — `axi_shim` is given `.axi_req_t(axi_req_t)` by
   `std_nbdcache`, whose own `axi_req_t` is filled in further up — so the walk
   continues until the name lands on something real.
2. **Is it an ancestor's localparam?** Then inline that definition, along with
   the ancestor types and parameters it references (`dcache_rtrn_t` embeds
   `dcache_inval_t`; `registers_t` is sized by its ancestor's `XLEN`).
3. **Does a helper package supply it?** See below.
4. Otherwise keep the default and report it as kept-default.

The generator also re-declares the target's **own** `#()` parameters when
nothing else supplies them. Generic library modules parameterise their ports
(`hpdcache_fifo_reg #(parameter int WIDTH = 8) (input logic [WIDTH-1:0] …)`),
and since the port list is copied verbatim those names must be declared before
it — otherwise slang reports `use of undeclared identifier 'WIDTH'`. Names that
cva6.sv or an `extras_*.svh` provides always win, so the real hierarchy's values
are never shadowed by a module's own default.

### Helper packages

Some parameters cannot be resolved by walking the hierarchy at all. The whole
hpdcache family is parameterised by types that `cva6_hpdcache_subsystem` builds
with `HPDCACHE_TYPEDEF_*` macros **inside its module body**, which a wrapper
cannot reach into — so those modules ran on `parameter type hpdcache_req_t =
logic` and an all-zero `HPDcacheCfg`, and reported a scatter of symptoms
(illegal field accesses, unindexable scalars, zero-width selects, the design's
own `$fatal`) that all traced back to that one gap.

`wrappers/hpdcache_equiv_pkg.svh` re-emits that environment as a package, and
any name it declares is offered to any wrapper that needs it. It is generated
rather than hand-copied, so it follows CVA6:

```bash
python3 scripts/gen_hpdcache_pkg.py     # after ./vendor_cva6.sh
```

Drop another `*.svh` containing a `package` into `wrappers/` and its names join
the pool the same way.

Regenerate a wrapper after a CVA6 update with:

```bash
python3 scripts/gen_wrapper.py <module>
```

It prints which parameters it bound and which kept their defaults — check the
kept-default list against the real instantiation site.

After regenerating in bulk, **diff the instantiation bindings against the
previous wrappers**, not just the file text. A generator change can silently
swap a real value for a module's default, and the symptom is not a failure: the
module still elaborates and still proves, it just proves a *different, usually
bigger* design — `bht` with `NR_ENTRIES = 1024` instead of
`CVA6Cfg.BHTEntries` stopped fitting its SAT budget and looked like a
load-related `timeout`. A binding may legitimately move from `.X(expr)` into a
`parameter X = expr` declaration; what must never change is the value.

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

Not every `elabfail` is a harness gap we can close. Five modules use system
tasks the reference frontend does not implement (`$random` in
`ariane_regfile_fpga`; `$onehot0` in the cvxif example decoders and, via
`hpdcache_rrarb`, the `hwpf_stride` pair), so there is no reference netlist to
miter against. Two more (`control_mvp`, `preprocess_mvp`) declare their ports
non-ANSI, which the port-list-copying wrapper cannot mirror. Those are marked
with a comment in `cva6_modules.txt` rather than re-triaged each round.

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
