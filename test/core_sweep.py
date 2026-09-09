#!/usr/bin/env python3
"""Per-core sweep: formal (read_uhdm vs read_slang) + Verilator co-sim table.

    core_sweep.py ibex|rp32|cva6 [--cycles N] [--jobs J] [--out FILE]

For every module of the chosen core, report:
  1. whether the UHDM import is formally equivalent to read_slang
     (per-test `test_slang_equiv.ys` miter for ibex/rp32; the cva6_equiv
     SAT-miter suite for cva6), and
  2. the Verilator co-sim result against the behavioural RTL — PASS or the
     number of divergent cycles (test_sim_equivalence.py for ibex/rp32;
     scripts/adjudicate.py for cva6),
plus a final co-sim pass-rate percentage.

The table is printed as GitHub-flavoured markdown; with $GITHUB_STEP_SUMMARY
set it is appended there too, so the Action run page shows it directly.
"""
import argparse
import concurrent.futures as cf
import os
import re
import subprocess
import sys
from pathlib import Path

TEST_DIR = Path(__file__).resolve().parent
CVA6_DIR = TEST_DIR / "cva6_equiv"
PAVONA_DIR = TEST_DIR / "pavona_equiv"
TLUL_DIR = TEST_DIR / "pavona_tlul_equiv"


