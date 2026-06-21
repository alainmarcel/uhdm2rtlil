#!/usr/bin/env python3
"""cosim_netlist.py — thin wrapper around test_sim_equivalence.py that
co-simulates a chosen frontend's synthesized netlist against the original RTL.

The real work lives in test_sim_equivalence.py (which gained a `--frontend`
option); this wrapper just gives the 4-frontend matrix a stable entry point.

Usage:  cosim_netlist.py <test_dir> --frontend {uhdm,verilog,sv2v,slang} [--cycles N]
Exit:   0 = PASS, 1 = mismatch, 77 = SKIP (Verilator can't build / no outputs)
"""
import runpy
import sys
from pathlib import Path

if __name__ == "__main__":
    # Default the frontend if the caller didn't pass one.
    if not any(a.startswith("--frontend") for a in sys.argv[1:]):
        sys.argv.extend(["--frontend", "uhdm"])
    target = Path(__file__).resolve().parent / "test_sim_equivalence.py"
    sys.argv[0] = str(target)
    runpy.run_path(str(target), run_name="__main__")
