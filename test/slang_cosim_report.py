#!/usr/bin/env python3
"""Emit docs/slang_cosim_findings.md from a curated row table.

Row: family, module, slang_div, uhdm_div, first_div, source
  slang_div / uhdm_div: divergence counts against the behavioural RTL in the
  same Verilator testbench; None when not measured.
"""
import os, re, sys, urllib.parse

ROWS = []          # filled by the caller via add()
def add(family, module, slang, uhdm, first="", source=""):
    ROWS.append(dict(family=family, module=module, slang=slang, uhdm=uhdm,
                     first=first, source=source))

def issue_url(family, module, first):
    title = f"read_slang: {module} netlist does not match the RTL in simulation"
    body = (f"`read_slang` ({family} sweep) produces a netlist whose simulation "
            f"diverges from the behavioural RTL.\n\n"
            f"First divergence: {first or 'see report'}\n\n"
            f"Method: one Verilator testbench drives the behavioural RTL, the "
            f"`read_slang` netlist and the `read_uhdm` netlist with identical "
            f"stimulus. The `read_uhdm` netlist matches the RTL on every cycle; "
            f"the `read_slang` netlist does not.\n\n"
            f"Yosys 0.69, read_slang from the vendored sv-elab (povik/sv-elab @ b4fd362).")
    return ("https://github.com/YosysHQ/yosys/issues/new?"
            + urllib.parse.urlencode({"title": title, "body": body}))

def classify(r):
    if r["slang"] in (None, 0):
        return "clean"
    if r["uhdm"] == 0:
        return "report"
    if r["uhdm"] is None:
        return "unmeasured"
    if r["uhdm"] == r["slang"]:
        return "shared"
    return "adjudicate"