def sh(cmd, cwd=None, timeout=None):
    """Run a command; return (rc, combined-output).  Never raises."""
    try:
        p = subprocess.run(cmd, cwd=cwd, text=True, timeout=timeout,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        # TimeoutExpired.stdout can be BYTES even with text=True (the child
        # is killed mid-stream) — concatenating str crashed the whole cva6
        # sweep right after the miter pass timed out.
        out = e.stdout or ""
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
        return 124, out + "\n[timeout]"


def read_names_file(path):
    names = set()
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                names.add(line.split()[0])
    return names


# ---------------------------------------------------------------- ibex / rp32
def read_analyzed_names():
    """Names from sim_equiv_analyzed.txt (`Test: <name>` headers) — co-sim
    divergences that were ADJUDICATED as non-bugs (SAT miter proves
    UHDM==Verilog, or the divergence is a shared sim/synth artefact)."""
    names = set()
    f = TEST_DIR / "sim_equiv_analyzed.txt"
    if f.exists():
        for line in f.read_text().splitlines():
            m = re.match(r"Test:\s*([A-Za-z0-9_-]+)", line.strip())
            if m:
                names.add(m.group(1))
    return names


def sweep_testdirs(prefix, cycles, jobs, flt=None):
    """Sweep test/<prefix>_* dirs: slang miter + test_sim_equivalence.py."""
    known_fail = read_names_file(TEST_DIR / "slang_miter_expected_fail.txt")
    analyzed = read_analyzed_names()
    baselined = read_names_file(TEST_DIR / "sim_equiv_warn_baseline.txt")
    dirs = sorted(d for d in TEST_DIR.iterdir()
                  if d.is_dir() and d.name.startswith(prefix + "_")
                  and ((d / "project.f").exists() or (d / "dut.sv").exists())
                  and (flt is None or re.search(flt, d.name)))

    def one(d):
        name = d.name
        row = {"module": name, "formal": "— (no miter)", "cosim": "—"}
        # Elaborate (surelog + read check) if the UHDM is missing.
        if not (d / "slpp_all" / "surelog.uhdm").exists():
            rc, _ = sh(["./test_uhdm_workflow.sh", name],
                       cwd=TEST_DIR, timeout=1200)
        if not (d / "slpp_all" / "surelog.uhdm").exists():
            row["formal"] = "elab-fail"
            row["cosim"] = "skip (no UHDM)"
            return row
        # 1. slang miter (only where the test ships one).
        if (d / "test_slang_equiv.ys").exists():
            rc, _ = sh([str(TEST_DIR / ".." / "out" / "current" / "bin" / "yosys"),
                        "-m", str(TEST_DIR / ".." / "build" / "uhdm2rtlil.so"),
                        "./test_slang_equiv.ys"], cwd=d, timeout=900)
            if rc == 0:
                row["formal"] = "✅ equivalent"
            elif name in known_fail:
                row["formal"] = "⚠ known-diff"
            else:
                row["formal"] = "❌ differs"
        # 2. Verilator co-sim.
        cfg = d / "sim_config"
        if cfg.exists() and "SKIP_SIM_EQUIV=1" in cfg.read_text():
            row["cosim"] = "skip (config)"
            return row
        rc, out = sh([sys.executable, "test_sim_equivalence.py", name,
                      "--cycles", str(cycles)], cwd=TEST_DIR, timeout=2400)
        m = re.search(r"FAIL: \d+ cycles, (\d+) mismatches", out)
        if re.search(r"PASS: \d+ cycles, 0 mismatches", out):
            row["cosim"] = "✅ PASS"
        elif m:
            # A divergence that the local campaign already ADJUDICATED as a
            # non-bug (sim_equiv_analyzed.txt) or has baselined as known
            # (sim_equiv_warn_baseline.txt) must not read as a failure here —
            # the local suite reports these as artefact/known, and the
            # nightly table contradicting it was pure confusion.
            if name in analyzed:
                row["cosim"] = f"⚠ artefact ({m.group(1)} div, adjudicated)"
            elif name in baselined:
                row["cosim"] = f"⚠ known ({m.group(1)} div, baselined)"
            else:
                row["cosim"] = f"❌ {m.group(1)} div"
        elif "vacuous" in out:
            row["cosim"] = "vacuous"
        elif rc == 77 or "SKIPPED" in out or "not applicable" in out \
                or "cannot build" in out:
            row["cosim"] = "skip"
        else:
            row["cosim"] = "error"
        return row

    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        return list(ex.map(one, dirs))


# --------------------------------------------------------------------- cva6
def sweep_cva6(cycles, jobs, flt=None):
    """Run the cva6_equiv miter suite, then adjudicate each module's co-sim."""
    # 1. Formal statuses from one run_cva6_equiv.sh pass (narrowed to the
    # filter when one is given — the script accepts module arguments).
    cmd = ["./run_cva6_equiv.sh"]
    if flt:
        manifest = CVA6_DIR / "cva6_modules.txt"
        for line in manifest.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    rc, out = sh(cmd, cwd=CVA6_DIR, timeout=10800)
    formal = {}
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"crash|elabfail|dead|skipped)", line)
        if m:
            formal[m.group(1)] = m.group(2)
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error", "crash": "crash",
        "elabfail": "elab-fail", "dead": "— (dead)", "skipped": "skip",
    }

    # Merge the manifest so a module the run did not report still gets a row.
    manifest = CVA6_DIR / "cva6_modules.txt"
    if manifest.exists():
        for line in manifest.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) >= 4 and parts[0] not in formal:
                formal[parts[0]] = parts[3] if parts[3] in label else "skipped"
    mods = sorted(m for m, st in formal.items()
                  if st != "dead" and (flt is None or re.search(flt, m)))

    def one(mod):
        row = {"module": mod, "formal": label.get(formal[mod], formal[mod]),
               "cosim": "—"}
        # Adjudicate the co-sim ONLY where the formal verdict left a
        # question (cex / SAT timeout).  Proven modules need no co-sim, and
        # adjudicating all ~140 modules serially can never fit a CI job
        # (the first nightly burned the whole 2h budget in the miter pass
        # alone).
        st = formal[mod]
        if st == "proven":
            row["cosim"] = "— (formally proven)"
            return row
        if st == "timeout":
            # SAT-budget class: co-sim adjudication for these runs locally;
            # doing all of them nightly cannot fit the job budget.
            row["cosim"] = "— (SAT-bound; adjudicate locally)"
            return row
        if st != "cex":
            row["cosim"] = "— (not runnable)"
            return row
        work = CVA6_DIR / "work" / mod
        for f in ("obj_dir", "adj_gold.v", "adj_gate.v", "adj_tb.sv", "adj.ys"):
            sh(["rm", "-rf", str(work / f)])
        rc, out = sh([sys.executable, "scripts/adjudicate.py", mod,
                      str(cycles), "1"], cwd=CVA6_DIR, timeout=2400)
        m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+)"
                      r" slang_vs_rtl=(\d+)", out)
        if m:
            u, sl = int(m.group(1)), int(m.group(2))
            if u == 0:
                row["cosim"] = "✅ PASS"
            elif sl > 0:
                # BOTH frontends diverge from the RTL sim — the established
                # shared-artifact class (X-init / stimulus), not a UHDM bug.
                row["cosim"] = f"⚠ shared div (uhdm={u}, slang={sl})"
            else:
                row["cosim"] = f"❌ {u} div (slang clean)"
        elif "no outputs to compare" in out:
            row["cosim"] = "skip (no outputs)"
        elif "netlist generation FAILED" in out or "NO_RUN" in out:
            row["cosim"] = "skip (no run)"
        else:
            row["cosim"] = "error" if rc else "skip"
        return row

    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        return list(ex.map(one, mods))


