#!/usr/bin/env python3
"""Verilator co-sim of a read_uhdm netlist (and, when given, the read_slang
netlist of the same module) against the behavioural RTL, under identical
pseudo-random stimulus.  One script for every sweep row: a full chip top
(Caliptra's flat wrapper) and every DIRECT instance of a chip (Pavona egret /
dragonfly, Caliptra), where the instance module is a paramod whose integer
parameters are passed to Verilator with -G.

  netlist_cosim.py --work DIR --uhdm-il FILE --top MOD [--slang-il FILE]
                   --rtl-top MOD [--param NAME=INT ...]
                   --srcs FILE --incs FILE [--var NAME=PATH ...]
                   [--extra-src FILE ...] [--cycles N] [--seed S]
                   [--ties FILE.json]

`--top` is the module name inside the IL (chip_flow's split() renames each
instance module to `<inst>_uhdm` / `<inst>_slang`); both netlists are renamed
to `--rtl-top` so the one generated testbench drives all three builds.

Every top-level clock is driven by the testbench clock, resets (active-low by
name: *_n, *_ni, *_b, *_l, por_n*, and power-good pins) are held asserted for
the first 20 cycles, ties (JSON name -> literal) are constant, and every other
input takes a new 64-bit xorshift value each cycle.  Each simulation prints all
outputs every cycle; the traces are compared line by line.

Prints (parsed by core_sweep.py):
  ACTIVITY <n> cycles with an output change
  ADJUDICATION <cycles> cycles: uhdm_vs_rtl=<n> slang_vs_rtl=<n|-1>
  FIRST-<TAG> cycle <c> <port> rtl=.. <tag>=..
  VERDICT NO_DIVERGENCE | SHARED_DIVERGENCE | UHDM_DIVERGENCE
and on a failure to run: NO_RUN (<why>) / <tag> Verilator build FAILED: ...
Exit 2 = NO_RUN (nothing to compare), 1 = build/sim failure, 0 = compared.
"""
import argparse, json, os, re, subprocess, sys
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--work", required=True)
ap.add_argument("--uhdm-il", required=True)
ap.add_argument("--slang-il")
ap.add_argument("--top", required=True, help="module name inside the IL files")
ap.add_argument("--rtl-top", required=True, help="RTL module name (Verilator --top-module)")
ap.add_argument("--param", action="append", default=[], help="NAME=INT for the RTL build")
ap.add_argument("--srcs", required=True)
ap.add_argument("--incs", required=True)
ap.add_argument("--var", action="append", default=[], help="NAME=PATH substituted for ${NAME}")
ap.add_argument("--iface-flat", action="store_true",
                help="rename the netlists' escaped interface-member ports (`\\bus.sig `) to "
                     "`bus_sig`, matching a flat-port RTL wrapper (gen_inst_wrapper.py)")
ap.add_argument("--extra-src", action="append", default=[])
ap.add_argument("--cycles", type=int, default=300)
ap.add_argument("--seed", type=int, default=1)
ap.add_argument("--ties")
ap.add_argument("--timeout", type=int, default=3600)
args = ap.parse_args()
args.extra_src = [str(Path(e).resolve()) for e in args.extra_src]
args.srcs, args.incs = str(Path(args.srcs).resolve()), str(Path(args.incs).resolve())

ROOT = Path(__file__).resolve().parent.parent
YOSYS = os.environ.get("YOSYS", str(ROOT / "out/current/bin/yosys"))
VERILATOR = os.environ.get("VERILATOR", "verilator")
WORK = Path(args.work).resolve()
WORK.mkdir(parents=True, exist_ok=True)
TOP = args.rtl_top
tag_name = Path(args.work).name


def sh(cmd, log=None, cwd=WORK, timeout=None):
    r = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, timeout=timeout,
                       errors="replace")
    if log:
        (WORK / log).write_text(r.stdout + r.stderr)
    return r


