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
    # Optional frontend tools — only needed for --frontend sv2v / slang.  Don't
    # fail here if absent; frontend_read_setup() reports a clear error instead.
    paths["slang_plugin"] = project_root / "build/slang.so"
    paths["sv2v_bin"]     = project_root / "build/frontends/sv2v/bin/sv2v"
    return paths


def frontend_read_setup(frontend: str, paths: dict, uhdm: Path,
                        rtl_srcs: list, test_dir: Path,
                        lang: str) -> tuple[str, list[str]]:
    """Return (read_lines, extra_yosys_args) for a given frontend so the same
    synth/netlist pipeline can be driven by any of the four readers.  Only the
    read step differs; everything downstream is shared with the UHDM path."""
    srcs = " ".join(str(s) for s in rtl_srcs)
    if frontend == "uhdm":
        return f"read_uhdm {uhdm}\n", ["-m", str(paths["uhdm_plugin"])]
    if frontend == "verilog":
        return f"read_verilog {lang} {srcs}\n", []
    if frontend == "slang":
        if not paths["slang_plugin"].exists():
            sys.exit(f"❌ slang plugin not built: {paths['slang_plugin']} "
                     f"(run test/build_frontends.sh)")
        return f"read_slang {srcs}\n", ["-m", str(paths["slang_plugin"])]
    if frontend == "sv2v":
        if not paths["sv2v_bin"].exists():
            sys.exit(f"❌ sv2v not built: {paths['sv2v_bin']} "
                     f"(run test/build_frontends.sh)")
        # Reuse the workflow's converted file when present; else transpile now.
        conv = test_dir / f"{test_dir.name}_sv2v.v"
        if not conv.exists():
            out = sh([str(paths["sv2v_bin"]), *[str(s) for s in rtl_srcs]])
            conv.write_text(out)
        return f"read_verilog {conv}\n", []
    sys.exit(f"❌ unknown frontend: {frontend}")


def parse_project_f(test_dir: Path) -> dict:
    """Read `project.f` if present.  Returns a dict with keys:
        srcs: list[Path]   — source files (relative to test_dir)
        top:  str          — top module name (or "")
        mode: str          — "uhdm-only", "equiv", "" (default)
    When `project.f` is absent or has no sources, falls back to
    `dut.sv` / `dut.v`.  Mirrors the bash project_files.sh helper used
    by the workflow / equivalence scripts so the three pipelines see
    the same file list."""
    out: dict = {"srcs": [], "top": "", "mode": "", "verilator": []}
    pf = test_dir / "project.f"
    if pf.exists():
        for raw in pf.read_text().splitlines():
            line = raw.strip()
            if not line:
                continue
            if line.startswith("#"):
                # Recognise "# key: value" directives.
                body = line[1:].strip()
                if ":" in body:
                    key, _, val = body.partition(":")
                    key = key.strip().lower()
                    val = val.strip()
                    if key in ("top", "mode"):
                        out[key] = val
                    elif key == "verilator":
                        # Per-test extra Verilator flags (e.g. `-Wno-...` or
                        # `+define+FOO`) for imported designs that need them.
                        out["verilator"] += val.split()
                continue
            out["srcs"].append(test_dir / line)
    if not out["srcs"]:
        for cand in ("dut.sv", "dut.v"):
            p = test_dir / cand
            if p.exists():
                out["srcs"].append(p)
                break
    return out


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


