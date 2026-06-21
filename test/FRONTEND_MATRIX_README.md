# 4-Frontend Regression Matrix

Runs every test through **four** SystemVerilog/Verilog frontends, then classifies,
per (test, frontend): **did it synthesize?** and **is the result correct?**

| Key | Tool | Read step |
|-----|------|-----------|
| `verilog` | Yosys native | `read_verilog` — also the golden reference |
| `uhdm` | this plugin | Surelog → `read_uhdm` |
| `sv2v` | [zachjs/sv2v](https://github.com/zachjs/sv2v) | `sv2v src… > out.v` → `read_verilog` |
| `slang` | [povik/yosys-slang](https://github.com/povik/yosys-slang) | `read_slang src…` |

Only the *read* step differs; the synthesis tail
(`hierarchy -check -auto-top; proc; opt; synth -auto-top; write_verilog -noexpr`)
is identical for all four, so each frontend produces a `<name>_from_<f>_synth.v`
that the shared correctness machinery treats uniformly.

## Build the external tools (one-time)

```bash
make                 # normal repo build first (needs out/current/bin/yosys-config)
make frontends       # clone + build sv2v and yosys-slang into build/frontends/
```

`build_frontends.sh` is idempotent (`--force` to rebuild). It builds:
- **sv2v** from source via Haskell Stack → `build/frontends/sv2v/bin/sv2v`.
  If the source build can't link (GHC/libgmp toolchain issues on hosts without
  `libgmp-dev`), it automatically falls back to the upstream **prebuilt** static
  Linux release binary.
- **yosys-slang** via CMake against *this repo's* Yosys
  (`out/current/bin/yosys-config`, passed as `YOSYS_PREFIX`) →
  `build/frontends/yosys-slang/build/slang.so`, symlinked to `build/slang.so`.

Cloned commits are recorded in `build/frontends/versions.txt`.

## Run the matrix

```bash
cd test
python3 run_frontend_matrix.py                 # internal tests (test/*)
python3 run_frontend_matrix.py --yosys          # upstream Yosys tests
python3 run_frontend_matrix.py --all            # both
python3 run_frontend_matrix.py simple_counter   # name/path substring filter
python3 run_frontend_matrix.py --jobs 8 --cycles 200
python3 run_frontend_matrix.py --no-cosim       # formal equivalence only (faster)
python3 run_frontend_matrix.py --frontends uhdm,slang   # correctness-check a subset
# or: make test-matrix
```

Outputs (in `test/`):
- `frontend_matrix.csv` — one row per test, `<f>_synth` + `<f>_correct` per frontend.
- `FRONTEND_MATRIX.md` — leaderboard + a **Disagreements** section (tests where one
  frontend is `INCORRECT` while another is `CORRECT` — the best triage list).

## Classification

**Synthesized** (`<f>_synth`), from `frontend_status.txt`:

| token | meaning |
|-------|---------|
| `yes` | read + synth OK, >0 logic gates |
| `empty` | synth OK but 0 gates (const-only design) |
| `no` | read or synth failed (`READ_FAIL`/`SYNTH_FAIL`/`CONVERT_FAIL`) |
| `crash` | tool crashed (exit ≥ 128) |
| `missing` | the tool/plugin isn't built |

**Correct** (`<f>_correct`) — two oracles, both reused from the existing harness:
1. **Formal** — `equiv_pair.sh` compares the frontend's netlist against the
   `verilog` golden netlist: const-value compare → `equiv_induct` →
   SAT-from-reset miter fallback.
2. **Co-sim** — `test_sim_equivalence.py --frontend <f>` Verilator-simulates the
   frontend's netlist against the original RTL.

Verdict:

| verdict | condition |
|---------|-----------|
| `CORRECT` | formal proves equivalent, or (formal N/A) and co-sim passes; `verilog` is correct unless its own co-sim fails |
| `INCORRECT` | formal finds a counterexample, or co-sim mismatches |
| `UNKNOWN` | no golden (native verilog couldn't read the SV) **and** co-sim could not run |
| `N/A` | the frontend did not synthesize |

When the native `verilog` frontend can't read a SystemVerilog construct, there is
no golden for formal equivalence; correctness then rests on co-sim-vs-RTL, and is
`UNKNOWN` if Verilator also can't build it. This is exactly the case the matrix is
built to surface (where `uhdm`/`slang`/`sv2v` succeed and `verilog` does not).

## Components

| File | Role |
|------|------|
| `build_frontends.sh` | clone + build sv2v and yosys-slang |
| `frontend_matrix_workflow.sh` | run all 4 frontends → netlists + `frontend_status.txt` |
| `equiv_pair.sh` + `equiv_chtype.ys` | formal equivalence of any two netlists |
| `test_sim_equivalence.py --frontend` | Verilator co-sim of a chosen frontend's netlist |
| `cosim_netlist.py` | thin wrapper over the above |
| `materialize_yosys_tests.sh` | stage upstream Yosys tests under `test/run/**` |
| `run_frontend_matrix.py` | orchestrator + CSV/Markdown report |

The existing `run_all_tests.sh` (UHDM-vs-Verilog CI) is left untouched.