def paths(fname):
    out = []
    for l in Path(fname).read_text().splitlines():
        l = l.strip()
        if not l:
            continue
        for kv in args.var:
            k, v = kv.split("=", 1)
            l = l.replace("${%s}" % k, v)
        out.append(l)
    return out


# ---------------------------------------------------------------- netlist
def netlist(tag, il, nl):
    il = Path(il).resolve()          # yosys runs in WORK; the IL path may be relative
    if not il.exists():
        return False
    if nl.exists() and nl.stat().st_mtime >= il.stat().st_mtime:
        # Reuse only a COMPLETE netlist (a full disk once left a truncated
        # one behind, and every later run failed on its last line).
        with open(nl, "rb") as fh:
            fh.seek(max(0, nl.stat().st_size - 4096))
            if b"endmodule" in fh.read():
                return True
    mod = args.top if tag == 'uhdm' else args.top.replace('_uhdm', '_slang')
    # The netlist module takes the RTL name in the written Verilog (below):
    # yosys's `rename` asserts on these instance ILs.
    ys = f"""read_rtlil {il}
hierarchy -top {mod}
proc
# opt_clean BEFORE flatten: the proc'd hierarchy carries every module's dead
# wires, which flatten replicates per instance -- caliptra_top peaked at 20 GB
# (killed the 16 GB CI runner); cleaning first peaks at 8.5 GB.
opt_clean
flatten
opt_clean
hierarchy -top {mod}
memory -nomap
opt_clean
delete t:$check t:$assert t:$assume t:$print t:$scopeinfo
bwmuxmap
bmuxmap
demuxmap
write_verilog -noattr -norename {nl}
"""
    (WORK / f"netlist_{tag}.ys").write_text(ys)
    r = sh([YOSYS, "-q", f"netlist_{tag}.ys"], log=f"netlist_{tag}.log")
    if r.returncode or not nl.exists():
        return False
    # Verilator refuses a line with more than 40000 tokens and caps a literal
    # at 65536 bits: break long lines after commas and rewrite wide constants.
    LIM = 65536

    def shrink(m):
        w, base, digits = int(m.group(1)), m.group(2), m.group(3).replace("_", "")
        if w <= LIM:
            return m.group(0)
        bits = {"h": 4, "b": 1, "o": 3}.get(base.lower())
        if bits is None:
            return m.group(0)
        if set(digits) == {"0"}:
            return "{%d{1'b0}}" % w
        if base.lower() == "h" and set(digits.lower()) == {"f"}:
            return "{%d{1'b1}}" % w
        b = "".join(bin(int(d, 16 if bits == 4 else 8 if bits == 3 else 2))[2:].zfill(bits)
                    for d in digits).zfill(w)[-w:]
        parts = [b[i:i + LIM] for i in range(0, len(b), LIM)]
        return "{" + ", ".join(f"{len(p)}'b{p}" for p in parts) + "}"

    wide = re.compile(r"\b(\d{5,})'([hbo])([0-9a-fA-F_]+)")
    # --iface-flat: an interface-typed port of the RTL module reaches the
    # netlist as one escaped identifier per member (`\s_axi_w_if.awvalid `);
    # the flat-port wrapper the RTL side is driven through names the same
    # member `s_axi_w_if_awvalid`.  Rewrite every escaped dotted identifier
    # (they only ever come from interface / struct flattening) so the two
    # sides share a port list.
    dotted = re.compile(r"\\([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+(?:\[\d+\])?) ")

    def flat_id(m):
        return m.group(1).replace(".", "_").replace("[", "_").replace("]", "")
    tmp = nl.with_suffix(".split.v")
    with open(nl, errors="replace") as fi, open(tmp, "w") as fo:
        for line in fi:
            if line.startswith(f"module {mod}(") or line.startswith(f"module \\{mod} ("):
                line = f"module {TOP}(" + line.split("(", 1)[1]
            if args.iface_flat and "\\" in line:
                line = dotted.sub(flat_id, line)
            if "'" in line:
                line = wide.sub(shrink, line)
            if len(line) > 8000:
                line = line.replace(", ", ",\n")
            fo.write(line)
    tmp.replace(nl)
    return True


