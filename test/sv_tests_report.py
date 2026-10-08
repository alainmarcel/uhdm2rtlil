#!/usr/bin/env python3
"""docs/sv_tests_coverage.md from sv_tests_sweep.py's results.tsv.

Usage: python3 sv_tests_report.py --results build/sv_tests/results.tsv \
         --commit <sv-tests sha> > ../docs/sv_tests_coverage.md
"""
import argparse, csv, re, sys
from collections import Counter, defaultdict

SVT = "https://github.com/chipsalliance/sv-tests"
CYCLES = 300   # matches sv_tests_sweep.py's --cycles default

CLASSES = [  # (label, regex on the read_uhdm diagnostic), first match wins
    ("a file with no module (class / package / `$unit` declarations only): read_uhdm errors \"No modules found\", the other frontends accept an empty design", r"No modules found"),
    ("several blocking assignments to one variable inside `initial` taken as conflicting init values", r"Conflicting init values"),
    ("`@(posedge clk iff cond)` event control: no clock extracted", r"Clock signal is empty"),
    ("sized decimal `?`/`z` literal (`16'sd?`) not parsed", r"Failed to parse decimal constant"),
    ("Surelog syntax error", r"surelog: \[SNT"),
    ("Surelog reports an error", r"surelog:"),
]

