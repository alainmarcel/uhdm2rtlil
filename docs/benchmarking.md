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
| **Syntacore SCR1** | 37 | 28 | 32 | 32 | 0 | 0 | 32 | 32 | 0 | 0 | 0 |
| **RgGen** | 25 | 25 | 25 | 25 | 0 | 0 | 25 | 25 | 0 | 0 | 0 |
| **VeeR EH1** | 67 | 55 | 66 | 66 | 0 | 0 | 66 | 66 | 0 | 0 | 0 |
| **TNoC** | 43 | 18 | 12 | 12 | 0 | 0 | 12 | 12 | 0 | 0 | 0 |
| **VeeR EL2** | 91 | 77 | 86 | 86 | 0 | 0 | 87 | 87 | 0 | 0 | 0 |
| **VeeR EH2** | 100 | 81 | 96 | 94 | **2** | 0 | 96 | 95 | 0 | 1 | 0 |
| **RSD** | 165 | 116 | 137 | 133 | **3** | 1 | 140 | 139 | 0 | 1 | 0 |
| **BlackParrot** | 125 | 48 | 45 | 42 | **3** | 0 | 45 | 45 | 0 | 0 | 0 |
| **OpenTitan** (upstream) | 32 | 28 | 29 | 27 | **1** | 1 | 29 | 28 | 0 | 1 | 0 |
| **OpenTitan IP library** (upstream, the other 44 blocks) | 605 | 526 | 551 | 539 | **6** | 6 | 551 | 545 | 0 | 6 | 0 |
| **Pavona** (300 modules + 100 chip instances) | 400 | 381 | 389 | 378 | **2** | 9 | 389 | 380 | 0 | 9 | 0 |
| **Ariane CVA6** (142 modules + 138 core instantiations, the latter formal-only) | 280 | 228 | 135 | 124 | **2** | 9 | 135 | 126 | 0 | 9 | 0 |
| **Ariane CVA6 flavours** (the three other sv-tests configurations: HPDcache, H-extension, RV32) | 429 | 301 | 402 | 365 | **9** | 28 | 402 | 374 | 0 | 28 | 0 |
| **Caliptra** | 22 | 19 | 21 | 21 | 0 | 0 | 21 | 21 | 0 | 0 | 0 |
| **XiangShan** (香山) | 21 | 19 | 21 | 21 | 0 | 0 | 21 | 21 | 0 | 0 | 0 |
| **XiangShan core** (香山) | 2002 | 1607 | 1944 | 1941 | **3** | 0 | 1945 | 1945 | 0 | 0 | 0 |
| **External IP** (the other 30 repos; the XiangShan library is the row above) | 3752 | 3084 | 3118 | 3081 | **10** | 27 | 3219 | 3113 | **78** | 28 | 0 |
| **chipsalliance/sv-tests** | 527 | 475 | 11 | 11 | 0 | 0 | 12 | 11 | 0 | 1 | 0 |
| **All sweeps** (19 workflows) | **8786** | **7162** | **7160** | **7026** | **41** | **93** | **7268** | **7094** | **78** | **96** | **0** |

**78 `read_uhdm` divergences in the 2026-10-28 nightlies**: 7094 of the 7268
co-simulated rows pass outright, 96 are divergences a SAT miter proved to be
simulation artefacts, and the 78 break down as

| family | divergences | status |
|---|---:|---|
| NVDLA | 70 | **3 open leads** -- `SDP_CORE_Y_cvt` (16 cycles), `_cvt_core` (7) and `MRDMA_EG_dout`, all one defect tracked by test/func_local_accumulator_in_ff -- plus 29 rows whose netlist `read_slang` cannot lower (`slang n/a`), which have no oracle either way |
| OpenPiton | 7 | to triage |
| OpenC910 | 1 | to triage |

NVDLA's rows are read-clean and opt-clean (908 of 908 with 0 undriven), so its
divergences are a triage queue rather than a regression.

VeeR EH2's
`eh2_ifu_mem_ctl` and adams-bridge's `abr_piso_multi`, the two open leads of the
2026-10-25 nightlies, still diverge (150 and 38 cycles) but are now ADJUDICATED
ARTEFACTS rather than counted defects: each one's miter proves equivalence as
far as its budget reaches (seq 4 and seq 3) and the divergence is deeper than
that, so the sweep classes them as artefacts and they are no longer in the
`read_uhdm` diverge column.  That is a reclassification, not a fix -- the two
rows still want a deeper miter.  `read_slang`, measured on the
same rows under the same stimulus, diverges on 38 of its own (92 more rows are
divergences both netlists share, the miter adjudicated, or have no oracle).

The `read_slang` divergences are listed with their reasons in
[slang_unsupported.md](slang_unsupported.md).  Counted by
[`test/sweep_table.py`](../test/sweep_table.py) over the reports of the runs
below.

### Provenance

The numbers are the **latest completed run of each sweep workflow as of
2026-10-28**, 19 workflows, refreshed with `test/sweep_table.py`.  The
**External IP** run (40668825086) FAILED as a whole: 148 of its 168 jobs
succeeded and the per-family reports of those are used, but

  * **BOOM (8 shards), Gemmini (6), Rocket Chip (4) and biRISC-V (1) produced
    no usable report** -- their report directories are empty -- so those four
    families contribute ZERO rows here and are tabulated from their first LOCAL
    sweep in [supported_ip.md](supported_ip.md);
  * **aib-protocols** reported 198 of its 397 rows and **OpenPiton** 756 of its
    852, so both keep local numbers there too;
  * **Cheshire** reported 30 rows against the 266 its local sweep measures --
    the CI run swept only the vendored `UsbOhciAxi4` modules.  That is an open
    harness question, not a result, and its row keeps the local figures;
  * **NaxRiscv, CV32E40X, CV32E40S and OpenE906** landed after the run started
    and have no nightly at all.

So the 8786 rows UNDERSTATE the corpus, by roughly the 1085 rows of those four
empty families plus the partial ones.

Run ids: ibex 40657392141, rp32 40660737218, fx68k 40706997811, scr1
40660315121, rggen 40713316491, veer-eh1 40668403252, tnoc 40715474861,
veer-el2 40680816053, veer-eh2 40672561668, rsd 40674691974, black-parrot
40705798747, opentitan 40696877896, ext (External IP + OpenTitan IP library)
40668825086, pavona 40668876232, cva6 40665596784, cva6-flavours
40674858534, caliptra 40679258861, xiangshan-core 40675391360, sv-tests
40668827529.

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
1847 tests) reports two things separately: what each frontend could **read**,
and — where a `read_verilog` golden exists to compare against — whether it was
**right**.

| Frontend | Read | Failed to read | Correct | Incorrect | No golden | Unknown |
|---|---:|---:|---:|---:|---:|---:|
| **`uhdm`** (this project) | **1815** | 32 | 1052 | 24 | 669 | 67 |
| `sv2v` | 1631 | 214 | 1000 | 0 | 559 | 71 |
| `slang` (Yosys sv-elab) | 1566 | 278 | 852 | 0 | 583 | 131 |
| `verilog` (Yosys native, the golden) | 1099 | 745 | 1099 | 0 | — | 0 |

*Failed to read* = failed + crashed + timed out + out-of-memory.  *No golden* = this
frontend synthesized but `read_verilog` could not, so there is nothing to
compare against — a capability win, verified against the RTL by co-simulation
rather than formally.  *Unknown* = formal non-equivalence the co-sim could not
adjudicate.

On this corpus the UHDM frontend reads the most SystemVerilog — **1815 of 1847**,
including **669 designs the native Verilog frontend cannot read at all**.

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