nl = WORK / f"uhdm_{TOP}.v"
if not netlist("uhdm", args.uhdm_il, nl):
    print(f"{tag_name}: NO_RUN (uhdm netlist generation failed)")
    sys.exit(2)
slang_nl = WORK / f"slang_{TOP}.v"
have_slang = bool(args.slang_il) and netlist("slang", args.slang_il, slang_nl)

# ---------------------------------------------------------------- ports
ports = []   # (dir, width, name)
with open(nl, errors="replace") as fh:
    inmod = False
    for line in fh:
        if not inmod:
            inmod = line.startswith(f"module {TOP}(")
            continue
        m = re.match(r"\s*(input|output|inout)\s+(?:\[(\d+):(\d+)\]\s+)?(\S+)\s*;", line)
        if m:
            w = abs(int(m.group(2)) - int(m.group(3))) + 1 if m.group(2) else 1
            ports.append((m.group(1), w, m.group(4)))
            continue
        if re.match(r"\s*(function|always|assign|endmodule)\b", line):
            break
if not ports:
    print(f"{tag_name}: NO_RUN (no ports parsed from {nl.name})")
    sys.exit(2)
if any(n.startswith("\\") for _, _, n in ports):
    # Escaped port names (flattened interface/struct members with dots) are
    # not what the RTL module declares — no port-by-port testbench possible.
    print(f"{tag_name}: NO_RUN (escaped port names: "
          f"{[n for _, _, n in ports if n.startswith(chr(92))][:3]})")
    sys.exit(2)

TIES = json.loads(Path(args.ties).read_text()) if args.ties else {}
# A clock is `clk`/`clock`, `*_clk`, `*clk_i`, pavona's `clk_<dom>_i`, JTAG tck,
# or VeeR's gated names — NOT every name containing "clk" (`clk_gate_en`,
# `rdc_clk_dis` are ordinary controls; driving them from the clock froze cg).
CLK_RE = re.compile(r"^(clk|clock|tb_clk|rawclk|gw_clk|l1clk|clk_cg)$|(^|_)(clk|clock)_i$"
                    r"|_(clk|clock)$|^clk_[a-z0-9]+_i$|(^|_)tck$")
RST_RE = re.compile(r"(^|_)(rst|reset|por|pwrgood|trst)(_|$)|_rst\w*$")
LOW_RE = re.compile(r"(_n|_ni|_b|_l|_n_i|_b_i)$|(^|_)por_n|pwrgood|_l_i$")
clocks = [n for d, w, n in ports if d == "input" and w == 1 and CLK_RE.search(n)]
resets = {n: (not LOW_RE.search(n)) for d, w, n in ports
          if d == "input" and w == 1 and n not in clocks and RST_RE.search(n)}
# resets[name] = True when the reset is ACTIVE-HIGH.

tb = ["`timescale 1ns/1ps", "module tb;", "  logic tb_clk = 1'b0;",
      f"  localparam int CYCLES = {args.cycles};", "  int cyc = 0;",
      "  logic [4095:0] wide = '0;",
      f"  logic [63:0] rng = 64'h{(args.seed * 0x9E3779B97F4A7C15) & (2**64 - 1) or 1:016x};"]
for d, w, n in ports:
    tb.append(f"  {'wire' if d == 'inout' else 'logic'} [{w-1}:0] {n};")
conns = ",\n    ".join(f".{n}({n})" for _, _, n in ports)
# The RTL build gets the instance's parameters on the instantiation (Verilator
# -G only reaches the top, which is the testbench); the netlists have them
# baked in and take the plain instantiation.
DUT_MARK = "  @@DUT@@"
tb.append(DUT_MARK)
for c in clocks:
    tb.append(f"  assign {c} = tb_clk;")
