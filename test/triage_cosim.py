#!/usr/bin/env python3
"""Triage a co-sim divergence: real UHDM-frontend bug, or sim/synth artefact?

For a test in the sim_equiv_analyzed.txt backlog, runs TWO independent checks
and prints a verdict.

  1. SAT-from-reset formal MITER (UHDM-synth vs Verilog-synth).
     This is the SOUND equivalence check.  `test_equivalence.sh` uses
     equiv_make/equiv_induct, which has a known blind spot (it silently
     passes some non-equivalent designs).  A miter counterexample means the
     UHDM frontend synthesises logic that genuinely DIFFERS from the Verilog
     frontend  ==>  REAL BUG (and equiv_induct missed it).
     Both designs are synthesised FRESH from source (no write_verilog
     round-trip), so the cells are internal $_*_/coarse types that satgen can
     model directly — no public-typed-cell chtype dance needed.

  2. Both-frontends Verilator CO-SIM (each netlist vs the original RTL),
     reusing the test_sim_equivalence.py harness.  If only the UHDM netlist
     diverges from the RTL  ==>  REAL BUG; if BOTH diverge the same way
     ==>  ARTEFACT (a Verilator-vs-synth difference: latch/X-init/wand-wor/
     full_case/initial-reads-input/...).

Verdict:
  🐛 REAL BUG  — miter finds a counterexample, OR uhdm co-sim fails while
                 verilog co-sim passes.
  🔬 ARTEFACT  — miter proves equivalence AND (both co-sims fail, or both
                 pass).
  ❓ INCONCLUSIVE otherwise (miter timed out / build issue) — investigate.

Usage:  python3 triage_cosim.py <test_name> [--cycles N] [--seq N] [--no-cosim]
"""
from __future__ import annotations
import argparse
import re
import subprocess
import sys
from pathlib import Path

import test_sim_equivalence as H   # reuse the co-sim harness


def sh(cmd, **kw):
    return subprocess.run(cmd, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, **kw)


def _chtype_block() -> str:
    """Grab the public->internal gate chtype mappings from test_equivalence.sh
    so satgen can model the public-typed cells in the synth .v files."""
    eq = (Path(__file__).resolve().parent / "test_equivalence.sh").read_text()
    return "\n".join(l.strip() for l in eq.splitlines()
                     if l.strip().startswith("chtype -map"))


def sat_miter(paths, test_dir: Path, uhdm: Path, seq: int) -> tuple[str, str]:
    """Run the SAT-from-reset miter (UHDM gate vs Verilog gold).

    Uses the already-generated gate-level synth .v files (no UHDM-frontend
    log noise) and the chtype block from test_equivalence.sh so satgen can
    model the public-typed cells.  Returns (verdict, detail) where verdict is
    'EQUIVALENT' / 'NON-EQUIVALENT' / 'INCONCLUSIVE'."""
    base = test_dir.name
    vlog_synth = test_dir / f"{base}_from_verilog_synth.v"
    uhdm_synth = test_dir / f"{base}_from_uhdm_synth.v"
    if not (vlog_synth.exists() and uhdm_synth.exists()):
        return "INCONCLUSIVE", "missing *_synth.v (run the workflow first)"
    yosys = str(paths["yosys"])
    chtype = _chtype_block()
    script = f"""
        read_verilog -lib +/simcells.v
        read_verilog -sv {vlog_synth}
        hierarchy -auto-top
        proc
        flatten
        opt -purge
        rename -top gold
        design -stash GOLD

        design -reset
        read_verilog -lib +/simcells.v
        read_verilog -sv {uhdm_synth}
        hierarchy -auto-top
        proc
        flatten
        opt -purge
        rename -top gate
        design -stash GATE

        design -copy-from GOLD -as gold gold
        design -copy-from GATE -as gate gate
        {chtype}
        async2sync
        miter -equiv -make_assert -make_outputs -flatten gold gate miter
        hierarchy -top miter
        sat -prove-asserts -seq {seq} -set-init-zero miter
    """
    p = sh([yosys, "-p", script])
    out = p.stdout
    if ("Assert failed" in out or "SAT model found" in out or
            "proof did fail" in out or "FAIL!" in out):
        m = re.search(r"Assert failed in miter: (\S+)", out)
        return "NON-EQUIVALENT", (m.group(1) if m else "counterexample found")
    if ("Assert passed" in out or "no model found" in out or "SUCCESS" in out):
        return "EQUIVALENT", "miter proved equivalent (bounded from reset)"
    err = [l for l in out.splitlines() if "ERROR" in l or "Error" in l]
    return "INCONCLUSIVE", (err[-1] if err else "no clear SAT verdict")