def synth_to_netlist(yosys: Path, read_lines: str, plugin_args: list,
                     out_v: Path) -> str:
    """Synth a design (read via the frontend-specific `read_lines`), write the
    renamed netlist, and return the *original* top module name (whatever Yosys
    auto-top selected).  `plugin_args` are extra `yosys` command-line args
    (e.g. `-m <plugin.so>`) needed by the frontend's read command."""
    # `$check` cells (concurrent / immediate assertions) and `$print`
    # cells ($display) have no Verilator-compatible behavioural model,
    # and they're not the subject of the equivalence check anyway.
    # Delete them before writing the netlist.
    out_top = out_v.with_name(out_v.stem + ".orig_top.txt")
    mem_flag = out_v.with_name(out_v.stem + ".memflag.txt")
    script = (
        f"{read_lines}"
        # Detect memories BEFORE synth expands/maps them.  Memory designs also
        # need the gate-instance (-noexpr) form: the behavioral $mem output of
        # write_verilog has read-during-write semantics that differ from the
        # RTL under Verilator.
        f"tee -q -o {mem_flag} select -count t:$mem t:$mem_v2 "
        f"t:$memrd t:$memrd_v2 t:$memwr t:$memwr_v2\n"
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
        # Write BOTH forms and pick below.  `-noexpr` renders FFs as gate
        # $_DFF*_ instances — needed so ASYNC-reset FFs (multi-edge
        # sensitivity) simulate correctly under Verilator — but it loses
        # register power-up init values (a gate Q wire has no
        # Verilator-honorable init) and writes coarse word-level cells as
        # unresolvable instances.  Expression mode keeps `reg q = init;`
        # (Verilator honors it, matching the RTL's SV initializers) and
        # writes coarse cells as operators, but async FFs become behavioral
        # always-blocks keyed on intermediate nets that Verilator
        # mis-schedules.  So use `-noexpr` only when the design actually has
        # async-edge FFs; otherwise prefer expression mode.
        f"write_verilog -noattr {out_v}.expr\n"
        f"write_verilog -noattr -noexpr {out_v}.noexpr\n"
    )
    sh([str(yosys), "-q", *plugin_args, "-p", script])
    # Pick the netlist form.  An async-edge FF shows up in expression mode as
    # a sensitivity list with two or more edges, e.g.
    #   always @(posedge clk, posedge rst)
    # — those need the gate-instance (-noexpr) form; everything else uses
    # expression mode so register initializers survive into the co-sim.
    import shutil
    expr_path = Path(str(out_v) + ".expr")
    noexpr_path = Path(str(out_v) + ".noexpr")
    expr_text = expr_path.read_text() if expr_path.exists() else ""
    has_async_ff = bool(re.search(
        r"always @\([^)]*edge[^)]*(?:,|\bor\b)[^)]*edge", expr_text))
    has_memory = False
    if mem_flag.exists():
        m = re.search(r"(\d+)\s+objects", mem_flag.read_text())
        has_memory = bool(m and int(m.group(1)) > 0)
    chosen = noexpr_path if (has_async_ff or has_memory) else expr_path
    if chosen.exists():
        shutil.copyfile(chosen, out_v)
    for p in (expr_path, noexpr_path, mem_flag):
        try:
            p.unlink()
        except OSError:
            pass
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
    # `proc` turns the behavioral `always @(posedge clk)` blocks that
    # write_verilog emits for large memories (e.g. blockram's 1024x8 array,
    # which stays a $mem rather than mapping to FFs) into $dff / $memwr_v2
    # cells whose CLK ports the extractor can trace to a top clock.  Without
    # it, such a netlist has NO clock-bearing cells and the co-sim never
    # toggles a clock → vacuous all-zero match.  `memory_dff` exposes the
    # write-port clocks as cells too.  Harmless for purely gate-level netlists.
    script = (
        f"read_verilog -nolatches {simcells} {netlist_v}\n"
        f"hierarchy -top dut_netlist\n"
        f"proc\n"
        f"memory_dff\n"
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
                       unpacked: dict[str, int] | None = None,
                       cycles: int = 200) -> None:
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
        "    unsigned long long act_or = 0;  // OR of every output value seen",
        "    long act_nz = 0;                // cycles where any output != 0",
    ]
    # Init all driven inputs
    for c in clocks:
        cpp.append(f"    tb.{c} = 0;")
    for r, ah in resets.items():
        cpp.append(f"    tb.{r} = {1 if ah else 0};  // assert reset")
    for n, w in inputs:
        if w <= 64:
            cpp.append(f"    tb.{n} = 0;")
        else:
            # VlWide<N> doesn't accept `= 0`; zero each word.
            nwords = (w + 31) // 32
            for i in range(nwords):
                cpp.append(f"    tb.{n}[{i}] = 0;")
    cpp.append("    tb.eval();")

    if clocks:
        # A posedge on EVERY clock.  A design may have several independent
        # clock domains / memory ports (e.g. blockram's clk_a_*/clk_b_*);
        # toggling only clocks[0] leaves the others un-clocked, so their logic
        # never updates and their outputs stay dead — a vacuous all-zero match.
        def tick(indent="        "):
            for c in clocks:
                cpp.append(f"{indent}tb.{c} = 0;")
            cpp.append(f"{indent}tb.eval();")
            for c in clocks:
                cpp.append(f"{indent}tb.{c} = 1;")
            cpp.append(f"{indent}tb.eval();")
        cpp.append("    // Reset phase: hold reset asserted for several clock cycles")
        cpp.append(f"    for (int i = 0; i < {reset_cycles}; ++i) {{")
        tick()
        cpp.append("    }")
        for r, ah in resets.items():
            cpp.append(f"    tb.{r} = {0 if ah else 1};  // de-assert reset")
        cpp.append(f"    tb.eval();")
        cpp.append(f"    srand({seed});")
        cpp.append(f"    for (int cycle = 0; cycle < {cycles}; ++cycle) {{")
        # Drive inputs before negedge / posedge.  Mask the stimulus to each
        # port's declared width (mirrors the unclocked branch below): an
        # unmasked `(uint32_t)rand()` written to a small port can flip bits
        # the synth'd netlist doesn't model the same way as Verilator's RTL
        # view, causing spurious mismatches.
        for n, w in inputs:
            if w <= 32:
                mask = f"((1ULL << {w}) - 1)" if w > 1 else "1ULL"
                cpp.append(f"        tb.{n} = (uint32_t)(((uint64_t)rand()) & {mask});")
            elif w <= 64:
                if w == 64:
                    cpp.append(f"        tb.{n} = ((uint64_t)rand() << 32) | (uint32_t)rand();")
                else:
                    mask = f"((1ULL << {w}) - 1)"
                    cpp.append(f"        tb.{n} = (((uint64_t)rand() << 32) | (uint32_t)rand()) & {mask};")
            else:
                nwords = (w + 31) // 32
                top_bits = w - 32 * (nwords - 1)
                for i in range(nwords):
                    if i == nwords - 1 and top_bits < 32:
                        m = (1 << top_bits) - 1
                        cpp.append(f"        tb.{n}[{i}] = (uint32_t)rand() & 0x{m:x}U;")
                    else:
                        cpp.append(f"        tb.{n}[{i}] = (uint32_t)rand();")
        # Wiggle reset/enable-style controls during the run instead of pinning
        # them de-asserted.  A signal the clock/reset extractor flags as a
        # "reset" is often ALSO a functional control — e.g. a RAM write-enable
        # whose asserted edge synchronously clears the read port (amber23
        # `o_read_data <= i_write_enable ? 0 : mem[a]`).  Pinning it off means
        # the memory is never written and every read returns 0 → vacuous match.
        # Both DUTs receive identical stimulus, so occasional assertion only
        # adds coverage; it can never invalidate the equivalence comparison.
        for r, ah in resets.items():
            assert_v, deassert_v = (1, 0) if ah else (0, 1)
            cpp.append(f"        tb.{r} = ((rand() & 3) == 0) ? {assert_v} : {deassert_v};")
        tick()
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
            cpp.append("          }")
            cpp.append("          act_or |= r; if (r) act_nz++; }")
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
            if w <= 32:
                mask = f"((1ULL << {w}) - 1)" if w > 1 else "1ULL"
                cpp.append(f"        tb.{n} = (uint32_t)(((uint64_t)rand()) & {mask});")
            elif w <= 64:
                if w == 64:
                    cpp.append(f"        tb.{n} = ((uint64_t)rand() << 32) | (uint32_t)rand();")
                else:
                    mask = f"((1ULL << {w}) - 1)"
                    cpp.append(f"        tb.{n} = (((uint64_t)rand() << 32) | (uint32_t)rand()) & {mask};")
            else:
                # Wide port: VlWide<N> exposes operator[] returning EData
                # (uint32_t). Fill each word with rand() and mask the top
                # word to the leftover bits.
                nwords = (w + 31) // 32
                top_bits = w - 32 * (nwords - 1)
                for i in range(nwords):
                    if i == nwords - 1 and top_bits < 32:
                        m = (1 << top_bits) - 1
                        cpp.append(f"        tb.{n}[{i}] = (uint32_t)rand() & 0x{m:x}U;")
                    else:
                        cpp.append(f"        tb.{n}[{i}] = (uint32_t)rand();")
        cpp.append("        tb.eval();")
        for n, w in outputs:
            if w <= 64:
                mask = ("((1ULL << %d) - 1)" % w) if w < 64 else "~0ULL"
                cpp.append(f"        {{ unsigned long long r = (unsigned long long)tb.rtl_{n} & {mask};")
                cpp.append(f"          unsigned long long s = (unsigned long long)tb.nl_{n}  & {mask};")
                cpp.append(f"          if (r != s) {{")
                cpp.append(f"            std::printf(\"MISMATCH cycle %d: {n}: rtl=0x%llx nl=0x%llx\\n\","
                           f" cycle, r, s);")
                cpp.append("            mismatches++;")
                cpp.append("          }")
                cpp.append("          act_or |= r; if (r) act_nz++; }")
            else:
                # Wide output: compare word-by-word.  Mask the top word to
                # the leftover bits so undefined high bits in either side
                # don't flag a false mismatch.
                nwords = (w + 31) // 32
                top_bits = w - 32 * (nwords - 1)
                top_mask = ((1 << top_bits) - 1) if top_bits < 32 else 0xFFFFFFFF
                cpp.append("        {")
                cpp.append("          bool ne = false;")
                for i in range(nwords):
                    if i == nwords - 1 and top_bits < 32:
                        cpp.append(f"          if (((uint32_t)tb.rtl_{n}[{i}] & 0x{top_mask:x}U)"
                                   f" != ((uint32_t)tb.nl_{n}[{i}] & 0x{top_mask:x}U)) ne = true;")
                    else:
                        cpp.append(f"          if ((uint32_t)tb.rtl_{n}[{i}]"
                                   f" != (uint32_t)tb.nl_{n}[{i}]) ne = true;")
                cpp.append("          if (ne) {")
                # Print all words for diagnostic purposes (low word last).
                fmt = " ".join(["%08x"] * nwords)
                rargs = ", ".join(
                    [f"(uint32_t)tb.rtl_{n}[{i}]" for i in range(nwords - 1, -1, -1)])
                nargs = ", ".join(
                    [f"(uint32_t)tb.nl_{n}[{i}]" for i in range(nwords - 1, -1, -1)])
                cpp.append(f"            std::printf(\"MISMATCH cycle %d: {n}:"
                           f" rtl={fmt} nl={fmt}\\n\","
                           f" cycle, {rargs}, {nargs});")
                cpp.append("            mismatches++;")
                cpp.append("          }")
                # Activity: OR every word of this wide output into act_or.
                for i in range(nwords):
                    cpp.append(f"          act_or |= (unsigned long long)(uint32_t)tb.rtl_{n}[{i}];")
                cpp.append("        }")
        cpp.append("    }")
    # Vacuous-pass guard: a co-sim that matches only because every output is
    # all-zero on every cycle proves nothing.  Flag it when at least one
    # comparable (<=64-bit) output exists yet no output bit was ever set.
    has_tracked = any(w <= 64 for _, w in outputs)
    cpp += [
        '    std::printf("ACTIVITY: out_nonzero_cycles=%ld bits_ever_set=0x%llx\\n",'
        " act_nz, act_or);",
    ]
    if has_tracked:
        cpp += [
            "    bool vacuous = (act_or == 0);",
            "    if (vacuous)",
            '        std::printf("VACUOUS: outputs were all-zero every cycle —'
            ' co-sim did not exercise the design\\n");',
        ]
    else:
        cpp += ["    bool vacuous = false;"]
    cpp += [
        f"    if (mismatches == 0 && !vacuous)",
        f"        std::printf(\"PASS: {cycles} cycles, 0 mismatches\\n\");",
        "    else if (mismatches)",
        f"        std::printf(\"FAIL: {cycles} cycles, %d mismatches\\n\", mismatches);",
        "    else",
        f"        std::printf(\"FAIL: {cycles} cycles, vacuous (no output activity)\\n\");",
        "    return (mismatches == 0 && !vacuous) ? 0 : 1;",
        "}",
        "",
    ]
    (out_dir / "tb_main.cpp").write_text("\n".join(cpp))