tb.append("  always #5 tb_clk = ~tb_clk;")
tb.append("  function automatic logic [63:0] step(logic [63:0] x);")
tb.append("    x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x;")
tb.append("  endfunction")
tb.append("  always @(negedge tb_clk) begin")
for d, w, n in ports:
    if d != "input" or n in clocks:
        continue
    if n in TIES:
        tb.append(f"    {n} <= {TIES[n]};")
    elif n in resets:
        asserted, released = ("'1", "'0") if resets[n] else ("'0", "'1")
        tb.append(f"    {n} <= (cyc < 20) ? {asserted} : {released};")
    else:
        chunks = (w + 63) // 64
        tb.append(f"    for (int k = 0; k < {chunks}; k++) begin rng = step(rng); "
                  f"wide = {{wide[4031:0], rng}}; end")
        ln = n.lower()
        if re.match(r"^h(sel|ready)(_i)?$", ln) and w == 1:
            # AHB: keep select/ready mostly asserted so transfers complete.
            tb.append(f"    {n} <= (wide[1:0] != 2'b00);")
        elif re.match(r"^htrans(_i)?$", ln) and w == 2:
            tb.append(f"    {n} <= {{wide[0], 1'b0}};")      # NONSEQ or IDLE
        elif re.match(r"^hsize(_i)?$", ln) and w == 3:
            tb.append(f"    {n} <= {{1'b0, 1'b1, wide[0]}};")  # word / dword
        elif "addr" in ln and w > 10:
            # A fully random address almost never lands in a register block's
            # small window (sha256_ctrl: 0 output changes in 1500 cycles);
            # keep the high bits mostly zero so bus transactions hit registers.
            tb.append(f"    {n} <= wide[{w-1}:0] & (wide[{w}] ? {w}'hff : {w}'h{(1 << w) - 1:x});")
        else:
            tb.append(f"    {n} <= wide[{w-1}:0];")
tb.append("    cyc <= cyc + 1;")
tb.append("  end")
outs = [(w, n) for d, w, n in ports if d == "output"]
if not outs:
    print(f"{tag_name}: NO_RUN (module has no outputs)")
    sys.exit(2)
fmt = " ".join(f"{n}=%h" for _, n in outs)
argl = ", ".join(n for _, n in outs)
tb.append("  always @(posedge tb_clk) begin")
tb.append(f"    #1 $display(\"C%0d {fmt}\", cyc, {argl});")
tb.append("    if (cyc >= CYCLES) $finish;")
tb.append("  end")
tb.append("endmodule")
text = "\n".join(tb) + "\n"
plain = f"  {TOP} dut (\n    {conns}\n  );"
(WORK / "tb.sv").write_text(text.replace(DUT_MARK, plain))

# ---------------------------------------------------------------- parameters
def header_params(top, files):
    """{name: decl-text} of the `parameter`s in the RTL module header of
    `top` (localparams excluded), from the first source declaring it."""
    for f in files:
        try:
            txt = Path(f).read_text(errors="replace")
        except OSError:
            continue
        m = re.search(r"^\s*module\s+" + re.escape(top) + r"\b(.*?)\)\s*;", txt, re.S | re.M)
        if not m:
            continue
        hdr = m.group(1)
        hdr = re.sub(r"//[^\n]*", "", hdr)
        hdr = re.sub(r"/\*.*?\*/", "", hdr, flags=re.S)
        out = {}
        for pm in re.finditer(r"\bparameter\b([^,;=]*?)\b(\w+)\s*(\[[^=]*?\])?\s*=", hdr):
            out[pm.group(2)] = (pm.group(1).strip(), pm.group(3))
        return out
    return None


KIND = {}   # typedef name -> enum | struct | union