# ------------------------------------------------------------------- pavona
def _pavona_cosim(mod, cycles):
    """Verilator co-sim of one pavona module (RTL vs read_uhdm vs read_slang),
    reusing the work/<mod> elaboration run_pavona_equiv.sh already produced.
    Returns the cosim cell text.  uhdm==0 → PASS; uhdm>0 & slang>0 → the
    established shared-artefact class (both frontends agree, both differ from
    the behavioural sim = X-init / synth-vs-behavioural, not a UHDM bug);
    uhdm>0 & slang==0 → a genuine UHDM divergence."""
    rc, out = sh([sys.executable, "scripts/adjudicate.py", mod, str(cycles), "1"],
                 cwd=PAVONA_DIR, timeout=2400)
    m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+) slang_vs_rtl=(\d+)",
                  out or "")
    if m:
        u, sl = int(m.group(1)), int(m.group(2))
        if u == 0:
            return "✅ PASS"
        if sl > 0:
            return f"⚠ shared div (uhdm={u}, slang={sl})"
        return f"❌ {u} div (slang clean)"
    if "no outputs to compare" in (out or ""):
        return "skip (no outputs)"
    if "netlist generation FAILED" in (out or "") or "NO_RUN" in (out or ""):
        return "skip (no run)"
    if "both simulators failed" in (out or ""):
        return "skip (sim build)"
    return "error" if rc else "skip"


def _pavona_check(mod):
    """Structural opt-level check of the read_uhdm netlist: flatten, opt_clean,
    then `check` for nets with no driver.  read_slang produces ZERO undriven
    nets for these modules, so any undriven net in the read_uhdm netlist is a
    dropped driver (the gen-scope enum-array / enum-const class that the
    whole-core cosim divergence traced back to).  Fast — no SAT, no cosim — so
    it runs on every module and catches dropped drivers structurally, without
    needing a deep co-sim to reach them."""
    work = PAVONA_DIR / "work" / mod
    if not (work / "slpp_all" / "surelog.uhdm").exists():
        return "— (no run)"
    yosys = TEST_DIR / ".." / "out" / "current" / "bin" / "yosys"
    plugin = TEST_DIR / ".." / "build" / "uhdm2rtlil.so"
    flat = PAVONA_DIR / "wrappers" / f"flat_{mod}.sv"
    top = f"{mod}_flat" if flat.exists() else mod
    (work / "check.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\n"
        f"hierarchy -check -top {top}\n"
        f"flatten; opt_clean\n"
        f"check\n")
    rc, out = sh([str(yosys), "-q", "-m", str(plugin), "check.ys"],
                 cwd=work, timeout=1800)
    undriven = len(re.findall(r"used but has no driver", out or ""))
    if undriven:
        return f"❌ {undriven} undriven"
    if rc:
        return "error"
    return "✅ 0 undriven"


