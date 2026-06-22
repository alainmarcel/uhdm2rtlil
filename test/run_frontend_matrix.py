#!/usr/bin/env python3
"""run_frontend_matrix.py — 4-frontend SystemVerilog regression matrix.

For every test (this repo's test/* and, with --yosys/--all, the upstream Yosys
suite) run each of four frontends and classify, per (test, frontend):

  * Did it SYNTHESIZE?  (read the source, produced a non-trivial gate netlist)
  * Is the result CORRECT?
      - formal equivalence (equiv_pair.sh) vs the Yosys-verilog golden netlist
      - Verilator co-simulation (test_sim_equivalence.py) vs the original RTL

Frontends: verilog (native, also golden), uhdm (this plugin), sv2v, slang.

Pipeline reused per test:
  frontend_matrix_workflow.sh  -> *_from_<f>_synth.v + frontend_status.txt
  equiv_pair.sh                -> formal verdict (vs verilog golden)
  test_sim_equivalence.py      -> co-sim verdict (vs original RTL)

Outputs (under test/): frontend_matrix.csv and FRONTEND_MATRIX.md.

Usage:
  run_frontend_matrix.py [pattern] [--yosys|--all] [--cycles N] [--jobs N]
                         [--frontends verilog,uhdm,sv2v,slang] [--no-cosim]
                         [--out PREFIX]
"""
from __future__ import annotations

import argparse
import csv
import os
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# Per-step wall-clock cap (seconds): each frontend's synth, its formal-equiv,
# and its co-sim are bounded so a pathological design can't spin a yosys/verilator
# for hours.  Override via FRONTEND_TIMEOUT_S (also honored by the workflow shell).
STEP_TIMEOUT = int(os.environ.get("FRONTEND_TIMEOUT_S", "360"))
RC_TIMEOUT = 124
RC_OOM = 125
# Hard per-job memory cap.  A single heavy synth/formal/Verilator job (e.g. a
# wide-RAM design like priority_memory) can exhaust the 16 GB CI runner and get
# the WHOLE action SIGTERM'd ("runner received a shutdown signal", exit 143) —
# losing the shard with no result and no log of which test did it.  We cap each
# job's process-group RSS and SIGKILL it OURSELVES first, recording an `oom`
# status, so the sweep keeps going.  Override via FRONTEND_MEM_LIMIT_MB; 0 = off.
MEM_LIMIT_BYTES = int(os.environ.get("FRONTEND_MEM_LIMIT_MB", "12000")) * 1024 * 1024
MEM_POLL_S = 1.0


def _pgroup_rss_bytes(pgid: int) -> int:
    """Total resident memory (bytes) of every process in process group `pgid`."""
    page = os.sysconf("SC_PAGE_SIZE")
    total = 0
    try:
        pids = os.listdir("/proc")
    except OSError:
        return 0
    for pid in pids:
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as fh:
                data = fh.read()
            # comm (field 2) is parenthesised and may contain spaces/parens —
            # parse the fixed fields AFTER the final ')'.
            after = data[data.rfind(")") + 2:].split()
            if int(after[2]) != pgid:          # state, ppid, pgrp
                continue
            with open(f"/proc/{pid}/statm") as fh:
                total += int(fh.read().split()[1]) * page   # field 2 = resident
        except (OSError, ValueError, IndexError):
            continue
    return total

ALL_FRONTENDS = ["verilog", "uhdm", "sv2v", "slang"]

TEST_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = TEST_DIR.parent

# synth status (from frontend_status.txt) -> short CSV token
SYNTH_TOKEN = {
    "OK": "yes", "NO_GATES": "empty", "SYNTH_FAIL": "no",
    "READ_FAIL": "no", "CONVERT_FAIL": "no", "CRASH": "crash",
    "TOOL_MISSING": "missing", "TIMEOUT": "timeout", "OOM": "oom",
}