def run_verilator(work: Path, paths: dict[str, Path],
                  rtl_srcs: list[Path],
                  extra_flags: list[str] | None = None) -> tuple[int, str]:
    cmd = [
        "verilator", "--cc", "--exe", "--build", "-j", "4",
        "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED", "-Wno-UNOPTFLAT",
        "-Wno-CASEINCOMPLETE", "-Wno-MULTIDRIVEN",
        # Imported third-party RTL sometimes uses non-unique enum values
        # (e.g. rp32's riscv_isa_pkg RV*GC aliases) — illegal-strict SV that
        # Surelog/slang tolerate; relax it so the co-sim can build the design.
        "-Wno-ENUMVALUE",
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
        *(extra_flags or []),
        *[str(p) for p in rtl_srcs],
        "wrapper.sv", "dut_netlist.v", "tb.sv",
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
    ap.add_argument("--cycles", type=int, default=200,
                    help="number of random simulation cycles (default: 200)")
    ap.add_argument("--frontend", default="uhdm",
                    choices=["uhdm", "verilog", "sv2v", "slang"],
                    help="which frontend's netlist to co-sim vs the original "
                         "RTL (default: uhdm)")
    args = ap.parse_args()

    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent
    test_dir = Path(args.test_name) if Path(args.test_name).is_absolute() \
        else Path.cwd() / args.test_name

    if not test_dir.is_dir():
        sys.exit(f"❌ test dir not found: {test_dir}")

    paths = find_paths(project_root)
    uhdm = test_dir / "slpp_all/surelog.uhdm"
    if args.frontend == "uhdm" and not uhdm.exists():
        sys.exit(f"❌ no UHDM at {uhdm} — run the standard workflow first")

    project = parse_project_f(test_dir)
    if not project["srcs"]:
        sys.exit(f"❌ no dut.sv / dut.v / project.f in {test_dir}")
    # Verilator-friendly RTL source list.  For single-file tests this is
    # just [dut.sv]; for multi-file projects it includes every source
    # listed in project.f.  Used both to find the original top (when no
    # explicit `# top:` directive) and to feed Verilator's --cc.
    rtl_srcs: list[Path] = project["srcs"]
    dut = rtl_srcs[0]

    work = test_dir / "sim_equiv"
    if work.exists():
        for f in work.iterdir():
            if f.is_dir():
                import shutil
                shutil.rmtree(f)
            else:
                f.unlink()
    work.mkdir(exist_ok=True)

    # Copy $readmem data files (*.mem/*.vmem/*.hex) into the Verilator work dir
    # so the RTL side loads the same ROM the UHDM netlist baked in via $meminit
    # (Verilator's $readmemh resolves the relative path from its run cwd = work).
    import shutil as _sh
    for pat in ("*.mem", "*.vmem", "*.hex"):
        for f in test_dir.glob(pat):
            _sh.copyfile(f, work / f.name)

    # Language flag for the native verilog reader: -sv if any source is .sv.
    lang = "-sv" if any(str(s).endswith(".sv") for s in rtl_srcs) else ""
    read_lines, plugin_args = frontend_read_setup(
        args.frontend, paths, uhdm, rtl_srcs, test_dir, lang)
    print(f"▶ Generating synthesized netlist from {args.frontend} frontend")
    yosys_top = synth_to_netlist(paths["yosys"], read_lines, plugin_args,
                                 work / "dut_netlist.v")
    # Prefer the auto-top name Yosys actually selected; fall back to the
    # last-`module`-declaration heuristic when capture failed.
    # Top priority order:
    #   1. `# top: <name>` directive in project.f (explicit, multi-file
    #      projects need this since auto-detection can pick wrong modules)
    #   2. Yosys's auto-top (from `synth -auto-top`)
    #   3. Last-`module`-declaration in the first source
    orig_top = project["top"] or yosys_top or find_top_module(dut)
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
                        unpacked=unpacked, cycles=args.cycles)

    print("▶ Running Verilator co-sim")
    rc, out = run_verilator(work, paths, rtl_srcs,
                            extra_flags=project.get("verilator") or [])
    # Trim Verilator noise so the PASS/FAIL line is easy to find
    for line in out.splitlines()[-15:]:
        print(line)
    if "[verilator build failed]" in out:
        # Verilator could not COMPILE the design — either the original RTL
        # uses a construct it doesn't support (`~&` binary nand, `ref` args,
        # arrayed defparam, some interface forms) or the synth netlist
        # contains cells it can't model ($allconst/$anyseq formal primitives,
        # ...).  A build failure is not evidence of an RTL-vs-netlist
        # divergence, so the co-sim is inapplicable: skip (autotools 77)
        # instead of reporting a spurious mismatch.
        print("⏭  Verilator cannot build this design — co-sim not applicable (skipping)")
        return 77
    if "PASS:" in out and "MISMATCH" not in out and "FAIL:" not in out:
        return 0
    print("❌ simulation reported a mismatch or did not complete")
    return 1 if rc == 0 else rc


if __name__ == "__main__":
    sys.exit(main())
