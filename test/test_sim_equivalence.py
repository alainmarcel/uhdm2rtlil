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


def detect_unpacked_array_ports(dut_path: Path,
                                orig_top: str) -> dict[str, int]:
    """Find input/output ports declared with an unpacked-array dimension
    like `input logic [W:0] iP [4]` — Yosys flattens them to a single
    flat-width wire, but Verilator still sees the original unpacked-array
    port on the RTL side and rejects a flat connection.  Return
    {port_name: element_count} so the wrapper can emit the appropriate
    assignment pattern (`'{flat[E-1:0], flat[2E-1:E], …}`).

    Limited to constant unpacked dims `[N]` or `[N-1:0]`; anything with a
    parameter or non-trivial expression is left for a follow-up.
    """
    text = dut_path.read_text()
    # Strip line/block comments globally before searching for the module
    # header so commented-out parens don't confuse the bracket counter.
    clean = re.sub(r"//[^\n]*", "", text)
    clean = re.sub(r"/\*.*?\*/", "", clean, flags=re.DOTALL)

    # Locate `module <orig_top>` and walk forward to find the port list,
    # skipping the optional `#(...)` parameter block in between.
    head = re.search(rf"\bmodule\s+{re.escape(orig_top)}\b", clean)
    if not head:
        return {}
    i = head.end()
    n = len(clean)
    # Skip whitespace.
    while i < n and clean[i].isspace():
        i += 1
    # Skip optional parameter block `#( ... )` (one level of nesting).
    if i < n and clean[i] == "#":
        i += 1
        while i < n and clean[i].isspace():
            i += 1
        if i < n and clean[i] == "(":
            depth = 1
            i += 1
            while i < n and depth > 0:
                if clean[i] == "(":
                    depth += 1
                elif clean[i] == ")":
                    depth -= 1
                i += 1
        while i < n and clean[i].isspace():
            i += 1
    # Now expect the port-list `( ... )` — match its body.
    if i >= n or clean[i] != "(":
        return {}
    depth = 1
    i += 1
    start = i
    while i < n and depth > 0:
        if clean[i] == "(":
            depth += 1
        elif clean[i] == ")":
            depth -= 1
            if depth == 0:
                break
        i += 1
    plist = clean[start:i]

    result: dict[str, int] = {}
    # `<dir> [type-or-kind...] [packed-dim...] <name> [<int>]` —
    # `type-or-kind` is up to two whitespace-separated identifiers
    # (e.g. `logic`, `wire integer`, `ptab_dat_t`, or even `wire logic`).
    # The greedy match backtracks so the last identifier ends up bound
    # to <name> rather than to the type words.
    port_re = re.compile(
        r"\b(input|output|inout)\b"               # direction
        r"(?:\s+[A-Za-z_]\w*){0,2}"               # optional 0-2 type/kind words
        r"(?:\s*\[[^\]]+\])*"                     # optional packed dims
        r"\s+([A-Za-z_]\w*)"                      # port name
        r"\s*\[\s*(\d+)\s*(?:-\s*1\s*:\s*0)?\s*\]"  # unpacked [N] or [N-1:0]
    )
    for d, name, count in port_re.findall(plist):
        # Filter out keywords accidentally captured as a port name.
        if name in ("input", "output", "inout", "wire", "reg",
                    "logic", "bit", "var"):
            continue
        result[name] = int(count)
    return result