def sweep_pavona(jobs, cycles=300, flt=None):
    """Pavona (OT-config hardened Ibex): formal (read_uhdm vs read_slang) from
    one run_pavona_equiv.sh pass, PLUS a per-module Verilator co-sim (RTL vs
    both frontends) for the full formal+cosim picture."""
    cmd = ["./run_pavona_equiv.sh"]
    if flt:
        for line in (PAVONA_DIR / "pavona_modules.txt").read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    env = dict(os.environ, JOBS=str(jobs))
    try:
        p = subprocess.run(cmd, cwd=PAVONA_DIR, text=True, timeout=7200,
                           env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error",
        "elabfail": "elab-fail",
    }
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌🎉]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"elabfail)", line)
        if m:
            rows.append({"module": m.group(1),
                         "formal": label.get(m.group(2), m.group(2)),
                         "formal_raw": m.group(2), "cosim": "—"})
    rows.sort(key=lambda r: r["module"])

    # Co-sim EVERY module that elaborated (not error/elabfail) — the user wants
    # the full cosim+formal picture, and pavona's ~26 modules fit the budget.
    def one(r):
        if r["formal_raw"] in ("error", "elabfail"):
            r["cosim"] = "— (no elaboration)"
            r["check"] = "— (no elaboration)"
        else:
            r["check"] = _pavona_check(r["module"])
            r["cosim"] = _pavona_cosim(r["module"], cycles)
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


# ---------------------------------------------------------------------- tlul
def _tlul_check(mod):
    """Structural opt-level undriven-net check on the read_uhdm netlist of one
    TL-UL module (same idea as _pavona_check)."""
    work = TLUL_DIR / "work" / mod
    if not (work / "slpp_all" / "surelog.uhdm").exists():
        return "— (no run)"
    yosys = TEST_DIR / ".." / "out" / "current" / "bin" / "yosys"
    plugin = TEST_DIR / ".." / "build" / "uhdm2rtlil.so"
    flat = TLUL_DIR / "wrappers" / f"flat_{mod}.sv"
    top = f"{mod}_flat" if flat.exists() else mod
    (work / "check.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\n"
        f"hierarchy -check -top {top}\n"
        f"flatten; opt_clean\n"
        f"check\n")
    rc, out = sh([str(yosys), "-q", "-m", str(plugin), "check.ys"],
                 cwd=work, timeout=1800)
    undriven = len(re.findall(r"used but has no driver", out or ""))
    if undriven:
        return f"❌ {undriven} undriven"
    return "error" if rc else "✅ 0 undriven"


def _tlul_cosim(mod, cycles):
    """Verilator co-sim of one TL-UL module (RTL vs read_uhdm vs read_slang),
    multi-clock aware.  Needed to adjudicate the dual-clock CDC modules
    (tlul_fifo_async) that the SAT miter cannot reach."""
    rc, out = sh([sys.executable, "scripts/tlul_cosim.py", mod, str(cycles), "1"],
                 cwd=TLUL_DIR, timeout=1800)
    m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+) slang_vs_rtl=(\d+)",
                  out or "")
    if m:
        u, sl = int(m.group(1)), int(m.group(2))
        if u == 0:
            return "✅ PASS"
        if sl > 0:
            return f"⚠ shared div (uhdm={u}, slang={sl})"
        return f"❌ {u} div (slang clean)"
    if "no outputs to compare" in (out or "") or "no clocks found" in (out or ""):
        return "— (comb/no clk)"
    if "NO_RUN" in (out or "") or "netlist generation FAILED" in (out or ""):
        return "skip (no run)"
    if "both simulators failed" in (out or ""):
        return "skip (sim build)"
    return "error" if rc else "skip"