def typedef_packages(files):
    """{typedef name: package} across the sources, to qualify an enum/struct
    parameter type declared in a package the module merely imports."""
    out = {}
    for f in files:
        try:
            txt = Path(f).read_text(errors="replace")
        except OSError:
            continue
        for pm in re.finditer(r"^\s*package\s+(\w+)\s*;(.*?)^\s*endpackage", txt, re.S | re.M):
            pkg, body = pm.group(1), pm.group(2)
            for tm in re.finditer(r"\btypedef\s+(enum|struct|union)\b[^{;]*\{.*?\}\s*(\w+)\s*;", body, re.S):
                out.setdefault(tm.group(2), pkg)
                KIND.setdefault(tm.group(2), tm.group(1))
            for tm in re.finditer(r"\btypedef\b(?![^;]*\{)[^;]*?\b(\w+)\s*;", body, re.S):
                out.setdefault(tm.group(1), pkg)
    return out


seen = set()
args.param = [p for p in args.param
              if not (p.split("=", 1)[0] in seen or seen.add(p.split("=", 1)[0]))]
hp = header_params(TOP, paths(args.srcs) + list(args.extra_src))
if hp is not None and args.param:
    tpk = None
    keep = []
    for p in args.param:
        k = p.split("=", 1)[0]
        if k not in hp:
            continue                     # a localparam RTLIL stamped into the name
        typ, unpacked = hp[k]
        if unpacked or re.search(r"\btype\b", typ):
            continue                     # unpacked array / type parameter: no literal fits
        # An enum/struct-typed parameter (aes_pkg::sbox_impl_e SBoxImpl) must
        # be cast: Verilator rejects an implicit bit-vector -> enum conversion.
        tw = re.sub(r"\b(unsigned|signed)\b", "", typ).split()
        tw = [t for t in tw if not t.startswith("[")]
        if tw and tw[-1] not in ("int", "integer", "logic", "bit", "reg", "wire",
                                 "longint", "shortint", "byte", "string", "real"):
            tn = tw[-1]
            if tpk is None:
                tpk = typedef_packages(paths(args.srcs) + list(args.extra_src))
            base = tn.split("::")[-1]
            if KIND.get(base) in ("struct", "union"):
                # A struct-valued parameter (VeeR's el2_param_t pt) is stamped
                # into the paramod name as a 32-bit value — not the struct —
                # so no literal we could pass reproduces the chip's value.
                # Leave the RTL default (the chip's `pt` IS the default).
                continue
            if "::" not in tn and base in tpk:
                tn = f"{tpk[base]}::{tn}"
            k2, v2 = p.split("=", 1)
            p = f"{k2}={tn}'({v2})"
        keep.append(p)
    args.param = keep

povr = ", ".join(f".{p.split('=', 1)[0]}({p.split('=', 1)[1]})" for p in args.param)
rtl_inst = (f"  {TOP} #({povr}) dut (\n    {conns}\n  );" if povr else plain)
(WORK / "tb_rtl.sv").write_text(text.replace(DUT_MARK, rtl_inst))

# ---------------------------------------------------------------- build + run
VFLAGS = ["--binary", "-j", "0", "--timing", "--no-assert", "-Wno-fatal", "-Wno-lint",
          "-Wno-style", "-Wno-ENUMVALUE", "--x-assign", "0", "--x-initial", "0", "-DSYNTHESIS",
          "--top-module", "tb", "-O1"]
incs = [f"+incdir+{d}" for d in paths(args.incs)]
srcs = paths(args.srcs) + list(args.extra_src)
builds = {
    # The RTL build elaborates only `TOP` (with the instance's parameters) but
    # parses the whole chip source list, exactly like the chip elaboration.
    "rtl": VFLAGS + ["--Mdir", "obj_rtl", "-o", "sim_rtl"] + incs + srcs + ["tb_rtl.sv"],
    "uhdm": VFLAGS + ["--Mdir", "obj_uhdm", "-o", "sim_uhdm"] + [str(nl), "tb.sv"],
}
if have_slang:
    builds["slang"] = VFLAGS + ["--Mdir", "obj_slang", "-o", "sim_slang"] + [str(slang_nl), "tb.sv"]