def cosim(test_name: str, cycles: int) -> str:
    """Run the harness co-sim (UHDM netlist vs RTL).  Returns PASS/FAIL/SKIP."""
    p = sh([sys.executable, "test_sim_equivalence.py", test_name,
            "--cycles", str(cycles)])
    if p.returncode == 77:
        return "SKIP"
    return "PASS" if ("PASS:" in p.stdout and "MISMATCH" not in p.stdout) else "FAIL"


def cosim_verilog(paths, test_dir: Path, cycles: int) -> str:
    """Co-sim the VERILOG-frontend netlist vs RTL, reusing the harness tb."""
    proj = H.parse_project_f(test_dir)
    dut = proj["srcs"][0]
    srcs = " ".join(str(p) for p in proj["srcs"])
    work = test_dir / "sim_equiv_vlog"
    if work.exists():
        for f in work.iterdir():
            f.unlink() if f.is_file() else None
    work.mkdir(exist_ok=True)
    out_v = work / "dut_netlist.v"
    # Synthesise the Verilog frontend the same way the harness does for UHDM.
    sh([str(paths["yosys"]), "-q", "-p",
        f"read_verilog -sv {srcs}; synth -auto-top; flatten; opt_clean; "
        f"rename -top dut_netlist; write_verilog -noattr {out_v}"])
    if not out_v.exists():
        return "BUILD-FAIL"
    yosys_top = ""
    H.extract_ports(paths["yosys"], paths["cr_plugin"], paths["simcells"],
                    out_v, work / "ports.txt")
    ports, clocks, resets = H.parse_ports(work / "ports.txt")
    orig_top = proj["top"] or H.find_top_module(dut)
    unpacked = H.detect_unpacked_array_ports(dut, orig_top)
    H.emit_wrapper_and_tb(dut, orig_top, ports, clocks, resets, work,
                          unpacked=unpacked, cycles=cycles)
    rc, out = H.run_verilator(work, paths, proj["srcs"])
    if "[verilator build failed]" in out:
        return "BUILD-FAIL"
    return "PASS" if ("PASS:" in out and "MISMATCH" not in out) else "FAIL"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("test_name")
    ap.add_argument("--cycles", type=int, default=200)
    ap.add_argument("--seq", type=int, default=20,
                    help="SAT miter bounded depth from reset")
    ap.add_argument("--no-cosim", action="store_true")
    args = ap.parse_args()

    root = Path(__file__).resolve().parent
    test_dir = root / args.test_name
    if not test_dir.is_dir():
        sys.exit(f"❌ no test dir {test_dir}")
    paths = H.find_paths(root.parent)
    uhdm = test_dir / "slpp_all/surelog.uhdm"
    if not uhdm.exists():
        sys.exit(f"❌ no UHDM at {uhdm} — run the workflow first")

    print(f"=== triage: {args.test_name} ===")
    mv, md = sat_miter(paths, test_dir, uhdm, args.seq)
    print(f"  SAT miter (UHDM vs Verilog, sound):  {mv}  — {md}")

    uc = vc = "(skipped)"
    if not args.no_cosim:
        uc = cosim(args.test_name, args.cycles)
        vc = cosim_verilog(paths, test_dir, args.cycles)
        print(f"  Verilator co-sim UHDM vs RTL:        {uc}")
        print(f"  Verilator co-sim Verilog vs RTL:     {vc}")

    # Verdict
    if mv == "NON-EQUIVALENT" or (uc == "FAIL" and vc == "PASS"):
        verdict = "🐛 REAL BUG (UHDM frontend differs from Verilog)"
    elif mv == "EQUIVALENT" and (uc == vc or vc in ("BUILD-FAIL", "SKIP")):
        verdict = "🔬 ARTEFACT (UHDM == Verilog; co-sim diff is Verilator-vs-synth)"
    else:
        verdict = "❓ INCONCLUSIVE — investigate manually"
    print(f"  VERDICT: {verdict}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
