#!/usr/bin/env python3
"""Emit per-module Pavona parameter bindings: wrappers/params_<mod>.txt.

Pavona's core processor is Ibex at the security-hardened OpenTitan-style
configuration (hw/top_egret/ip_autogen/rv_core_ibex/rtl/rv_core_ibex.sv
defaults).  For each ibex module, the file lists `NAME VALUE` for every
parameter the module declares that the Pavona binding sets — numeric
values, so the SAME overrides feed both elaborations:

    surelog  -PNAME=VALUE ...     (read_uhdm side)
    read_slang -GNAME=VALUE ...   (reference side)

Enum values are the ibex_pkg integer encodings (rv32m_e RV32MSingleCycle=3,
rv32b_e RV32BOTEarlGrey=2, rv32zc_e RV32ZcaZcbZcmp=3, regfile_e RegFileFF=0).
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
IBEX = HERE / "rtl" / "ibex"
WRAP = HERE / "wrappers"

# name: (numeric for surelog -P, SV expression for read_slang -G).
# slang refuses an implicit int->enum conversion, so enum-typed values use
# the package-scoped enum literal on the -G side.
PAVONA = {
    "PMPEnable":        ("1", "1"),
    "PMPGranularity":   ("0", "0"),
    "PMPNumRegions":    ("16", "16"),
    "MHPMCounterNum":   ("10", "10"),
    "MHPMCounterWidth": ("32", "32"),
    "RV32E":            ("0", "0"),
    "RV32M":            ("3", "ibex_pkg::RV32MSingleCycle"),
    "RV32B":            ("2", "ibex_pkg::RV32BOTEarlGrey"),
    "RV32ZC":           ("3", "ibex_pkg::RV32ZcaZcbZcmp"),
    "RegFile":          ("0", "ibex_pkg::RegFileFF"),
    "BranchTargetALU":  ("1", "1"),
    "WritebackStage":   ("1", "1"),
    "ICache":           ("1", "1"),
    "ICacheECC":        ("1", "1"),
    "ICacheScramble":   ("1", "1"),
    "ICacheNWays":      ("2", "2"),
    "BranchPredictor":  ("0", "0"),
    "DbgTriggerEn":     ("1", "1"),
    "DbgHwBreakNum":    ("4", "4"),
    "SecureIbex":       ("1", "1"),
    "DmBaseAddr":       ("437321728", "437321728"),    # 32'h1A110000
    "DmAddrMask":       ("4095", "4095"),              # 32'h00000FFF
    "DmHaltAddr":       ("437325824", "437325824"),    # 32'h1A110800
    "DmExceptionAddr":  ("437325832", "437325832"),    # 32'h1A110808
}


def module_params(src: Path, mod: str):
    text = re.sub(r"//[^\n]*", "", src.read_text())
    m = re.search(rf"\bmodule\s+{mod}\b(.*?)\)\s*\(", text, re.DOTALL)
    return re.findall(r"\bparameter\b[^=,\n]*?([A-Za-z_]\w*)\s*=",
                      m.group(1)) if m else []


def main():
    WRAP.mkdir(exist_ok=True)
    mods = sys.argv[1:] or sorted(
        f.stem for f in IBEX.glob("ibex_*.sv")
        if not f.stem.endswith("_pkg") and "tracer" not in f.stem
        and f.stem != "ibex_top_tracing")
    for mod in mods:
        params = module_params(IBEX / f"{mod}.sv", mod)
        ovr = [(p, *PAVONA[p]) for p in params if p in PAVONA]
        (WRAP / f"params_{mod}.txt").write_text(
            "".join(f"{k} {n} {g}\n" for k, n, g in ovr))
        print(f"{mod}: {len(ovr)} overrides"
              + ("" if ovr else " (module defaults)"))


if __name__ == "__main__":
    main()
