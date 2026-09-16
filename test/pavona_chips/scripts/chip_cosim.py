#!/usr/bin/env python3
"""Full-chip Verilator co-sim: the Pavona top (behavioural RTL) vs the read_uhdm
netlist of the same top, under identical pseudo-random pad stimulus.

  chip_cosim.py <chip> [cycles] [seed]      # chip = egret | dragonfly

Inputs:  work/<chip>/<chip>_uhdm_hier.il   (written by chip_flow.py)
         <chip>/srcs.txt, <chip>/incs.txt (Pavona source list, $PAVONA-relative)

Both simulations share one generated testbench (tb.sv): every top-level
clock is driven by one testbench clock, the power-on resets are held low for
the first cycles, test/scan controls are tied off (scanmode = MuBi4False,
AST init done / power-good asserted), and every other input takes a new
64-bit xorshift value each cycle.  Each simulation prints all top-level
outputs every cycle; the two traces are compared line by line.

Prints (parsed by core_sweep.py):
  ACTIVITY <n> cycles with an output change
  ADJUDICATION <cycles> cycles: uhdm_vs_rtl=<mismatching cycles>
  FIRST-MISMATCH <cycle> <port>
"""
import os, re, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent          # test/pavona_chips
ROOT = HERE.parent.parent
YOSYS = os.environ.get("YOSYS", str(ROOT / "out/current/bin/yosys"))
VERILATOR = os.environ.get("VERILATOR", "verilator")

chip = sys.argv[1]
CYCLES = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
SEED = int(sys.argv[3]) if len(sys.argv) > 3 else 1
TOP = f"top_{chip}"
WORK = HERE / "work" / chip / "cosim"
WORK.mkdir(parents=True, exist_ok=True)
PAVONA = os.environ.get("PAVONA", str(HERE / "pavona"))


def sh(cmd, cwd=WORK, timeout=None, log=None):
    r = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, timeout=timeout,
                       errors="replace")
    if log:
        (WORK / log).write_text(r.stdout + r.stderr)
    return r


def paths(fname):
    return [l.strip().replace("${PAVONA}", PAVONA)
            for l in (HERE / chip / fname).read_text().splitlines() if l.strip()]