def emit(out):
    g = {k: [r for r in ROWS if classify(r) == k]
         for k in ("report", "adjudicate", "shared", "clean", "unmeasured")}
    L = []
    A = L.append
    A("# Where `read_slang` does not match Verilator\n")
    A("Every nightly IP sweep co-simulates three things against each other with one\n"
      "testbench and one random stimulus: the behavioural RTL, the netlist\n"
      "`read_uhdm` produces, and the netlist `read_slang` produces.  The left-most\n"
      "column of every sweep table is the last of those — how the reference\n"
      "frontend's own netlist tracks the RTL under Verilator.  This file collects\n"
      "every row where it does not.\n")
    A("A row is evidence of a `read_slang` defect when the `read_uhdm` netlist\n"
      "matches the RTL on every cycle and the `read_slang` netlist does not: same\n"
      "testbench, same stimulus, same RTL, one netlist right and one wrong.  When\n"
      "BOTH netlists diverge the cause is almost always the co-simulation itself —\n"
      "an un-reset register reads X out of reset in the RTL and 0 in a netlist —\n"
      "so those rows are listed separately and are not reported.\n")
    A("`read_slang` is a Yosys built-in since v0.67; the code is vendored from\n"
      "[povik/sv-elab](https://github.com/povik/sv-elab) at `b4fd362`.  Measured on\n"
      "Yosys 0.69.\n")
    A("> **A correction.** Until 2026-09-29 this list was much longer, and wrongly\n"
      "> so.  All three co-simulation harnesses flattened an unpacked-array port\n"
      "> with element 0 at the least significant bits whatever the declared\n"
      "> direction, which matched `read_uhdm` alone.  `read_slang` follows the\n"
      "> language — the left index of the dimension takes the most significant\n"
      "> bits, which is what the stream operator `{>>{x}}` computes (LRM 11.4.14)\n"
      "> and what Verilator prints for it — so every module with an ascending\n"
      "> `x [N]` port looked like a slang defect.  The reader and the harnesses\n"
      "> were corrected to the language's order; `ibex_id_stage` went from 52\n"
      "> divergences to none, `otbn_reg_top` from 19 to none, `ibex_ex_block` from\n"
      "> 447 to 58 (and those 58 are shared with `read_uhdm`, so the row is an\n"
      "> artefact, not a defect).  The rows below are what survived.\n")

    A("\n## Report to Yosys\n")
    if g["report"]:
        A("The `read_uhdm` netlist matches the RTL cycle for cycle; the\n"
          "`read_slang` netlist does not.\n")
        A("| Sweep | Module | Diverging cycles | First divergence | Report |")
        A("|---|---|---|---|---|")
        for r in sorted(g["report"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} | {r['first'] or '—'} "
              f"| [file an issue]({issue_url(r['family'], r['module'], r['first'])}) |")
    else:
        A("None outstanding.\n")

    if g["adjudicate"]:
        A("\n## Both netlists diverge, but not equally\n")
        A("Both frontends drift from the RTL, so the co-simulation's own X-initial\n"
          "state explains most of it, but the counts differ — worth adjudicating\n"
          "before either reporting or dismissing.\n")
        A("| Sweep | Module | slang | read_uhdm | First slang divergence |")
        A("|---|---|---|---|---|")
        for r in sorted(g["adjudicate"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} | {r['uhdm']} | {r['first'] or '—'} |")

    if g["shared"]:
        A("\n## Shared divergence — a co-simulation artefact, not a defect\n")
        A("Both netlists diverge from the RTL on exactly the same cycles.  A netlist\n"
          "has no X state, so an un-reset register reads 0 where the RTL reads X;\n"
          "the SAT miter, which starts from a defined state, proves these modules\n"
          "equivalent.  Listed for completeness.\n")
        A("| Sweep | Module | Diverging cycles (both) |")
        A("|---|---|---|")
        for r in sorted(g["shared"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} |")

    if g["unmeasured"]:
        A("\n## Not yet re-measured\n")
        A("Carried from the last CI report; the `read_uhdm` side has not been run\n"
          "since the harness correction, so these are not yet classified.\n")
        A("| Sweep | Module | slang divergences | Source |")
        A("|---|---|---|---|")
        for r in sorted(g["unmeasured"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['slang']} | {r['source']} |")

    if g["clean"]:
        A("\n## Cleared by the harness correction\n")
        A("| Sweep | Module | Was | Now |")
        A("|---|---|---|---|")
        for r in sorted(g["clean"], key=lambda r: (r["family"], r["module"])):
            A(f"| {r['family']} | `{r['module']}` | {r['first']} | 0 |")

    A("\n---\n")
    A("Regenerate with `test/slang_cosim_report.py` after a sweep cycle.  A row moves\n"
      "out of this file the moment its sweep reports the slang column clean.\n")
    open(out, "w").write("\n".join(L) + "\n")
    print(f"{out}: report={len(g['report'])} adjudicate={len(g['adjudicate'])} "
          f"shared={len(g['shared'])} unmeasured={len(g['unmeasured'])} cleared={len(g['clean'])}")

# ------------------------------------------------------------ the sweep rows
# Parsed straight from the downloaded CI sweep reports, so the file cites what
# the nightly measured rather than anything run by hand.  Point SWEEPS at a
# directory of `gh run download` results: <family>_<runid>/<fam>-sweep-report/*.md.
SWEEPS = os.environ.get("SLANG_REPORT_SWEEPS", "build/sweeps/post_elemorder")

# First divergence for the rows where it was captured (the co-sim log's
# FIRST-SLANG line; the sweep report keeps only the count).
FIRST = {
    "width_converter_8toN": "cycle 26, `source_data_o` rtl=`0000073f` slang=`0000003f`",
    "cv32e40p_register_file": "cycle 27, `rdata_a_o` rtl=`82b7c5e0` slang=`00000000`",
    "macro_decoder": "cycle 6, `instr_o` rtl=`ff313823` slang=`c172ff1c`",
    "fpnew_fma_multi": "cycle 16, `result_o` rtl=`…ffff7fc0` slang=`…ffff5ae0`",
    "otbn_rnd": "cycle 4, `ispr_urnd_state_rdata_o` (slang zeroes the low limb)",
    "axis_ram_switch": "cycle 40, `m_axis_tdata` rtl=`00630000` slang=`00000000`",
    "pcie_axil_master": "cycle 55, `tx_cpl_tlp_data`",
    "pcie_s10_cfg": "cycle 198, `cfg_msi_address` rtl=`c2af88347c3321e0` slang=`000000007c3321e0`",
    "ibex_cs_registers": "cycle 206, `csr_mepc_o` rtl=`0` slang=`548c3846`",
}

def _num(cell):
    m = re.search(r"(\d+) div", cell)
    return int(m.group(1)) if m else None

def _uhdm_div(cell):
    """Divergence count on the read_uhdm side, from the right-most co-sim cell."""
    if cell.startswith("✅") or "PASS" in cell:
        return 0
    m = re.search(r"uhdm=(\d+)", cell) or re.search(r"\((\d+) div", cell) or re.search(r"(\d+) div", cell)
    return int(m.group(1)) if m else None

NOREF = []            # rows read_slang cannot read at all -- the other report
RUNS = {}

def load_sweeps(root):
    import glob
    for f in sorted(glob.glob(os.path.join(root, "*", "*-sweep-report", "*.md"))):
        fam = os.path.basename(f).replace("-sweep.md", "")
        run = os.path.basename(os.path.dirname(os.path.dirname(f))).rsplit("_", 1)[-1]
        RUNS[fam] = run
        hdr = None
        for line in open(f):
            if not line.startswith("| "):
                continue
            c = [x.strip() for x in line.strip().strip("|").split("|")]
            if hdr is None:
                hdr = c
                continue
            if len(c) < 4 or set(c[0]) <= set("-: "):
                continue
            mod, formal, cos = c[1], c[2], c[-1]
            if "no reference" in formal or formal.startswith("— (no miter"):
                NOREF.append((fam, mod, formal))
                continue
            if not c[0].startswith(("❌", "⚠")):
                continue
            add(fam, mod, _num(c[0]), _uhdm_div(cos), FIRST.get(mod, ""), f"CI run {run}")

# ----------------------------------------------------- the two test suites
# The same three-way question asked of every test that already has a
# wrapper, a testbench and stimulus: 1139 local tests and 511 upstream Yosys
# tests (test/run/).  `--frontend slang` was never run over these until
# 2026-09-29; the regression now runs it as a soft-warn column.
SUITE = []
def suite_add(suite_name, test, slang, uhdm, first=""):
    SUITE.append(dict(suite=suite_name, test=test, slang=slang, uhdm=uhdm, first=first))

# read_uhdm clean, read_slang not -- a small self-contained reproducer each
suite_add("local", "ArrayInit", 200, 0,
          "`a` rtl=`1` slang=`0` — 2-D unpacked array, nested `'{'{0,1,2},'{4,4,4}}` initialiser")
suite_add("local", "case_expr_extend", 200, 0, "`out` rtl=`3f` slang=`0`")
suite_add("local", "const_fold_func", 200, 0, "`out6` rtl=`2` slang=`0`")
suite_add("local", "counter_dual_xbranch", 108, 0, "`count_instr` rtl=`0` slang=`2`")
suite_add("local", "dyn_packed_multidim", 89, 0, "`o_dyn_both` rtl=`0` slang=`1eb`")
suite_add("local", "hana_test_parse2synthtrans", None, 0,
          "the slang netlist is inert — no output activity at all")
suite_add("local", "nested_full_case", 13, 0, "`q` rtl=`eb` slang=`49`")
suite_add("local", "param_dyn_elem_select", 124, 0, "`ut_out` rtl=`0` slang=`1`")
suite_add("local", "UnionParameter", 200, 0, "`o` rtl=`6` slang=`8`")
suite_add("upstream", "run/arch/common/tribuf", 46, 0, "`o` rtl=`0` slang=`1`")
suite_add("upstream", "run/simple/task_func", 200, 0, "`w` rtl=`54` slang=`a8`")

def emit_suites(L):
    A = L.append
    only = [r for r in SUITE if r["uhdm"] == 0]
    A("\n## The test suites\n")
    A("Both suites already carry what the measurement needs — a wrapper, a\n"
      "testbench and stimulus — and a known-good `read_uhdm` baseline.  Until\n"
      "2026-09-29 the co-simulation was only ever run with the `read_uhdm`\n"
      "netlist, so the reference frontend went unmeasured over 1650 tests.  It is\n"
      "now a soft-warn column of the regression (`run_slang_cosim_softwarn`).\n")
    A("| Suite | Co-simulated | `read_slang` diverges | of those: slang-only | both, unequal | shared |")
    A("|---|---|---|---|---|---|")
    A("| local `test/<name>` | 1139 | 41 | 9 | 9 | 23 |")
    A("| upstream `test/run/**` | 511 | 42 | 5 | 15 | 22 |")
    A("\nThree tests appear in both suites — the internal copies of upstream\n"
      "reproducers — so the distinct slang-only set is eleven.\n")
    A("\n### Report to Yosys — test-suite reproducers\n")
    A("These are the most useful reports in this file: the `read_uhdm` netlist\n"
      "matches the RTL, the `read_slang` netlist does not, and the design is a few\n"
      "lines that already live in a repository Yosys itself ships or vendors.\n")
    A("| Suite | Test | Diverging cycles | First divergence | Report |")
    A("|---|---|---|---|---|")
    for r in sorted(only, key=lambda r: (r["suite"], r["test"])):
        n = r["slang"] if r["slang"] is not None else "inert"
        A(f"| {r['suite']} | `{r['test']}` | {n} | {r['first']} "
          f"| [file an issue]({issue_url('test suite', r['test'], r['first'])}) |")
    A("\nThe other rows split the same way as the sweeps: where both netlists\n"
      "diverge identically the co-simulation's X-initial state explains it, and\n"
      "where the counts merely differ the row needs adjudicating before anyone\n"
      "reports or dismisses it.  `case_expr_const`, `case_expr_non_const`,\n"
      "`wandwor`, `latch_002`, `ibex_cs_registers`, `rp32_r5p_alu`,\n"
      "`rp32_r5p_mouse`, `full_case_latch` and the `dynamic_part_select` family\n"
      "are in that middle group on both sides.\n")

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "slang_cosim_findings.md"
    load_sweeps(SWEEPS)
    emit(out)
    L = []
    emit_suites(L)
    L.append("\n## Designs `read_slang` cannot read at all\n")
    L.append(f"A further **{len(NOREF)}** sweep rows never reach this comparison because\n"
             "`read_slang` cannot elaborate the design, so there is no netlist to\n"
             "co-simulate: an interface port at the top, `$readmemh`, a package or macro\n"
             "it does not resolve, an unroll limit.  Those are a capability gap rather\n"
             "than a divergence and are counted here only so this file is not mistaken\n"
             "for the whole picture.\n")
    byfam = {}
    for fam, mod, why in NOREF:
        byfam[fam] = byfam.get(fam, 0) + 1
    L.append("| Sweep | Rows |")
    L.append("|---|---|")
    for fam in sorted(byfam, key=lambda k: -byfam[k]):
        L.append(f"| {fam} | {byfam[fam]} |")
    L.append(f"\nMeasured on CI runs: " +
             ", ".join(f"{k} `{v}`" for k, v in sorted(RUNS.items())) + ".\n")
    with open(out, "a") as f:
        f.write("\n".join(L) + "\n")
    print(f"  + suites: slang-only {len([r for r in SUITE if r['uhdm']==0])}"
          f"  + noref rows: {len(NOREF)}")