CORES = [  # (sv-tests core test, what sv-tests runs, our coverage)
    ("ariane / CVA6 (`cva6_cv64a6_imafdc_sv39`)", "full core, top `cva6`", "yes -- per-module miters + per-instance chip sweep (`sweep-cva6.yml`, same configuration)"),
    ("ariane / CVA6 (`cv64a6_imafdc_sv39_hpdcache`, `cv64a6_imafdch_sv39`, `cv32a6_imac_sv32`, `ariane_testharness`)", "full core at four more configurations", "**no** -- one configuration only"),
    ("ibex (`ibex_simple_system`, fusesoc)", "full core", "yes -- per-module (`sweep-ibex.yml`) and `ibex_top` / `ibex_lockstep` as internal tests"),
    ("veer-el2 (`veer-el2_wrapper` synth, `tb_top` sim)", "full core, default config", "partly -- the VeeR EL2 instances inside the Caliptra chip (`sweep-caliptra.yml`), not standalone"),
    ("veer-eh1 (`veer-eh1_wrapper`, fusesoc)", "full core", "yes -- per-module miters + co-sim over the core, its pipeline blocks and the rv* library (`sweep-veer-eh1.yml`)"),
    ("black-parrot (`bp_default`, `bp_unicore`, `bp_multicore_1`, `_cce_ucode`, `bp_multicore_4`, `_cce_ucode_cfg`) with basejump_stl + HardFloat", "six configurations, top `wrapper`", "**no**"),
    ("scr1 (`scr1_top_tb_axi`)", "full core + AXI top", "yes -- per-module miters + co-sim over the pipeline and both SoC tops (`sweep-scr1.yml`)"),
    ("rsd (`Core`)", "full core", "yes -- per-module miters + co-sim over the out-of-order core and its blocks (`sweep-rsd.yml`)"),
    ("tnoc (`tnoc`)", "network-on-chip", "**no**"),
    ("rggen (`rggen`, rggen-sv-rtl + rggen-sample)", "generated register files", "**no**"),
    ("fx68k", "68000 core (needs `--allow-dup-initial-drivers` under slang)", "**no**"),
    ("yosys tests (`yosys_hana`)", "the upstream yosys test files", "yes -- the 576 generated `test/run/**` tests in the regression"),
    ("ivtest (Icarus tests)", "the Icarus Verilog test suite", "**no**"),
]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", required=True)
    ap.add_argument("--commit", required=True)
    ap.add_argument("--repo", default=__import__("os").path.expanduser("~/ext/sv-tests"))
    a = ap.parse_args()
    rows = list(csv.DictReader(open(a.results), delimiter="\t"))
    run = [r for r in rows if r["uhdm"] != "SKIP"]
    skipped = len(rows) - len(run)
    def cnt(fe): return Counter(r[fe] for r in run)
    link = lambda t: f"[`{t.replace('tests/', '')}`]({SVT}/blob/{a.commit}/{t})"
    L = []; A = L.append
    A("# chipsalliance/sv-tests: what our frontend misses\n")
    A(f"[sv-tests]({SVT}) at `{a.commit[:9]}` is the LRM-chapter corpus every SystemVerilog tool is")
    A("scored on. The nightly **Sweep sv-tests** action"
      " (`.github/workflows/sweep-sv-tests.yml`) runs `test/sv_tests_sweep.py` over")
    A("sv-tests' OWN local tests -- the `tests/chapter-*` trees, `tests/generic` and")
    A("`tests/sanity.sv` -- and publishes this report as its artifact; the CORE tests")
    A("sv-tests also defines (ariane/CVA6, ibex, VeeR, black-parrot, scr1, ...) are swept")
    A("per core instead. Of those local tests, every one not marked")
    A(f"`:unsynthesizable: 1` outside `uvm/` and `testbenches/`, {len(run)} of {len(rows)} -- through three")
    A("frontends with sv-tests' own rules: the test's mode (simulation > elaboration > parsing >")
    A("preprocessing from its `:type:`), the Yosys runner's script per mode (`hierarchy; proc;")
    A("check; clean; memory_dff; memory_collect; stat; check`, then `sim -assert` for simulation")
    A("tests), and `:should_fail_because:` tests PASS when the tool rejects them.\n")
    A("| frontend | PASS | FAIL | what the column means |")
    A("|---|---|---|---|")
    c = cnt("uhdm"); A(f"| read_uhdm (Surelog + our frontend) | {c['PASS']} | {c['FAIL'] + c['TIMEOUT']} | Surelog parse + read_uhdm + the mode script |")
    c = cnt("verilog"); A(f"| read_verilog (yosys, sv-tests' own Yosys runner) | {c['PASS']} | {c['FAIL'] + c['TIMEOUT']} | the same mode script |")
    c = cnt("slang"); A(f"| read_slang (sv-tests' yosys_slang runner flags) | {c['PASS']} | {c['FAIL'] + c['TIMEOUT']} | read only -- that runner never elaborates further, so this is \"slang reads it\" |")
    A("")
    # ---- the same table every other sweep prints ---------------------------
    # sv-tests' own verdict is only "did the frontend read it".  That says
    # nothing about whether what we BUILT is right, which is what the core /
    # ext / pavona sweeps measure per module.  Same probes, same columns, same
    # order and same summary lines as core_sweep.py's table, so a reader can
    # compare an sv-tests row against an ibex or pavona row directly.
    deep = [r for r in run if (r.get("formal") or "—") != "—"
            and not (r.get("formal") or "").startswith("— (")]
    if deep:
        deep.sort(key=lambda r: r["test"])
        sc = lambda r: r.get("slang_cosim") or "—"
        has_conf = any((r.get("conflicts") or "—") != "—" for r in deep)
        has_check = any((r.get("undriven") or "—") != "—" for r in deep)
        has_unres = any((r.get("unresolved") or "—") != "—" for r in deep)
        A(f"## sv-tests sweep — formal (vs read_slang) + Verilator co-sim "
          f"({CYCLES} cycles)\n")
        A("Reading a file proves nothing about the netlist, so every row that")
        A("elaborates to a top also goes through the probes the core / ext /")
        A("pavona sweeps use -- a SAT miter against `read_slang`, the structural")
        A("opt-check for dropped drivers and driver conflicts, and a Verilator")
        A("co-simulation of BOTH netlists against the original RTL.\n")
        hdr = ["slang co-sim vs RTL", "module", "formal vs slang"]
        if has_conf:
            hdr.append("driver conflicts")
        if has_check:
            hdr.append("opt check (undriven)")
        if has_unres:
            hdr.append("unresolved reads")
        hdr.append("co-sim vs RTL")
        A("| " + " | ".join(hdr) + " |")
        A("|" + "---|" * len(hdr))
        for r in deep:
            cells = [sc(r), link(r["test"]), r.get("formal") or "—"]
            if has_conf:
                cells.append(r.get("conflicts") or "—")
            if has_check:
                cells.append(r.get("undriven") or "—")
            if has_unres:
                cells.append(r.get("unresolved") or "—")
            cells.append(r.get("cosim") or "—")
            A("| " + " | ".join(cells) + " |")
        spass = sum(1 for r in deep if sc(r).startswith("✅"))
        sfail = sum(1 for r in deep if sc(r).startswith("❌"))
        npass = sum(1 for r in deep if (r.get("cosim") or "").startswith("✅"))
        nfail = sum(1 for r in deep if (r.get("cosim") or "").startswith("❌"))
        nadj = sum(1 for r in deep if (r.get("cosim") or "").startswith("⚠"))
        comparable = npass + nfail
        pct = (100.0 * npass / comparable) if comparable else 100.0
        nequiv = sum(1 for r in deep if (r.get("formal") or "").startswith("✅"))
        A("")
        A(f"**Slang co-sim baseline:** {spass}/{spass + sfail} read_slang "
          f"netlists track the RTL ({sfail} diverge; "
          f"{len(deep) - spass - sfail} not comparable).")
        A(f"**Formal:** {nequiv}/{len(deep)} modules equivalent with read_slang.")
        A(f"**Co-sim pass rate:** {npass}/{comparable} (**{pct:.1f}%**) — "
          f"{nadj} adjudicated non-bug divergences (⚠ rows, excluded), "
          f"{len(deep) - comparable - nadj} not comparable (skipped / no run).")
        if has_check:
            nclean = sum(1 for r in deep if (r.get("undriven") or "").startswith("✅"))
            ndirty = sum(1 for r in deep if (r.get("undriven") or "").startswith("❌"))
            A(f"**Opt check:** {nclean}/{nclean + ndirty} modules with zero "
              f"undriven nets ({ndirty} with dropped drivers).")
        if has_conf:
            cclean = sum(1 for r in deep if (r.get("conflicts") or "").startswith("✅"))
            cdirty = sum(1 for r in deep if (r.get("conflicts") or "").startswith("❌"))
            A(f"**Driver conflicts:** {cclean}/{cclean + cdirty} modules with "
              f"none ({cdirty} with a net driven twice, or an assignment whose "
              f"target is a constant / input port). A row with conflicts makes "
              f"the formal column UNRELIABLE — the bogus feedback constrains "
              f"the miter to the inputs where gold and gate agree, so it can "
              f"pass vacuously.")
        A("")
        A("Most rows co-sim as `skip (no run)`: an LRM snippet usually has no")
        A("clocked I/O for a testbench to drive, so there is nothing to compare.")
        A("And a `differs` here is NOT automatically a reader defect -- most of")
        A("them are **simulation-only constructs** (associative arrays and their")
        A("methods, `force`/`release`, `$test$plusargs`, `cover`) that neither")
        A("frontend synthesises to anything meaningful, so the miter compares two")
        A("different nothings.\n")

    miss = [r for r in run if r["uhdm"] != "PASS" and (r["verilog"] == "PASS" or r["slang"] == "PASS")]
    ours_only = sum(1 for r in run if r["uhdm"] == "PASS" and r["verilog"] != "PASS")
    allfail = [r for r in run if r["uhdm"] != "PASS" and r["verilog"] != "PASS" and r["slang"] != "PASS"]
    A(f"**{len(miss)}** tests pass under read_verilog or read_slang and not under read_uhdm (the misses");
    A(f"below); **{ours_only}** pass under read_uhdm and not under read_verilog; **{len(allfail)}** fail under all three.\n")
    A("## How to reproduce\n")
    A("```")
    A("git clone --depth 1 https://github.com/chipsalliance/sv-tests ~/ext/sv-tests")
    A("cd test && python3 sv_tests_sweep.py --repo ~/ext/sv-tests --jobs 8 --out ../build/sv_tests   # all 1015 tests, ~10 min")
    A("python3 sv_tests_sweep.py --filter 'chapter-9/9.4.2.3'                                       # one test")
    A("ls ../build/sv_tests/work/tests__chapter-9__9.4.2.3--event_conditional.sv/   # surelog.log, uhdm.ys/.log, verilog.ys/.log, slang.ys/.log")
    A("python3 sv_tests_report.py --results ../build/sv_tests/results.tsv --commit <sha> > ../docs/sv_tests_coverage.md")
    A("```\n")
    A("## Misses, by cause\n")
    by = defaultdict(list)
    for r in miss:
        if r["should_fail"] == "1":
            by[("should-fail test accepted: Surelog elaborates code the LRM forbids (every row lists the rule)", 100)].append(r); continue
        d = r["uhdm_err"]
        for i, (label, rx) in enumerate(CLASSES):
            if re.search(rx, d):
                by[(label, i)].append(r); break
        else:
            by[(d[:80] or "(no diagnostic)", 50)].append(r)
    A("| cause | tests | kind |")
    A("|---|---|---|")
    for (label, i), lst in sorted(by.items(), key=lambda kv: -len(kv[1])):
        kind = "reader behaviour" if i == 0 else "Surelog leniency" if i == 100 else "Surelog" if 4 <= i <= 5 else "reader bug"
        A(f"| {label} | {len(lst)} | {kind} |")
    A("")
    for (label, i), lst in sorted(by.items(), key=lambda kv: -len(kv[1])):
        A(f"### {label} -- {len(lst)}\n")
        A("| test | mode | read_uhdm | read_verilog | read_slang | diagnostic / rule |")
        A("|---|---|---|---|---|---|")
        for r in sorted(lst, key=lambda r: r["test"]):
            why = r["uhdm_err"]
            if r["should_fail"] == "1":
                try:
                    txt = open(f"{a.repo}/{r['test']}", errors='replace').read(4000)
                except Exception:
                    txt = ""
                m = re.search(r":should_fail_because:\s*(.*)", txt)
                why = ("should fail: " + m.group(1).strip()) if m else "should fail"
            A(f"| {link(r['test'])} | {r['mode']} | {r['uhdm']} | {r['verilog']} | {r['slang']} | {why.replace('|', chr(92) + '|')[:160]} |")
        A("")
    A("## Fails under all three frontends\n")
    A("| test | mode | read_uhdm | read_slang |")
    A("|---|---|---|---|")
    for r in sorted(allfail, key=lambda r: r["test"]):
        A(f"| {link(r['test'])} | {r['mode']} | {r['uhdm_err'][:100] or r['uhdm']} | {r['slang_err'][:100] or r['slang']} |")
    A("")
    A("## The cores sv-tests covers, and which we sweep\n")
    A("sv-tests generates one test per core configuration from `generators/*` (full-core")
    A("elaboration, top module named); our nightly sweeps prove per module against read_slang")
    A("and co-simulate.  What they have that we do not:\n")
    A("| sv-tests core test | what it is | our sweep |")
    A("|---|---|---|")
    for core, what, ours in CORES:
        A(f"| {core} | {what} | {ours} |")
    A("")
    print("\n".join(L))

if __name__ == "__main__":
    main()