def synth_to_netlist(yosys: Path, uhdm_plugin: Path,
                     uhdm: Path, out_v: Path) -> str:
    """Synth the UHDM, write the renamed netlist, and return the
    *original* top module name (whatever Yosys auto-top selected)."""
    # `$check` cells (concurrent / immediate assertions) and `$print`
    # cells ($display) have no Verilator-compatible behavioural model,
    # and they're not the subject of the equivalence check anyway.
    # Delete them before writing the netlist.
    out_top = out_v.with_name(out_v.stem + ".orig_top.txt")
    script = (
        f"read_uhdm {uhdm}\n"
        f"synth -auto-top\n"
        f"delete t:$check t:$print\n"
        f"flatten\n"
        f"opt_clean\n"
        # Capture the auto-top name *before* renaming so the wrapper
        # can instantiate the right SV module (the netlist top can
        # differ from the last-`module`-declaration in dut.sv when
        # the source has `bind`, multiple unrelated modules, etc.).
        f"tee -q -o {out_top} ls A:top\n"
        f"rename -top dut_netlist\n"
        f"write_verilog -noattr -noexpr {out_v}\n"
    )
    sh([str(yosys), "-q", "-m", str(uhdm_plugin), "-p", script])
    # Parse the `ls A:top` output.  Yosys formats it as:
    #
    #   1 modules:
    #     top
    #
    # — the module name is the first indented line after the header.
    # For parameterised modules it can be `$paramod\Foo\X=...`; strip
    # the prefix back to the original SV name.
    name = ""
    if out_top.exists():
        for line in out_top.read_text().splitlines():
            s = line.strip()
            if not s or "modules:" in s:
                continue
            if s.startswith("$paramod"):
                # `$paramod\Foo\X=...` — pull the bit between the first
                # two backslashes (the original module name).
                parts = s.split("\\")
                if len(parts) >= 2:
                    name = parts[1]
                else:
                    name = s
            else:
                # Strip leading backslash if Yosys printed an escaped id.
                name = s[1:] if s.startswith("\\") else s
            break
    return name


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
                       out_dir: Path,
                       unpacked: dict[str, int] | None = None) -> None:
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
    # For unpacked-array ports, build a per-element unpacked-array wire
    # inside the wrapper and `assign` slices of the flat input into it.
    # We avoid the `'{...}` assignment-pattern form in the port
    # connection because Verilator drops the live-update of those args
    # in some configurations.  Yosys flattens element 0 to the LSBs of
    # the synthesized port (verified via `connect \iP[0] \iP[13:0]` in
    # the IL), so the assigns mirror that ordering.
    intermediates: list[str] = []
    def conn(n: str, w: int) -> str:
        if unpacked and n in unpacked:
            count = unpacked[n]
            if count > 0 and w % count == 0:
                ew = w // count
                intermediates.append(
                    f"  logic [{ew-1}:0] {n}_arr [{count}];")
                for i in range(count):
                    intermediates.append(
                        f"  assign {n}_arr[{i}] = {n}[{(i+1)*ew-1}:{i*ew}];")
                return f"    .{n}({n}_arr)"
        return f"    .{n}({n})"
    inst_conn = [conn(n, w) for (n, w, _d) in ports]
    wrapper_lines = [
        "// Auto-generated: wraps the original SV top as `dut_rtl`.",
        f"module dut_rtl (\n" + ",\n".join(port_decl) + "\n);",
        *intermediates,
        f"  {orig_top} u_orig (",
        ",\n".join(inst_conn),
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
        # Mask the stimulus to each port's declared width.  Verilator
        # stores small ports in IData / VlWide but does NOT auto-truncate
        # writes from the C++ side, so an unmasked `(uint32_t)rand()` can
        # produce out-of-range values that diverge between RTL and netlist
        # (e.g. `arr[sel]` indexes out of bounds in C++ while the synth'd
        # mux chain handles all 32 bits — observed on
        # typedef_unpacked_input).
        for n, w in inputs:
            if w < 64:
                mask = f"((1ULL << {w}) - 1)" if w > 1 else "1ULL"
                if w <= 32:
                    cpp.append(f"        tb.{n} = (uint32_t)(((uint64_t)rand()) & {mask});")
                else:
                    cpp.append(f"        tb.{n} = (((uint64_t)rand() << 32) | (uint32_t)rand()) & {mask};")
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
        # `--timing` lets Verilator parse SVA constructs (`##N`, `|=>`,
        # `until`, ...) and event controls that are otherwise rejected
        # with NEEDTIMINGOPT.  Required for the SV-side simulation of
        # assertion-heavy DUTs; harmless for purely structural ones.
        "--timing",
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

    print("▶ Generating synthesized netlist from UHDM")
    yosys_top = synth_to_netlist(paths["yosys"], paths["uhdm_plugin"],
                                 uhdm, work / "dut_netlist.v")
    # Prefer the auto-top name Yosys actually selected; fall back to the
    # last-`module`-declaration heuristic when capture failed.
    orig_top = yosys_top or find_top_module(dut)
    print(f"▶ original SV top: {orig_top}")

    print("▶ Extracting clocks/resets/ports")
    extract_ports(paths["yosys"], paths["cr_plugin"],
                  paths["simcells"], work / "dut_netlist.v",
                  work / "ports.txt")
    ports, clocks, resets = parse_ports(work / "ports.txt")
    print(f"  ports={len(ports)} clocks={clocks} resets={list(resets)}")

    unpacked = detect_unpacked_array_ports(dut, orig_top)
    if unpacked:
        print(f"  unpacked-array ports: {unpacked}")
    print("▶ Emitting wrapper + testbench")
    emit_wrapper_and_tb(dut, orig_top, ports, clocks, resets, work,
                        unpacked=unpacked)

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
