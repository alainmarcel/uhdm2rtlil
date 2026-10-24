# Benchmarking against the reference frontends

`read_uhdm` is measured against `read_slang` (Yosys's built-in sv-elab
frontend) on every design the nightly sweeps touch, and against `sv2v` and
the native `read_verilog` on the test corpus -- the same designs, the same
checks, the same random stimulus.  The headline numbers are in the
[README](../README.md#supported-core-ip); this page is the full account: the
per-core co-simulation table, the reference frontend's own record, and the
4-frontend matrix.  Every figure is produced by a script over the run
artifacts named here, not kept by hand.

## Nightly sweeps: co-simulation per core, `read_slang` vs `read_uhdm`

Every sweep row co-simulates **both** netlists against the same RTL under the
same random stimulus, so the reference frontend is measured by the same yardstick
as this one.  The columns are disjoint counts and the arithmetic holds on every
line and in the total:

- *co-simulated* = rows whose netlist got a Verilator run at all;
  **Rows − co-simulated** = rows with no co-sim for that netlist (no ports — 514
  of the 526 sv-tests snippets — no buildable testbench, no default
  elaboration, or a formal-only instantiation row).
- `read_slang`: **co-simulated = pass + diverge + artefact / no oracle**, counted
  the same way as ours: *artefact* is a row where BOTH netlists diverge from the
  RTL identically (or the miter adjudicates the divergence), *no oracle* a row
  whose RTL is inert under Verilator -- neither is a verdict on slang -- and
  **diverge** is a row where our netlist tracks the RTL and slang's does not:
  the "bug" class of [slang_unsupported.md](slang_unsupported.md), row for row.
- `read_uhdm`: **co-simulated = pass + diverge + artefact**, where *artefact* is
  a divergence a SAT miter proved to be a simulation artefact (X-semantics,
  unique/priority-case violation stimulus), not a reader defect, and
  **diverge** is a real one.
- The rows are the rows of the README's [Supported Core IP](../README.md#supported-core-ip)
  table, in its order (the sweep links are there); the XiangShan library has its own row, so the
  External IP row is the other 10 repos and every column sums to its total.
  The script asserts both identities before printing.

| Core | Rows | Formal proven | `read_slang` co-simulated | pass | **diverge** | artefact / no oracle | `read_uhdm` co-simulated | pass | **diverge** | artefact | Undriven |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **Ibex** | 28 | 22 | 23 | 20 | 0 | 3 | 24 | 20 | 0 | 4 | 0 |
| **rp32 (R5P)** | 13 | 6 | 5 | 2 | 0 | 3 | 7 | 3 | 0 | 4 | 0 |
| **fx68k** | 22 | 18 | 12 | 6 | 0 | 6 | 10 | 6 | 0 | 4 | 0 |
| **Syntacore SCR1** | 37 | 29 | 32 | 32 | 0 | 0 | 32 | 32 | 0 | 0 | 0 |
| **RgGen** | 25 | 25 | 25 | 25 | 0 | 0 | 25 | 25 | 0 | 0 | 0 |
| **VeeR EH1** | 67 | 55 | 66 | 66 | 0 | 0 | 66 | 66 | 0 | 0 | 0 |
| **TNoC** | 43 | 16 | 12 | 12 | 0 | 0 | 12 | 12 | 0 | 0 | 0 |
| **VeeR EL2** | 91 | 76 | 86 | 86 | 0 | 0 | 87 | 87 | 0 | 0 | 0 |
| **RSD** | 165 | 118 | 144 | 140 | **3** | 1 | 147 | 146 | 0 | 1 | 0 |
| **BlackParrot** | 125 | 50 | 45 | 42 | **2** | 1 | 45 | 44 | 0 | 1 | 0 |
| **OpenTitan** (upstream) | 32 | 28 | 29 | 27 | **1** | 1 | 29 | 28 | 0 | 1 | 0 |
| **OpenTitan IP library** (upstream, the other 44 blocks) | 605 | 525 | 551 | 539 | **6** | 6 | 551 | 544 | **3** | 4 | 0 |
| **Pavona** (300 modules + 100 chip instances) | 400 | 381 | 390 | 379 | **2** | 9 | 390 | 381 | 0 | 9 | 0 |
| **Ariane CVA6** (142 modules + 138 core instantiations, the latter formal-only) | 280 | 227 | 135 | 124 | **2** | 9 | 135 | 126 | 0 | 9 | 0 |
| **Ariane CVA6 flavours** (the three other sv-tests configurations: HPDcache, H-extension, RV32) | 429 | 301 | 402 | 365 | **9** | 28 | 402 | 372 | **2** | 28 | 0 |
| **Caliptra** | 22 | 19 | 21 | 21 | 0 | 0 | 21 | 21 | 0 | 0 | 0 |
| **XiangShan** (香山) | 21 | 19 | 21 | 21 | 0 | 0 | 21 | 21 | 0 | 0 | 0 |
| **XiangShan core** (香山) | 2002 | 1612 | 1943 | 1940 | **3** | 0 | 1944 | 1944 | 0 | 0 | 0 |
| **External IP** (the other 10 repos; the XiangShan library is the row above) | 1023 | 864 | 893 | 863 | **6** | 24 | 913 | 889 | 0 | 24 | 0 |
| **chipsalliance/sv-tests** | 527 | 474 | 11 | 11 | 0 | 0 | 12 | 11 | 0 | 1 | 0 |
| **All sweeps** (18 workflows) | **5957** | **4865** | **4846** | **4721** | **34** | **91** | **4873** | **4778** | **5** | **90** | **0** |

**Five `read_uhdm` divergences remained in the 2026-10-23 nightlies, all
closed since**: 4778 of the 4873 co-simulated rows pass outright, 90 are
divergences a SAT miter proved to be simulation artefacts, and the five real
ones were `cva6_hpdcache_subsystem` (2 diverging cycles) and
`cva6_hpdcache_wrapper` (3) at the HPDcache flavour of CVA6 -- three
type-parameter folds, two of them Surelog's (#1293, #1294, the bump #1295
carrying chipsalliance/UHDM#1167 and Surelog#4222 / #4223), both rows
NO_DIVERGENCE on re-measure -- and three rows of the OpenTitan IP library
(`aes_control` 301, `i3c_ctrl_req_gen` 1, `rram_ctrl_mp` 1): `aes_control`
was the flat shim's port width plus a one-bit element read (#1296, #1297,
now equivalent and PASS), the two one-bit rows are enum inputs driven to
encodings their `case` never lists, adjudicated in the manifest (#1298).  The
seven other first-nightly divergences of that library were fixed the day
before (#1270, #1275, #1276, #1282, #1283, #1284).  `read_slang`, measured on
the same rows under the same stimulus, diverges on 34 of its own (81 more
rows are divergences both netlists share, 6 the miter adjudicated, 4 have no
oracle).

The `read_slang` divergences are listed with their reasons in
[slang_unsupported.md](slang_unsupported.md).  Counted by
[`test/sweep_table.py`](../test/sweep_table.py) over the reports of the runs
below.

### Provenance

The numbers are the **2026-10-23 nightly runs**, one per sweep workflow, 18
workflows, on main at `63a2be657` or the commits just before it (the morning
of the day the HPDcache and aes_control fixes merged, so those five rows still
show their divergences above).  Two rows are not from that morning:
**BlackParrot is its 2026-10-18 run** on `52374ad92` (its nightly has been
cancelled on the job time limit every day since, and a cancelled run uploads a
TRUNCATED report), and **sv-tests is the 2026-10-24 dispatch** on `7c48107d7`.
Run ids: ibex 39918341671, rp32 39921164212, fx68k 39956673196, scr1
39920781723, rggen 39961951399, veer-eh1 39927241179, tnoc 39963887093,
veer-el2 39939130087, rsd 39932369061, black-parrot 39126191261, opentitan
39950413357, ext (External IP + OpenTitan IP library) 39927547137, pavona
39927582293, cva6 39925100536, cva6-flavours 39932545158, caliptra
39936446928, xiangshan-core 39933201376, sv-tests 40058509055.

### Formal-only `differs` rows that are adjudicated non-defects

- **CVA6's 5 `differs` rows are adjudicated non-defects**, each re-checked on
  2026-10-19 against its own counterexample: `hpdcache_cmo` is a
  **unique-case violation** (the solver sets `is_flush_by_nline`,
  `is_flush_all` and `is_fence` at once, so two arms of
  `unique case (1'b1)` match and either lowering is licensed);
  `hpdcache_uncached` is **unprovable by construction** -- the differing bit
  is in `mem_req_atomic`, which that `always_comb` never assigns on the path
  taken, and BOTH netlists then hold it through the same combinational
  self-hold, which SAT reads as two independent free values;
  `csr_regfile` is an **init-state** difference, because we fold `dcsr`'s
  reset-only `xdebugver` field to a constant while `read_slang` keeps a flop
  and the miter's `-set-init-zero` pins both initial states to 0;
  `macro_decoder` and `zcmt_decoder` are **latch-vs-self-feedback** -- we
  infer a latch for a comb variable the source leaves unassigned on the
  illegal-instruction path (22 and 5 of them) where `read_slang` builds a
  combinational loop SAT treats as free.  Every undriven row is a net the
  source never assigns, which the sweeps tell apart from a dropped driver.
- **Still open on our side:** the sweep rows where `read_slang` tracks the RTL and
  we do not are listed, in the same format as slang's own failures, in the "other
  direction" section of [docs/slang_unsupported.md](docs/slang_unsupported.md).
- CVA6 is the one family excluded from the local `--no-cva6` developer run, so
  read the nightly rather than a local run for its figures.

## The reference frontend's own record

**How the reference frontend itself does.** The left-most column of every sweep
table co-simulates the `read_slang` netlist against the same RTL, so the sweeps
also measure the frontend they compare against.  Every row where it does not
track the RTL -- and every design it cannot read at all, in the sweeps, in the
local test suite and in the upstream Yosys tests -- is collected in ONE report,
[slang_unsupported.md](slang_unsupported.md): one format (reason, link
to the test, recipe to reproduce), the recipes described up front.  Rows the
harness could not give slang a fair run on (a module no file of the test defines,
a test invalid on purpose, a design no frontend elaborates, a co-sim both netlists
fail identically) are in [incomplete_testcases.md](incomplete_testcases.md)
with a statement of which frontends fail on them.  The same report lists the
**other direction** -- rows where `read_slang` is clean and OURS is wrong --
because a document that can only record another tool's mistakes is not a
measurement.

**What the reference frontend cannot read.** 146 sweep rows carry
`no reference (read_slang fails)` -- `read_slang` cannot elaborate the module,
so there is nothing for the miter or the co-sim to judge us against -- and of
the 125 rows where it does build a netlist that diverges from the RTL (the
*diverge* and *artefact / no oracle* columns of the table above), **34 are
rows ours passes outright**.
The other 91 are rows where both netlists diverge
and a miter has adjudicated ours as the same simulation artefact, which is the
shared-divergence class rather than a verdict on either frontend.  Every one of
these is in [slang_unsupported.md](slang_unsupported.md) with the
reason, a link to the module's source and the recipe that reproduces it, next
to the local and upstream tests slang cannot read.  Rows that carry no verdict
for either side -- a design neither frontend elaborates, a co-sim both netlists
fail identically, a testbench Verilator could not build -- sit in
[incomplete_testcases.md](incomplete_testcases.md) with a statement of
which frontends fail on them.  Most of what used to be counted as unreadable was the harness, not slang
(a configuration the design forbids at its defaults, a withheld package or
macro, an unwrapped interface port, an unroll limit, a header never vendored),
and is excluded rather than scored.

## The 4-frontend matrix: `uhdm`, `sv2v`, `slang`, `verilog`

The 4-frontend regression matrix (`make test-matrix`, run nightly) synthesizes
every test's SystemVerilog through **four** frontends and ranks them by how much
SV each handles **correctly**. Every netlist is verified either by **formal
equivalence** — Yosys `equiv_induct` plus a sound SAT-from-reset miter, against
the Yosys Verilog-frontend golden — **and/or** by **high-activity randomized
Verilator co-simulation** against the original RTL. A result counts as *Correct*
only when one of those checks proves it equivalent; *SV-only* means the frontend
synthesized SystemVerilog that the native Verilog frontend cannot even read (no
golden to compare against, so it is verified against the RTL by co-simulation).

The nightly run
([Frontend Matrix](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml),
1822 tests) reports two things separately: what each frontend could **read**,
and — where a `read_verilog` golden exists to compare against — whether it was
**right**.

| Frontend | Read | Failed to read | Correct | Incorrect | No golden | Unknown |
|---|---:|---:|---:|---:|---:|---:|
| **`uhdm`** (this project) | **1792** | 33 | 1044 | 24 | 654 | 67 |
| `sv2v` | 1610 | 213 | 992 | 0 | 546 | 71 |
| `slang` (Yosys sv-elab) | 1545 | 277 | 845 | 0 | 569 | 131 |
| `verilog` (Yosys native, the golden) | 1091 | 731 | 1091 | 0 | — | 0 |

*Failed to read* = failed + crashed + timed out + out-of-memory.  *No golden* = this
frontend synthesized but `read_verilog` could not, so there is nothing to
compare against — a capability win, verified against the RTL by co-simulation
rather than formally.  *Unknown* = formal non-equivalence the co-sim could not
adjudicate.

On this corpus the UHDM frontend reads the most SystemVerilog — **1792 of 1822**,
including **654 designs the native Verilog frontend cannot read at all**.

**How to read this table honestly:**

- **It is a self-run benchmark on a largely self-authored corpus.** The matrix is
  mostly this project's own test suite (plus imported Yosys and
  chipsalliance/UHDM-integration tests), and many tests were added specifically to
  exercise constructs this frontend targets. The ranking is real but it is *not* a
  neutral third-party comparison — a tool graded on the set its authors curated is
  playing at home. Read "#1 by ~10 points" in that light.
- **The benchmark rewards breadth over conservatism.** `sv2v` and `slang` report
  **0 incorrect** results here; `uhdm`'s **24** are a real (tracked) triage backlog
  in `test/failing_tests.txt`. Ranking by how much is read favors breadth, but
  "accepts less yet is never wrong on what it accepts" is a legitimate — sometimes
  preferable — posture, and it's the one `sv2v`/`slang` show on this corpus. Their
  higher "Failed to read" counts (213 / 277 vs 33) reflect that trade-off, not a
  defect.
- **Coverage ≠ ecosystem fit.** `slang`/sv-elab is the frontend that has been
  **upstreamed into Yosys itself**, ships in the OSS CAD Suite, and is used by
  OpenROAD — adoption, integration, and maintenance advantages a nightly coverage
  count does not capture. If your criterion is *maximum SV coverage through the
  Surelog/UHDM path today*, this table favors `uhdm`; if it is *what is maintained
  and integrated for production*, sv-elab has the stronger case. Both can be true.

`verilog` is the golden reference, so it has no *SV-only* column and its ceiling is
the SV subset it can parse. Numbers are from one nightly run and drift between runs
(seq-equiv induction is inductively incomplete on some designs) — treat any single
figure as approximate.

The 24 `uhdm` *Incorrect* tests are what remains of the 349 DUTs imported from
[chipsalliance/UHDM-integration-tests](https://github.com/chipsalliance/UHDM-integration-tests)
(`test/<Name>/dut.sv`); they are tracked in `test/failing_tests.txt`.

## Related reports

- Everything `read_slang` cannot read or gets wrong -- across the sweeps, the
  internal tests and the generated upstream Yosys tests, with reproduce recipes
  -- and the rows where it is right and `read_uhdm` is wrong →
  [slang_unsupported.md](slang_unsupported.md)
- Tests no frontend can be judged on → [incomplete_testcases.md](incomplete_testcases.md)
- chipsalliance/sv-tests, the LRM-chapter corpus, per test → [sv_tests_coverage.md](sv_tests_coverage.md)
- Pavona per-IP table → [pavona_sweep.md](pavona_sweep.md); external-IP families → [ext_ip.md](ext_ip.md)
- The frontend matrix harness → [`test/FRONTEND_MATRIX_README.md`](../test/FRONTEND_MATRIX_README.md)