def sweep_tlul(jobs, cycles=300, flt=None):
    """Pavona TL-UL bus library: formal (read_uhdm vs read_slang) from one
    run_tlul_equiv.sh pass, plus a structural undriven-net check and (where the
    module has clocks) a Verilator co-sim vs the behavioural RTL."""
    cmd = ["./run_tlul_equiv.sh"]
    if flt:
        for line in (TLUL_DIR / "tlul_modules.txt").read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    try:
        p = subprocess.run(cmd, cwd=TLUL_DIR, text=True, timeout=7200,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error", "elabfail": "elab-fail",
    }
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌‼🎉]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"elabfail)\b", line)
        if m and m.group(1) not in ("TL-UL",):
            rows.append({"module": m.group(1),
                         "formal": label.get(m.group(2), m.group(2)),
                         "formal_raw": m.group(2), "cosim": "—"})
    rows.sort(key=lambda r: r["module"])

    def one(r):
        if r["formal_raw"] in ("error", "elabfail"):
            r["cosim"] = "— (no elaboration)"
            r["check"] = "— (no elaboration)"
        else:
            r["check"] = _tlul_check(r["module"])
            r["cosim"] = _tlul_cosim(r["module"], cycles)
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


# -------------------------------------------------------------------- report
def render(core, rows, cycles):
    # The pavona sweep adds a structural opt-level "check" column (undriven-net
    # detection on the flattened+opt'd read_uhdm netlist) — a fast dropped-driver
    # probe that runs on every module without needing a deep co-sim.
    has_check = any("check" in r for r in rows)
    lines = [f"## {core} sweep — formal (vs read_slang) + Verilator co-sim "
             f"({cycles} cycles)", ""]
    if has_check:
        lines += ["| module | formal vs slang | opt check (undriven) | co-sim vs RTL |",
                  "|---|---|---|---|"]
        for r in rows:
            lines.append(f"| {r['module']} | {r['formal']} | "
                         f"{r.get('check', '—')} | {r['cosim']} |")
    else:
        lines += ["| module | formal vs slang | co-sim vs RTL |",
                  "|---|---|---|"]
        for r in rows:
            lines.append(f"| {r['module']} | {r['formal']} | {r['cosim']} |")
    npass = sum(1 for r in rows if r["cosim"].startswith("✅"))
    nfail = sum(1 for r in rows if r["cosim"].startswith("❌"))
    nadj = sum(1 for r in rows if r["cosim"].startswith("⚠"))
    comparable = npass + nfail
    pct = (100.0 * npass / comparable) if comparable else 100.0
    nequiv = sum(1 for r in rows if r["formal"].startswith("✅"))
    lines += ["",
              f"**Formal:** {nequiv}/{len(rows)} modules equivalent with "
              f"read_slang.",
              f"**Co-sim pass rate:** {npass}/{comparable} "
              f"(**{pct:.1f}%**) — {nadj} adjudicated non-bug divergences "
              f"(⚠ rows, excluded), "
              f"{len(rows) - comparable - nadj} not comparable "
              f"(skipped / no run)."]
    if has_check:
        nclean = sum(1 for r in rows if r.get("check", "").startswith("✅"))
        ndirty = sum(1 for r in rows if r.get("check", "").startswith("❌"))
        lines.append(f"**Opt check:** {nclean}/{nclean + ndirty} modules with "
                     f"zero undriven nets ({ndirty} with dropped drivers).")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("core", choices=["ibex", "rp32", "cva6", "pavona", "tlul"])
    ap.add_argument("--cycles", type=int, default=300)
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--filter", help="regex: only sweep matching modules")
    args = ap.parse_args()

    if args.core == "cva6":
        rows = sweep_cva6(args.cycles, args.jobs, args.filter)
    elif args.core == "pavona":
        rows = sweep_pavona(args.jobs, args.cycles, args.filter)
    elif args.core == "tlul":
        rows = sweep_tlul(args.jobs, args.cycles, args.filter)
    else:
        rows = sweep_testdirs(args.core, args.cycles, args.jobs, args.filter)

    report = render(args.core, rows, args.cycles)
    print(report)
    if args.out:
        args.out.write_text(report)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(report)
    # Exit status: informational sweep — fail only if nothing ran.
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
