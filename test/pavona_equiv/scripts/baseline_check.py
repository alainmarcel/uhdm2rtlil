#!/usr/bin/env python3
"""Baseline-support survey for the Pavona Ibex modules.

Before any UHDM equivalence work, verify that both baselines handle every
module of the core processor:
  1. read_slang (built into our yosys) elaborates it, and
  2. Verilator (--lint-only) accepts it,
each standalone with the packages + prims on the include/file path.  The
result table seeds pavona_modules.txt.

    baseline_check.py [--module NAME]
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
ROOT = HERE.parent.parent
YOSYS = ROOT / "out" / "current" / "bin" / "yosys"
IBEX = HERE / "rtl" / "ibex"
PRIM = HERE / "rtl" / "prim"

PKGS = ["prim_pkg.sv", "prim_util_pkg.sv", "prim_count_pkg.sv",
        "prim_mubi_pkg.sv", "prim_secded_pkg.sv", "prim_cipher_pkg.sv",
        "prim_ram_1p_pkg.sv"]
IBEX_PKGS = ["ibex_pkg.sv", "ibex_tracer_pkg.sv"]


def prim_sources():
    srcs = [PRIM / p for p in PKGS if (PRIM / p).exists()]
    srcs += [f for f in sorted(PRIM.glob("prim_*.sv"))
             if f.name not in PKGS and not f.name.endswith("_macros.sv")]
    return srcs


def sh(cmd, timeout=300):
    try:
        p = subprocess.run(cmd, cwd=HERE, text=True, timeout=timeout,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or "") + "\n[timeout]"


def check_module(mod):
    # Full file set: the target instantiates siblings (ex_block -> alu/multdiv,
    # core -> everything), so every ibex module rides along.  The tracer pair
    # only when the target needs it (it is DV collateral, not synth RTL).
    ibex_files = [f for f in sorted(IBEX.glob("*.sv"))
                  if ("tracer" not in f.name or "tracing" in mod)
                  and not f.name.endswith("_pkg.sv")]
    # Verilator compiles single-pass: packages must precede their users.
    pkgs = [IBEX / p for p in IBEX_PKGS if (IBEX / p).exists()]
    srcs = pkgs + prim_sources() + ibex_files
    row = {"module": mod}

    # 1. slang elaboration through our yosys.
    cmd = " ".join(["read_slang", "--ignore-assertions", "-DSYNTHESIS",
                    "-I", str(PRIM), "-I", str(IBEX),
                    *[str(s) for s in srcs], "--top", mod])
    rc, out = sh([str(YOSYS), "-q", "-p", cmd])
    if rc == 0:
        row["slang"] = "✅"
    else:
        m = re.search(r"error: ([^\n]+)", out)
        row["slang"] = "❌ " + (m.group(1)[:60] if m else f"rc={rc}")

    # 2. Verilator lint.
    rc, out = sh(["verilator", "--lint-only", "-Wno-fatal", "--timing",
                  "--no-assert", "-DSYNTHESIS",
                  "-I" + str(PRIM), "-I" + str(IBEX),
                  *[str(s) for s in srcs], "--top-module", mod])
    if rc == 0:
        row["verilator"] = "✅"
    else:
        m = re.search(r"%Error[^\n]*: ([^\n]+)", out)
        row["verilator"] = "❌ " + (m.group(1)[:60] if m else f"rc={rc}")
    return row


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module")
    args = ap.parse_args()
    mods = ([args.module] if args.module else
            sorted(f.stem for f in IBEX.glob("ibex_*.sv")
                   if not f.stem.endswith("_pkg") and "tracer" not in f.stem))
    rows = [check_module(m) for m in mods]
    print("| module | read_slang | Verilator |")
    print("|---|---|---|")
    for r in rows:
        print(f"| {r['module']} | {r['slang']} | {r['verilator']} |")
    ok = sum(1 for r in rows
             if r["slang"] == "✅" and r["verilator"] == "✅")
    print(f"\nBoth baselines OK: {ok}/{len(rows)}")


if __name__ == "__main__":
    sys.exit(main())