def run(cmd: list[str], cwd: Path | None = None, timeout: int | None = None):
    """Run a command; return (returncode, combined_output).

    On timeout the ENTIRE process group is killed — the children we launch are
    shell scripts / Python that spawn yosys / surelog / verilator / cc1plus
    grandchildren, and a plain subprocess timeout would reap only the direct
    child, orphaning those grandchildren to burn a core for hours.  We start the
    child in its own session (process-group leader) and SIGKILL the whole group.
    """
    try:
        p = subprocess.Popen(cmd, cwd=cwd, text=True, start_new_session=True,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    except OSError as e:
        return 1, f"[spawn-failed] {e}"
    # Drain stdout in a thread so a chatty job can't deadlock on a full pipe
    # while we poll its memory; meanwhile watch wall-time AND process-group RSS.
    chunks: list[str] = []
    reader = threading.Thread(target=lambda: chunks.extend(p.stdout), daemon=True)
    reader.start()
    pgid = p.pid                       # start_new_session => pgid == pid
    deadline = (time.time() + timeout) if timeout else None
    verdict = None                     # None=ok | RC_TIMEOUT | RC_OOM
    while True:
        try:
            p.wait(timeout=MEM_POLL_S)
            break
        except subprocess.TimeoutExpired:
            pass
        if deadline and time.time() > deadline:
            verdict = RC_TIMEOUT
            break
        if MEM_LIMIT_BYTES and _pgroup_rss_bytes(pgid) > MEM_LIMIT_BYTES:
            verdict = RC_OOM
            break
    if verdict is not None:
        try:
            os.killpg(pgid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            p.wait(timeout=15)
        except Exception:
            pass
    reader.join(timeout=15)
    out = "".join(chunks)
    if verdict == RC_TIMEOUT:
        return RC_TIMEOUT, out + "\n[timeout]"
    if verdict == RC_OOM:
        return RC_OOM, out + "\n[oom]"
    return p.returncode, out


def discover_internal(pattern: str) -> list[str]:
    """Internal tests: immediate test/* dirs holding dut.sv/dut.v/project.f."""
    out = []
    for d in sorted(TEST_DIR.iterdir()):
        if not d.is_dir() or d.name == "run":
            continue
        if not any((d / f).exists() for f in ("dut.sv", "dut.v", "project.f")):
            continue
        if pattern and pattern not in d.name:
            continue
        out.append(d.name)
    return out


def discover_yosys(pattern: str) -> list[str]:
    """Materialize upstream Yosys tests under test/run/** and return their
    paths (relative to test/)."""
    cmd = [str(TEST_DIR / "materialize_yosys_tests.sh")]
    if pattern:
        cmd.append(pattern)
    rc, out = run(cmd, cwd=TEST_DIR)
    if rc != 0:
        sys.stderr.write(f"⚠️  materialization failed:\n{out}\n")
    return [ln.strip() for ln in out.splitlines() if ln.strip().startswith("run/")]


def read_status(test_dir: Path) -> dict[str, tuple[str, int]]:
    """Parse frontend_status.txt -> {frontend: (STATUS, gate_count)}."""
    res: dict[str, tuple[str, int]] = {}
    f = test_dir / "frontend_status.txt"
    if not f.exists():
        return res
    for line in f.read_text().splitlines():
        parts = line.split()
        if len(parts) >= 3:
            res[parts[0]] = (parts[1], int(parts[2]))
    return res


FAIL_STATUS = ("READ_FAIL", "SYNTH_FAIL", "CONVERT_FAIL", "CRASH", "TOOL_MISSING")


def cosim_result(test_rel: str, frontend: str, args) -> str:
    """Verilator co-sim of a frontend's netlist vs the original RTL.
    -> pass/fail/skip/timeout."""
    if args.no_cosim:
        return "skip"
    rc, _ = run([sys.executable, str(TEST_DIR / "test_sim_equivalence.py"),
                 test_rel, "--frontend", frontend, "--cycles", str(args.cycles)],
                cwd=TEST_DIR, timeout=STEP_TIMEOUT)
    if rc == RC_TIMEOUT:
        return "timeout"
    if rc == RC_OOM:
        return "oom"
    return {0: "pass", 1: "fail", 77: "skip"}.get(rc, "fail")


def formal_result(test_rel: str, test_dir: Path, frontend: str,
                  golden_ok: bool) -> str:
    """equiv_pair.sh vs the verilog golden -> equiv/non-equiv/inconclusive/self/n-a."""
    if frontend == "verilog":
        return "self"
    if not golden_ok:
        # The verilog golden itself didn't synthesize, so there is no reference
        # to formally compare against.  Distinct from "n-a": this frontend DID
        # synthesize where verilog couldn't — `make test-all`'s "UHDM-only
        # success".  Kept separate so it isn't lumped into UNKNOWN.
        return "no-golden"
    name = Path(test_rel).name
    gold_v = test_dir / f"{name}_from_verilog_synth.v"
    gate_v = test_dir / f"{name}_from_{frontend}_synth.v"
    if not (gold_v.exists() and gate_v.exists()):
        return "n-a"
    is_formal = (test_dir / "project.f").exists() and \
        any(ln.strip().startswith("#") and "formal" in ln and ":" in ln
            for ln in (test_dir / "project.f").read_text().splitlines())
    cmd = [str(TEST_DIR / "equiv_pair.sh"), str(gold_v), str(gate_v)]
    if is_formal:
        cmd.append("--formal")
    rc, _ = run(cmd, cwd=TEST_DIR, timeout=STEP_TIMEOUT)
    if rc == RC_TIMEOUT:
        return "timeout"
    if rc == RC_OOM:
        return "oom"
    return {0: "equiv", 1: "non-equiv", 2: "inconclusive"}.get(rc, "inconclusive")


def decide(frontend: str, formal: str, cosim: str, golden_cosim: str) -> str:
    """Combine the two oracles into a verdict.

    Ground truth is the ORIGINAL RTL (co-sim).  Formal equivalence is measured
    against the verilog golden netlist, which is only a trustworthy reference
    when the golden itself co-simulates cleanly against that RTL.  This mirrors
    the established harness's adjudication: a divergence is a real frontend bug
    only when the golden agrees with the RTL where this frontend does not; when
    the golden ALSO disagrees with its own RTL, the failure is a Verilator-vs-
    synth artefact and the verdict is UNKNOWN, not INCORRECT.
    """
    # A step that blew the 6-min cap is neither correct nor incorrect — give it
    # its own category so it can't masquerade as a fail/unknown.
    if formal == "oom" or cosim == "oom":
        return "OOM"
    if formal == "timeout" or cosim == "timeout":
        return "TIMEOUT"
    if frontend == "verilog":
        # The golden itself: trust only its co-sim against its own RTL.
        if cosim == "pass":
            return "CORRECT"
        if cosim == "fail":
            return "UNKNOWN"      # disagrees with its own RTL -> harness artefact
        return "CORRECT"          # skip: synthesized, nothing contradicts it

    if formal == "no-golden":
        # Synthesized where the verilog golden could not — no formal reference.
        # Mirrors `make test-all`'s "UHDM-only success": a capability win, not a
        # possible bug, so it gets its own bucket instead of UNKNOWN.
        if cosim == "pass":
            return "CORRECT"          # also matches the original RTL directly
        if cosim == "fail":
            return "UNKNOWN"          # differs from the RTL, and no golden -> unclear
        return "NO-GOLDEN"            # cosim unavailable (e.g. --no-cosim)

    golden_reliable = (golden_cosim == "pass")
    if golden_reliable:
        # Golden is validated against the RTL, so disagreement is a real bug.
        if cosim == "fail" or formal == "non-equiv":
            return "INCORRECT"
        if cosim == "pass" or formal == "equiv":
            return "CORRECT"
        return "UNKNOWN"          # cosim skipped, formal inconclusive/n-a
    # Golden unreliable (its own co-sim failed/skipped): trust RTL co-sim only.
    if cosim == "pass":
        return "CORRECT"          # matches the RTL even if it differs from golden
    if cosim == "fail":
        return "UNKNOWN"          # both differ from RTL -> artefact, can't tell
    if formal == "equiv":
        return "CORRECT"          # cosim unavailable; identical to golden netlist
    return "UNKNOWN"


def safe_process(test_rel: str, args) -> dict:
    """process_test guarded so one test's exception can't abort the sweep."""
    try:
        return process_test(test_rel, args)
    except Exception as e:  # noqa: BLE001 - never let one test kill the run
        row = {"test": test_rel}
        for f in ALL_FRONTENDS:
            row[f"{f}_synth"] = "no"
            row[f"{f}_correct"] = "N/A"
            row[f"{f}_detail"] = f"harness-error: {type(e).__name__}: {e}"
        return row


def process_test(test_rel: str, args) -> dict:
    """Run the full matrix pipeline for one test; return a result row."""
    test_dir = (TEST_DIR / test_rel).resolve()
    row = {"test": test_rel}
    wf_rc, _ = run([str(TEST_DIR / "frontend_matrix_workflow.sh"), test_rel],
                   cwd=TEST_DIR, timeout=900)
    status = read_status(test_dir)
    golden_ok = status.get("verilog", ("", 0))[0] in ("OK", "NO_GATES")

    # Compute the golden's own co-sim once — it gates every other frontend's
    # verdict (and is the verilog column's own oracle).
    golden_cosim = "skip"
    if golden_ok and not args.no_cosim:
        golden_cosim = cosim_result(test_rel, "verilog", args)

    for f in ALL_FRONTENDS:
        st = status.get(f, ("READ_FAIL", 0))[0]
        # If the synth job hit the memory cap (or the wall-time cap) and this
        # frontend never wrote a status, attribute it to OOM/TIMEOUT rather than
        # a spurious READ_FAIL — the job was killed mid-flight, not broken.
        if f not in status and wf_rc == RC_OOM:
            st = "OOM"
        elif f not in status and wf_rc == RC_TIMEOUT:
            st = "TIMEOUT"
        row[f"{f}_synth"] = SYNTH_TOKEN.get(st, "no")
        if f not in args.frontends:
            row[f"{f}_correct"], row[f"{f}_detail"] = "N/A", "skipped"
            continue
        if st == "OOM":
            row[f"{f}_correct"], row[f"{f}_detail"] = "OOM", "synth-oom"
            continue
        if st == "TIMEOUT":
            row[f"{f}_correct"], row[f"{f}_detail"] = "TIMEOUT", "synth-timeout"
            continue
        if st in FAIL_STATUS:
            row[f"{f}_correct"], row[f"{f}_detail"] = "N/A", st
            continue
        formal = formal_result(test_rel, test_dir, f, golden_ok)
        cosim = golden_cosim if f == "verilog" else cosim_result(test_rel, f, args)
        row[f"{f}_correct"] = decide(f, formal, cosim, golden_cosim)
        row[f"{f}_detail"] = f"formal={formal} cosim={cosim} golden_cosim={golden_cosim}"

    # Bound disk: the Verilator co-sim leaves a per-test working dir (obj_dir +
    # build artifacts) that, across 1000+ tests, can fill a CI runner's disk.
    if args.prune:
        import shutil
        for junk in (test_dir / "sim_equiv",):
            shutil.rmtree(junk, ignore_errors=True)
    return row


def write_csv(rows: list[dict], out_csv: Path):
    cols = ["test"]
    for f in ALL_FRONTENDS:
        cols += [f"{f}_synth", f"{f}_correct"]
    with out_csv.open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def write_markdown(rows: list[dict], out_md: Path, args):
    total = len(rows)
    # Per-frontend aggregate counts.
    agg = {f: {"synth_yes": 0, "synth_empty": 0, "synth_no": 0, "crash": 0,
               "missing": 0, "correct": 0, "incorrect": 0, "unknown": 0,
               "no_golden": 0, "timeout": 0, "oom": 0}
           for f in ALL_FRONTENDS}
    for r in rows:
        for f in ALL_FRONTENDS:
            s = r[f"{f}_synth"]
            agg[f]["synth_yes"] += s == "yes"
            agg[f]["synth_empty"] += s == "empty"
            agg[f]["synth_no"] += s == "no"
            agg[f]["crash"] += s == "crash"
            agg[f]["missing"] += s == "missing"
            c = r[f"{f}_correct"]
            agg[f]["correct"] += c == "CORRECT"
            agg[f]["incorrect"] += c == "INCORRECT"
            agg[f]["unknown"] += c == "UNKNOWN"
            # Synthesized but no verilog golden to compare (UHDM-only success).
            agg[f]["no_golden"] += c == "NO-GOLDEN"
            # Timeout: synth blew the cap (synth=timeout) or a formal/co-sim step
            # did (correct=TIMEOUT) — count each test once per frontend.
            agg[f]["timeout"] += c == "TIMEOUT"
            # OOM: a step exceeded the hard memory cap and was killed.
            agg[f]["oom"] += c == "OOM"

    lines = [f"# Frontend Regression Matrix",
             "",
             f"Tests: **{total}**  ·  cycles={args.cycles}  ·  "
             f"frontends={','.join(args.frontends)}"
             f"{'  ·  (formal only, --no-cosim)' if args.no_cosim else ''}",
             "",
             "## Leaderboard",
             "",
             "`Read + synth(gate)` = read OK, netlist has logic gates; "
             "`Read + synth(const)` = read OK but folds to a constant netlist "
             "(0 gates). Both count toward Correct/Incorrect/Unknown.",
             "",
             "`Timeout` = a frontend's synth, formal-equiv, or co-sim exceeded "
             f"the {STEP_TIMEOUT // 60}-min per-step cap.",
             "",
             "`No-golden` = the frontend synthesized but the verilog golden did "
             "NOT, so there is no reference to formally compare against — this is "
             "`make test-all`'s \"UHDM-only success\" (a capability win, not a "
             "possible bug).  `Unknown` is reserved for genuine ambiguity "
             "(formal non-equiv vs the golden with co-sim unavailable); a "
             "`--no-cosim` run cannot adjudicate those, so run with co-sim to "
             "match `make test-all`'s verdict on them.",
             "",
             "| Frontend | Read + synth(gate) | Read + synth(const) | Failed | Crash | Missing | Correct | Incorrect | No-golden | Unknown | Timeout | OOM |",
             "|----------|------------------:|--------------------:|-------:|------:|--------:|--------:|----------:|----------:|--------:|--------:|----:|"]
    for f in ALL_FRONTENDS:
        a = agg[f]
        lines.append(
            f"| `{f}` | {a['synth_yes']} | {a['synth_empty']} | {a['synth_no']} | "
            f"{a['crash']} | {a['missing']} | {a['correct']} | {a['incorrect']} | "
            f"{a['no_golden']} | {a['unknown']} | {a['timeout']} | {a['oom']} |")

    # Disagreements: tests where one frontend is INCORRECT while another is CORRECT.
    disagree = []
    for r in rows:
        verdicts = {f: r[f"{f}_correct"] for f in ALL_FRONTENDS}
        if "INCORRECT" in verdicts.values() and "CORRECT" in verdicts.values():
            disagree.append(r)
    lines += ["", f"## Disagreements ({len(disagree)})",
              "",
              "Tests where at least one frontend is **INCORRECT** while another is "
              "**CORRECT** — the highest-value triage list.", ""]
    if disagree:
        lines.append("| Test | " + " | ".join(ALL_FRONTENDS) + " |")
        lines.append("|------|" + "|".join(["---"] * len(ALL_FRONTENDS)) + "|")
        for r in disagree:
            cells = []
            for f in ALL_FRONTENDS:
                cells.append(f"{r[f'{f}_synth']}/{r[f'{f}_correct']}")
            lines.append(f"| `{r['test']}` | " + " | ".join(cells) + " |")
    else:
        lines.append("_None._")

    lines += ["", "## Incorrect / crashed per frontend", ""]
    for f in ALL_FRONTENDS:
        bad = [r["test"] for r in rows
               if r[f"{f}_correct"] == "INCORRECT" or r[f"{f}_synth"] == "crash"]
        if bad:
            lines.append(f"- **{f}** ({len(bad)}): " +
                         ", ".join(f"`{t}`" for t in bad[:40]) +
                         (" …" if len(bad) > 40 else ""))

    lines += ["", f"## Timeouts per frontend (> {STEP_TIMEOUT // 60} min)", ""]
    any_to = False
    for f in ALL_FRONTENDS:
        to = [r["test"] for r in rows if r[f"{f}_correct"] == "TIMEOUT"]
        if to:
            any_to = True
            lines.append(f"- **{f}** ({len(to)}): " +
                         ", ".join(f"`{t}`" for t in to[:40]) +
                         (" …" if len(to) > 40 else ""))
    if not any_to:
        lines.append("_None._")
    lines.append("")
    out_md.write_text("\n".join(lines))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pattern", nargs="?", default="",
                    help="substring filter on test name/path")
    ap.add_argument("--yosys", action="store_true",
                    help="run upstream Yosys tests instead of internal ones")
    ap.add_argument("--all", action="store_true",
                    help="run both internal and upstream Yosys tests")
    ap.add_argument("--cycles", type=int, default=200)
    ap.add_argument("--jobs", type=int, default=1)
    ap.add_argument("--frontends", default=",".join(ALL_FRONTENDS),
                    help="comma list subset to correctness-check (default all)")
    ap.add_argument("--no-cosim", action="store_true",
                    help="skip Verilator co-sim (formal equivalence only)")
    ap.add_argument("--prune", action="store_true",
                    help="delete each test's sim_equiv working dir after its "
                         "verdict (bounds disk usage on CI)")
    ap.add_argument("--out", default=str(TEST_DIR / "frontend_matrix"),
                    help="output path prefix (.csv / FRONTEND_MATRIX.md)")
    ap.add_argument("--shard", default="",
                    help="run only shard I of N (1-based, e.g. 2/4) so the test "
                         "list can be split across parallel CI runners")
    ap.add_argument("--combine", default="",
                    help="combine mode: glob of shard CSVs to merge into the "
                         "final frontend_matrix.csv + FRONTEND_MATRIX.md, then exit")
    args = ap.parse_args()
    args.frontends = [f.strip() for f in args.frontends.split(",") if f.strip()]

    # --- combine mode: merge shard CSVs into the final report and exit ---------
    if args.combine:
        import glob
        merged: list[dict] = []
        seen: set = set()
        for csv_path in sorted(glob.glob(args.combine)):
            for r in csv.DictReader(open(csv_path)):
                if r["test"] not in seen:
                    seen.add(r["test"])
                    merged.append(r)
        merged.sort(key=lambda r: r["test"])
        write_csv(merged, Path(args.out + ".csv"))
        write_markdown(merged, TEST_DIR / "FRONTEND_MATRIX.md", args)
        print(f"✅ combined {len(merged)} rows from {args.combine}")
        return 0

    tests: list[str] = []
    if args.all:
        tests = discover_internal(args.pattern) + discover_yosys(args.pattern)
    elif args.yosys:
        tests = discover_yosys(args.pattern)
    else:
        tests = discover_internal(args.pattern)

    tests.sort()
    # --- shard selection: keep every Nth test (strided so heavy/light tests
    # spread evenly across shards) ---------------------------------------------
    if args.shard:
        si, _, sn = args.shard.partition("/")
        si, sn = int(si), int(sn)
        if not (1 <= si <= sn):
            sys.exit(f"❌ bad --shard {args.shard} (expect I/N, 1<=I<=N)")
        tests = tests[si - 1::sn]
        print(f"▶ shard {si}/{sn}")

    if not tests:
        print("No tests matched.")
        return 1
    print(f"▶ {len(tests)} test(s) × {len(ALL_FRONTENDS)} frontends "
          f"(jobs={args.jobs}, cycles={args.cycles})")

    rows: list[dict] = []
    if args.jobs > 1:
        with ThreadPoolExecutor(max_workers=args.jobs) as ex:
            futs = {ex.submit(safe_process, t, args): t for t in tests}
            for i, fut in enumerate(as_completed(futs), 1):
                r = fut.result()
                rows.append(r)
                print(f"  [{i}/{len(tests)}] {r['test']}")
    else:
        for i, t in enumerate(tests, 1):
            r = safe_process(t, args)
            rows.append(r)
            summ = " ".join(f"{f}:{r[f'{f}_synth']}/{r[f'{f}_correct']}"
                            for f in ALL_FRONTENDS)
            print(f"  [{i}/{len(tests)}] {t}  {summ}")

    rows.sort(key=lambda r: r["test"])
    out_csv = Path(args.out + ".csv")
    write_csv(rows, out_csv)
    # Sharded runs only emit their CSV; the combine step builds the global
    # Markdown report from all shards.
    if args.shard:
        print(f"\n✅ wrote {out_csv} (shard {args.shard})")
        return 0
    out_md = TEST_DIR / "FRONTEND_MATRIX.md"
    write_markdown(rows, out_md, args)
    print(f"\n✅ wrote {out_csv} and {out_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