traces = {}
for tag, flags in builds.items():
    exe = WORK / f"obj_{tag}" / f"sim_{tag}"
    stamp = [slang_nl if tag == "slang" else nl, WORK / "tb.sv", WORK / "tb_rtl.sv"]
    if True:   # object dirs are deleted after every run, so always build
        for attempt in range(4):
            try:
                r = sh([VERILATOR] + flags, log=f"build_{tag}.log", timeout=args.timeout)
            except subprocess.TimeoutExpired:
                print(f"{tag_name}: {tag} Verilator build FAILED: timeout")
                sys.exit(1)
            # The paramod name also carries LOCALPARAMS (derived values such
            # as NumAlerts / BlockAw); Verilator refuses to override those —
            # drop them from the instantiation and rebuild.
            locals_ = set(re.findall(r"override '(\w+)'", r.stdout + r.stderr))
            if tag != "rtl" or r.returncode == 0 or not locals_:
                break
            args.param = [p for p in args.param if p.split("=", 1)[0] not in locals_]
            povr = ", ".join(f".{p.split('=', 1)[0]}({p.split('=', 1)[1]})" for p in args.param)
            rtl_inst = (f"  {TOP} #({povr}) dut (\n    {conns}\n  );" if povr else plain)
            (WORK / "tb_rtl.sv").write_text(text.replace(DUT_MARK, rtl_inst))
        if r.returncode or not exe.exists():
            errs = [l for l in (r.stdout + r.stderr).splitlines() if "%Error" in l]
            last = errs[:1] or (r.stdout + r.stderr).strip().splitlines()[-1:] or [""]
            print(f"{tag_name}: {tag} Verilator build FAILED: {last[0][:200]}")
            sys.exit(1)
    try:
        r = sh([str(exe)], log=f"run_{tag}.log", timeout=args.timeout)
    except subprocess.TimeoutExpired:
        print(f"{tag_name}: {tag} simulation FAILED: timeout")
        sys.exit(1)
    traces[tag] = [l for l in (r.stdout or "").splitlines() if l.startswith("C")]
    if not traces[tag]:
        print(f"{tag_name}: {tag} simulation produced no trace")
        sys.exit(1)

import shutil
for tag in builds:
    shutil.rmtree(WORK / f"obj_{tag}", ignore_errors=True)   # ~0.5 GB each; logs stay

rtl = traces["rtl"]
activity, prev = 0, None
for line in rtl:
    body = line.split(" ", 1)[1] if " " in line else ""
    if prev is not None and body != prev:
        activity += 1
    prev = body


def compare(tag):
    other = traces[tag]
    n = min(len(rtl), len(other))
    mism, first = 0, None
    for i in range(n):
        if rtl[i] != other[i]:
            mism += 1
            if first is None:
                a = dict(kv.split("=", 1) for kv in rtl[i].split()[1:])
                b = dict(kv.split("=", 1) for kv in other[i].split()[1:])
                port = next((k for k in a if a[k] != b.get(k)), "?")
                first = (rtl[i].split()[0][1:], port, a.get(port, ""), b.get(port, ""))
    if first:
        print(f"{tag_name} FIRST-{tag.upper()} cycle {first[0]} {first[1]} "
              f"rtl={first[2][:40]} {tag}={first[3][:40]}")
    return n, mism


print(f"{tag_name} ACTIVITY {activity} cycles with an output change")
n, mu = compare("uhdm")
ms = compare("slang")[1] if "slang" in traces else -1
print(f"{tag_name} ADJUDICATION {n} cycles: uhdm_vs_rtl={mu} slang_vs_rtl={ms}")
if mu == 0:
    verdict = "NO_DIVERGENCE"
elif ms > 0:
    verdict = "SHARED_DIVERGENCE"
else:
    verdict = "UHDM_DIVERGENCE"
print(f"{tag_name} VERDICT {verdict}")