# ---------------------------------------------------------------- netlist
def netlist(tag, hier, nl):
    if not hier.exists():
        return False
    if nl.exists() and nl.stat().st_mtime >= hier.stat().st_mtime:
        return True
    ys = f"""read_rtlil {hier}
hierarchy -top {TOP}
proc
flatten
opt_clean
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
    # Verilator refuses a line with more than 40000 tokens (wide concatenations
    # in a flattened netlist).  Break long lines after each comma: every token
    # boundary there is whitespace-insensitive, and escaped identifiers end at
    # the space before the comma.
    # Verilator also caps a literal at 65536 bits; a flattened top can carry
    # much wider zero constants (an unused 160064-bit slice of otp_ctrl's
    # broadcast bundle).  Rewrite those as replications / chunked concats.
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
    tmp = nl.with_suffix(".split.v")
    with open(nl, errors="replace") as fi, open(tmp, "w") as fo:
        for line in fi:
            if "'" in line:
                line = wide.sub(shrink, line)
            if len(line) > 8000:
                line = line.replace(", ", ",\n")
            fo.write(line)
    tmp.replace(nl)
    return True


hier = HERE / "work" / chip / f"{chip}_uhdm_hier.il"
nl = WORK / f"uhdm_{TOP}.v"
if not hier.exists():
    print(f"{chip}: NO_RUN (no {hier.name}; run chip_flow.py first)")
    sys.exit(2)
if not netlist("uhdm", hier, nl):
    print(f"{chip}: netlist generation FAILED")
    sys.exit(1)
# The read_slang netlist of the same top: the reference frontend's own co-sim
# vs the RTL, which adjudicates a uhdm divergence (shared => netlist-sim
# artefact, slang clean => read_uhdm bug).
slang_hier = HERE / "work" / chip / f"{chip}_slang_keephier.il"
slang_nl = WORK / f"slang_{TOP}.v"
have_slang = netlist("slang", slang_hier, slang_nl)

# ---------------------------------------------------------------- ports
ports = []   # (dir, width, name)
with open(nl, errors="replace") as fh:
    inmod = False
    for line in fh:
        if not inmod:
            inmod = line.startswith(f"module {TOP}(")
            continue
        m = re.match(r"\s*(input|output|inout)\s+(?:\[(\d+):(\d+)\]\s+)?(\w+)\s*;", line)
        if m:
            w = abs(int(m.group(2)) - int(m.group(3))) + 1 if m.group(2) else 1
            ports.append((m.group(1), w, m.group(4)))
            continue
        # write_verilog interleaves wire/reg declarations with the port
        # declarations; functions (whose own input decls must not be taken)
        # and the body follow them.
        if re.match(r"\s*(function|always|assign|endmodule)\b", line):
            break

# Tie-offs: test/scan controls off, AST reports ready, power good.
MUBI4_TRUE, MUBI4_FALSE = "4'h6", "4'h9"
TIES = {
    "scan_rst_ni": "1'b1", "scan_en_i": "1'b0", "scanmode_i": MUBI4_FALSE,
    "ast_init_done_i": MUBI4_TRUE, "calib_rdy_i": MUBI4_TRUE,
    "flash_bist_enable_i": MUBI4_FALSE, "io_clk_byp_ack_i": MUBI4_FALSE,
    "all_clk_byp_ack_i": MUBI4_FALSE, "div_step_down_req_i": MUBI4_FALSE,
    "pwrmgr_ast_rsp_i": "'1", "dft_hold_tap_sel_i": "1'b0",
    "ram_1p_cfg_i": "'0", "sram_ctrl_main_cfg_i": "'0", "sram_ctrl_ret_aon_cfg_i": "'0",
    "sram_ctrl_mbox_cfg_i": "'0", "spi_ram_2p_cfg_i": "'0", "usb_ram_1p_cfg_i": "'0",
    "rom_cfg_i": "'0", "rom_ctrl0_cfg_i": "'0", "rom_ctrl1_cfg_i": "'0",
    "sensor_ctrl_ast_alert_req_i": "'0", "flash_power_down_h_i": "1'b0",
    "flash_power_ready_h_i": "1'b1", "otp_macro_pwr_seq_h_i": "'0",
}
clocks = [n for d, w, n in ports if d == "input" and re.match(r"clk_\w+_i$", n)]
resets = [n for d, w, n in ports if d == "input" and re.match(r"(por_n_i|rst_\w+_ni)$", n)]

tb = ["`timescale 1ns/1ps", "module tb;", "  logic clk = 1'b0;",
      f"  localparam int CYCLES = {CYCLES};", "  int cyc = 0;",
      "  logic [4095:0] wide = '0;",
      f"  logic [63:0] rng = 64'h{(SEED * 0x9E3779B97F4A7C15) & (2**64 - 1) or 1:016x};"]
for d, w, n in ports:
    if d == "inout":
        tb.append(f"  wire [{w-1}:0] {n};")
    else:
        tb.append(f"  logic [{w-1}:0] {n};")
conns = ",\n    ".join(f".{n}({n})" for _, _, n in ports)
tb.append(f"  {TOP} dut (\n    {conns}\n  );")
for c in clocks:
    tb.append(f"  assign {c} = clk;")
tb.append("  always #5 clk = ~clk;")
# Stimulus: new pseudo-random inputs just after each falling edge.
tb.append("  function automatic logic [63:0] step(logic [63:0] x);")
tb.append("    x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x;")
tb.append("  endfunction")
tb.append("  always @(negedge clk) begin")
for d, w, n in ports:
    if d != "input" or n in clocks:
        continue
    if n in resets:
        tb.append(f"    {n} <= (cyc < 20) ? '0 : '1;")
    elif n in TIES:
        tb.append(f"    {n} <= {TIES[n]};")
    else:
        chunks = (w + 63) // 64
        tb.append(f"    for (int k = 0; k < {chunks}; k++) begin rng = step(rng); wide = {{wide[4031:0], rng}}; end")
        tb.append(f"    {n} <= wide[{w-1}:0];")
tb.append("    cyc <= cyc + 1;")
tb.append("  end")
outs = [(w, n) for d, w, n in ports if d == "output"]
fmt = " ".join(f"{n}=%h" for _, n in outs)
args = ", ".join(n for _, n in outs)
tb.append("  always @(posedge clk) begin")
tb.append(f"    #1 $display(\"C%0d {fmt}\", cyc, {args});")
tb.append("    if (cyc >= CYCLES) $finish;")
tb.append("  end")
tb.append("endmodule")
(WORK / "tb.sv").write_text("\n".join(tb) + "\n")

# ---------------------------------------------------------------- build + run
VFLAGS = ["--binary", "-j", "0", "--timing", "--no-assert", "-Wno-fatal", "-Wno-lint",
          "-Wno-style", "--x-assign", "0", "--x-initial", "0", "-DSYNTHESIS",
          "--top-module", "tb", "-O1"]
incs = [f"+incdir+{d}" for d in paths("incs.txt")]
srcs = [f"{PAVONA}/hw/ip/prim/rtl/prim_assert.sv"] + paths("srcs.txt")
builds = {
    "rtl": VFLAGS + ["--Mdir", "obj_rtl", "-o", "sim_rtl"] + incs + srcs + ["tb.sv"],
    "uhdm": VFLAGS + ["--Mdir", "obj_uhdm", "-o", "sim_uhdm"] + [str(nl), "tb.sv"],
}
if have_slang:
    builds["slang"] = VFLAGS + ["--Mdir", "obj_slang", "-o", "sim_slang"] + [str(slang_nl), "tb.sv"]
traces = {}
for tag, flags in builds.items():
    exe = WORK / f"obj_{tag}" / f"sim_{tag}"
    stamp = [slang_nl if tag == "slang" else nl, WORK / "tb.sv"]
    if not exe.exists() or any(p.stat().st_mtime > exe.stat().st_mtime for p in stamp):
        r = sh([VERILATOR] + flags, log=f"build_{tag}.log")
        if r.returncode or not exe.exists():
            last = (r.stdout + r.stderr).strip().splitlines()[-1:] or [""]
            print(f"{chip}: {tag} Verilator build FAILED: {last[0][:160]}")
            sys.exit(1)
    r = sh([str(exe)], log=f"run_{tag}.log")
    traces[tag] = [l for l in (r.stdout or "").splitlines() if l.startswith("C")]
    if not traces[tag]:
        print(f"{chip}: {tag} simulation produced no trace")
        sys.exit(1)

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
        print(f"{chip} FIRST-{tag.upper()} cycle {first[0]} {first[1]} "
              f"rtl={first[2][:40]} {tag}={first[3][:40]}")
    return n, mism


print(f"{chip} ACTIVITY {activity} cycles with an output change")
n, mu = compare("uhdm")
ms = compare("slang")[1] if "slang" in traces else -1
print(f"{chip} ADJUDICATION {n} cycles: uhdm_vs_rtl={mu} slang_vs_rtl={ms}")
if mu == 0:
    verdict = "NO_DIVERGENCE"
elif ms > 0:
    verdict = "SHARED_DIVERGENCE"
else:
    verdict = "UHDM_DIVERGENCE"
print(f"{chip} VERDICT {verdict}")
