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


def sh(cmd, cwd=None, timeout=None):
    """Run a command; return (rc, combined-output).  Never raises."""
    try:
        p = subprocess.run(cmd, cwd=cwd, text=True, timeout=timeout,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or "") + "\n[timeout]"


def read_names_file(path):
    names = set()
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                names.add(line.split()[0])
    return names


# ---------------------------------------------------------------- ibex / rp32
def sweep_testdirs(prefix, cycles, jobs, flt=None):
    """Sweep test/<prefix>_* dirs: slang miter + test_sim_equivalence.py."""
    known_fail = read_names_file(TEST_DIR / "slang_miter_expected_fail.txt")
    dirs = sorted(d for d in TEST_DIR.iterdir()
                  if d.is_dir() and d.name.startswith(prefix + "_")
                  and ((d / "project.f").exists() or (d / "dut.sv").exists())
                  and (flt is None or re.search(flt, d.name)))

    def one(d):
        name = d.name
        row = {"module": name, "formal": "—", "cosim": "—"}
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
    rc, out = sh(cmd, cwd=CVA6_DIR, timeout=7200)
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
        work = CVA6_DIR / "work" / mod
        for f in ("obj_dir", "adj_gold.v", "adj_gate.v", "adj_tb.sv", "adj.ys"):
            sh(["rm", "-rf", str(work / f)])
        rc, out = sh([sys.executable, "scripts/adjudicate.py", mod,
                      str(cycles), "1"], cwd=CVA6_DIR, timeout=2400)
        m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+)"
                      r" slang_vs_rtl=(\d+)", out)
        if m:
            u = int(m.group(1))
            row["cosim"] = "✅ PASS" if u == 0 else f"❌ {u} div"
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
def sweep_pavona(jobs, flt=None):
    """Pavona (OT-config hardened Ibex): formal statuses from one
    run_pavona_equiv.sh pass.  Co-sim adjudication is not wired up for this
    core yet — the column reports that honestly rather than skipping rows."""
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
                         "cosim": "— (not wired yet)"})
    rows.sort(key=lambda r: r["module"])
    return rows


# -------------------------------------------------------------------- report
def render(core, rows, cycles):
    lines = [f"## {core} sweep — formal (vs read_slang) + Verilator co-sim "
             f"({cycles} cycles)", "",
             "| module | formal vs slang | co-sim vs RTL |",
             "|---|---|---|"]
    for r in rows:
        lines.append(f"| {r['module']} | {r['formal']} | {r['cosim']} |")
    npass = sum(1 for r in rows if r["cosim"].startswith("✅"))
    nfail = sum(1 for r in rows if r["cosim"].startswith("❌"))
    comparable = npass + nfail
    pct = (100.0 * npass / comparable) if comparable else 0.0
    nequiv = sum(1 for r in rows if r["formal"].startswith("✅"))
    lines += ["",
              f"**Formal:** {nequiv}/{len(rows)} modules equivalent with "
              f"read_slang.",
              f"**Co-sim pass rate:** {npass}/{comparable} "
              f"(**{pct:.1f}%**) — {len(rows) - comparable} not comparable "
              f"(skipped / no run)."]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("core", choices=["ibex", "rp32", "cva6", "pavona"])
    ap.add_argument("--cycles", type=int, default=300)
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--filter", help="regex: only sweep matching modules")
    args = ap.parse_args()

    if args.core == "cva6":
        rows = sweep_cva6(args.cycles, args.jobs, args.filter)
    elif args.core == "pavona":
        rows = sweep_pavona(args.jobs, args.filter)
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
