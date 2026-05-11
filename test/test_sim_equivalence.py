#!/usr/bin/env python3
"""Verilator-based simulation equivalence check for UHDM-only tests.

When the Yosys Verilog frontend can't parse the SystemVerilog the test
uses, we have no reference netlist to formally equivalence-check
against.  Instead, we use Verilator as the reference:

  RTL form  — the original `dut.sv` simulated directly by Verilator
  Netlist   — UHDM-frontend output, post-`synth -auto-top`

A SystemVerilog testbench instantiates both side by side, drives
shared clocks/resets/random inputs, and compares outputs cycle by
cycle.  A mismatch indicates a bug in the UHDM-frontend output or in
the synthesis flow driven by our generated RTLIL.

Pipeline:
  1. Generate the synthesized netlist Verilog (Yosys + UHDM frontend),
     renaming the top module to `dut_netlist`.
  2. Extract clocks / resets / port list from the netlist using the
     `extract_clocks_resets` Yosys plugin.
  3. Emit a SystemVerilog wrapper that aliases the original SV top
     module to `dut_rtl`, plus a testbench that instantiates `dut_rtl`
     and `dut_netlist`, drives shared inputs, and compares outputs.
  4. Build with Verilator and run; non-zero exit on mismatch.
"""

from __future__ import annotations
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def sh(cmd: list[str], cwd: Path | None = None, check: bool = True) -> str:
    """Run a command, return stdout.  Print stderr on failure."""
    p = subprocess.run(cmd, cwd=cwd, check=False, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and p.returncode != 0:
        sys.stderr.write(f"$ {' '.join(cmd)}\n{p.stdout}\n{p.stderr}\n")
        sys.exit(p.returncode)
    return p.stdout


def find_paths(project_root: Path) -> dict[str, Path]:
    paths = {
        "yosys":          project_root / "out/current/bin/yosys",
        "uhdm_plugin":    project_root / "build/uhdm2rtlil.so",
        "cr_plugin":      project_root / "build/extract_clocks_resets.so",
        "simcells":       project_root / "out/current/share/yosys/simcells.v",
        "simlib":         project_root / "out/current/share/yosys/simlib.v",
    }
    for k, p in paths.items():
        if not p.exists():
            sys.exit(f"❌ missing {k}: {p}")
    return paths


def find_top_module(dut_path: Path) -> str:
    """Heuristic: the SV top module is the LAST `module <name>` declaration
    that isn't `endmodule`.  In tests using inner+outer wrappers this is
    typically the outer wrapper that takes the runtime stimulus."""
    last = None
    for line in dut_path.read_text().splitlines():
        m = re.match(r"\s*module\s+([A-Za-z_][A-Za-z0-9_]*)", line)
        if m:
            last = m.group(1)
    if last is None:
        sys.exit(f"❌ no `module` declaration in {dut_path}")
    return last


def synth_to_netlist(yosys: Path, uhdm_plugin: Path,
                     uhdm: Path, out_v: Path) -> None:
    # `$check` cells (concurrent / immediate assertions) and `$print`
    # cells ($display) have no Verilator-compatible behavioural model,
    # and they're not the subject of the equivalence check anyway.
    # Delete them before writing the netlist.
    script = (
        f"read_uhdm {uhdm}\n"
        f"synth -auto-top\n"
        f"delete t:$check t:$print\n"
        f"flatten\n"
        f"opt_clean\n"
        f"rename -top dut_netlist\n"
        f"write_verilog -noattr -noexpr {out_v}\n"
    )
    sh([str(yosys), "-q", "-m", str(uhdm_plugin), "-p", script])


def extract_ports(yosys: Path, cr_plugin: Path, simcells: Path,
                  netlist_v: Path, out_txt: Path) -> None:
    script = (
        f"read_verilog -nolatches {simcells} {netlist_v}\n"
        f"hierarchy -top dut_netlist\n"
        f"extract_clocks_resets -o {out_txt}\n"
    )
    sh([str(yosys), "-q", "-m", str(cr_plugin), "-p", script])


def parse_ports(path: Path) -> tuple[list[tuple[str, int, str]],
                                     list[str],
                                     dict[str, bool]]:
    ports: list[tuple[str, int, str]] = []
    clocks: set[str] = set()
    resets: dict[str, bool] = {}
    for line in path.read_text().splitlines():
        toks = line.split()
        if not toks:
            continue
        if toks[0] == "PORT":
            ports.append((toks[1], int(toks[2]), toks[3]))
        elif toks[0] == "CLOCK":
            clocks.add(toks[1])
        elif toks[0] == "RESET":
            resets[toks[1]] = toks[2] == "1"
    return ports, sorted(clocks), resets


def emit_wrapper_and_tb(dut_path: Path,
                       orig_top: str,
                       ports: list[tuple[str, int, str]],
                       clocks: list[str],
                       resets: dict[str, bool],
                       out_dir: Path) -> None:
    """Write `tb.sv` (wraps both DUTs as a non-clocking pass-through) and
    `tb_main.cpp` (drives the simulation cycle by cycle).

    We avoid `--timing` so the testbench is compatible with older
    Verilator releases.  Clocks and reset are advanced from C++ via
    `eval()` calls; the SV side is purely structural."""

    inputs = [(n, w) for (n, w, d) in ports
              if d in ("input", "inout")
              and n not in clocks and n not in resets]
    outputs = [(n, w) for (n, w, d) in ports if d == "output"]
    if not outputs:
        # Self-checking testbench: input-only DUT with internal asserts.
        # Nothing for an external co-sim to compare — not a failure, just
        # not applicable.  Exit 77 (the autotools convention for "skip").
        print("⏭  no output ports — self-checking DUT, sim-equiv N/A")
        sys.exit(77)

    # Wrapper: instantiate the original SV top under the name dut_rtl.
    port_decl = []
    for n, w, d in ports:
        rng = f" [{w-1}:0]" if w > 1 else ""
        port_decl.append(f"  {d}{rng} {n}")
    wrapper_lines = [
        "// Auto-generated: wraps the original SV top as `dut_rtl`.",
        f"module dut_rtl (\n" + ",\n".join(port_decl) + "\n);",
        f"  {orig_top} u_orig (",
        ",\n".join(f"    .{n}({n})" for (n, _w, _d) in ports),
        "  );",
        "endmodule",
        "",
    ]
    (out_dir / "wrapper.sv").write_text("\n".join(wrapper_lines))

    # Top SV testbench: pure structural — exposes the union of ports so
    # the C++ driver can poke clocks, resets, and inputs directly.
    L = ["// Auto-generated tb: exposes both DUTs as a flat interface.",
         "module tb ("]
    sigs = []
    for c in clocks:
        sigs.append(f"  input  logic {c}")
    for r in resets:
        sigs.append(f"  input  logic {r}")
    for n, w in inputs:
        rng = f" [{w-1}:0]" if w > 1 else ""
        sigs.append(f"  input  logic{rng} {n}")
    for n, w in outputs:
        rng = f" [{w-1}:0]" if w > 1 else ""
        sigs.append(f"  output logic{rng} rtl_{n}")
        rng = f" [{w-1}:0]" if w > 1 else ""
        sigs.append(f"  output logic{rng} nl_{n}")
    L.append(",\n".join(sigs))
    L.append(");")

    def inst(mod, prefix):
        L.append("")
        L.append(f"  {mod} u_{prefix.strip('_')} (")
        conn = []
        for n, _w, d in ports:
            conn.append(f"    .{n}({prefix}{n})" if d == "output"
                        else f"    .{n}({n})")
        L.append(",\n".join(conn))
        L.append("  );")
    inst("dut_rtl",     "rtl_")
    inst("dut_netlist", "nl_")
    L.append("endmodule")
    (out_dir / "tb.sv").write_text("\n".join(L))

    # C++ driver
    seed = 42
    cycles = 200
    reset_cycles = 5

    cpp = []
    cpp += [
        "#include <cstdio>",
        "#include <cstdint>",
        "#include <cstdlib>",
        "#include \"Vtb.h\"",
        "",
        "int main(int argc, char** argv) {",
        "    Vtb tb;",
        "    int mismatches = 0;",
    ]
    # Init all driven inputs
    for c in clocks:
        cpp.append(f"    tb.{c} = 0;")
    for r, ah in resets.items():
        cpp.append(f"    tb.{r} = {1 if ah else 0};  // assert reset")
    for n, _w in inputs:
        cpp.append(f"    tb.{n} = 0;")
    cpp.append("    tb.eval();")

    if clocks:
        clk = clocks[0]
        cpp.append("    // Reset phase: hold reset asserted for several clock cycles")
        cpp.append(f"    for (int i = 0; i < {reset_cycles}; ++i) {{")
        cpp.append(f"        tb.{clk} = 0; tb.eval();")
        cpp.append(f"        tb.{clk} = 1; tb.eval();")
        cpp.append("    }")
        for r, ah in resets.items():
            cpp.append(f"    tb.{r} = {0 if ah else 1};  // de-assert reset")
        cpp.append(f"    tb.eval();")
        cpp.append(f"    srand({seed});")
        cpp.append(f"    for (int cycle = 0; cycle < {cycles}; ++cycle) {{")
        # Drive inputs before negedge / posedge
        for n, w in inputs:
            if w <= 32:
                cpp.append(f"        tb.{n} = (uint32_t)rand();")
            else:
                cpp.append(f"        tb.{n} = ((uint64_t)rand() << 32) | (uint32_t)rand();")
        cpp.append(f"        tb.{clk} = 0; tb.eval();")
        cpp.append(f"        tb.{clk} = 1; tb.eval();")
        for n, w in outputs:
            # Verilator C++ codegen returns sub-byte signals as uint8_t with
            # uninitialised upper bits, so mask to the declared port width
            # before comparing.  For >64-bit ports we'd need __VlWide
            # handling; cap at 64 for now and skip the test if wider.
            mask = "((1ULL << %d) - 1)" % w if w < 64 else "~0ULL"
            cpp.append(f"        {{ unsigned long long r = (unsigned long long)tb.rtl_{n} & {mask};")
            cpp.append(f"          unsigned long long s = (unsigned long long)tb.nl_{n}  & {mask};")
            cpp.append(f"          if (r != s) {{")
            cpp.append(f"            std::printf(\"MISMATCH cycle %d: {n}: rtl=0x%llx nl=0x%llx\\n\","
                       f" cycle, r, s);")
            cpp.append("            mismatches++;")
            cpp.append("          } }")
        cpp.append("    }")
    else:
        cpp.append(f"    srand({seed});")
        cpp.append(f"    for (int cycle = 0; cycle < {cycles}; ++cycle) {{")
        for n, w in inputs:
            if w <= 32:
                cpp.append(f"        tb.{n} = (uint32_t)rand();")
            else:
                cpp.append(f"        tb.{n} = ((uint64_t)rand() << 32) | (uint32_t)rand();")
        cpp.append("        tb.eval();")
        for n, w in outputs:
            mask = "((1ULL << %d) - 1)" % w if w < 64 else "~0ULL"
            cpp.append(f"        {{ unsigned long long r = (unsigned long long)tb.rtl_{n} & {mask};")
            cpp.append(f"          unsigned long long s = (unsigned long long)tb.nl_{n}  & {mask};")
            cpp.append(f"          if (r != s) {{")
            cpp.append(f"            std::printf(\"MISMATCH cycle %d: {n}: rtl=0x%llx nl=0x%llx\\n\","
                       f" cycle, r, s);")
            cpp.append("            mismatches++;")
            cpp.append("          } }")
        cpp.append("    }")
    cpp += [
        f"    if (mismatches == 0)",
        f"        std::printf(\"PASS: {cycles} cycles, 0 mismatches\\n\");",
        "    else",
        f"        std::printf(\"FAIL: {cycles} cycles, %d mismatches\\n\", mismatches);",
        "    return mismatches == 0 ? 0 : 1;",
        "}",
        "",
    ]
    (out_dir / "tb_main.cpp").write_text("\n".join(cpp))


def run_verilator(work: Path, paths: dict[str, Path], dut_path: Path) -> tuple[int, str]:
    cmd = [
        "verilator", "--cc", "--exe", "--build", "-j", "4",
        "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED", "-Wno-UNOPTFLAT",
        "-Wno-CASEINCOMPLETE", "-Wno-MULTIDRIVEN",
        "--top-module", "tb",
        # simcells.v contains the $_DFF_*/$_MUX_/... gate-level cells;
        # simlib.v has higher-level primitives (and a `tran` that older
        # Verilator can't parse) — synth doesn't emit those, so skip.
        str(paths["simcells"]),
        str(dut_path), "wrapper.sv", "dut_netlist.v", "tb.sv",
        "tb_main.cpp",
    ]
    p = subprocess.run(cmd, cwd=work, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        return p.returncode, "[verilator build failed]\n" + p.stdout
    p2 = subprocess.run(["./obj_dir/Vtb"], cwd=work, text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return p2.returncode, p2.stdout


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("test_name", help="test directory under test/")
    args = ap.parse_args()

    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent
    test_dir = Path(args.test_name) if Path(args.test_name).is_absolute() \
        else Path.cwd() / args.test_name

    if not test_dir.is_dir():
        sys.exit(f"❌ test dir not found: {test_dir}")

    paths = find_paths(project_root)
    uhdm = test_dir / "slpp_all/surelog.uhdm"
    if not uhdm.exists():
        sys.exit(f"❌ no UHDM at {uhdm} — run the standard workflow first")

    dut = test_dir / "dut.sv"
    if not dut.exists():
        dut = test_dir / "dut.v"
    if not dut.exists():
        sys.exit(f"❌ no dut.sv / dut.v in {test_dir}")

    work = test_dir / "sim_equiv"
    if work.exists():
        for f in work.iterdir():
            if f.is_dir():
                import shutil
                shutil.rmtree(f)
            else:
                f.unlink()
    work.mkdir(exist_ok=True)

    orig_top = find_top_module(dut)
    print(f"▶ original SV top: {orig_top}")

    print("▶ Generating synthesized netlist from UHDM")
    synth_to_netlist(paths["yosys"], paths["uhdm_plugin"],
                     uhdm, work / "dut_netlist.v")

    print("▶ Extracting clocks/resets/ports")
    extract_ports(paths["yosys"], paths["cr_plugin"],
                  paths["simcells"], work / "dut_netlist.v",
                  work / "ports.txt")
    ports, clocks, resets = parse_ports(work / "ports.txt")
    print(f"  ports={len(ports)} clocks={clocks} resets={list(resets)}")

    print("▶ Emitting wrapper + testbench")
    emit_wrapper_and_tb(dut, orig_top, ports, clocks, resets, work)

    print("▶ Running Verilator co-sim")
    rc, out = run_verilator(work, paths, dut)
    # Trim Verilator noise so the PASS/FAIL line is easy to find
    for line in out.splitlines()[-15:]:
        print(line)
    if "PASS:" in out and "MISMATCH" not in out and "FAIL:" not in out:
        return 0
    print("❌ simulation reported a mismatch or did not complete")
    return 1 if rc == 0 else rc


if __name__ == "__main__":
    sys.exit(main())
