#!/usr/bin/env python3
"""Full-chip flow for a Pavona top (egret | dragonfly): elaborate with Surelog,
import with read_uhdm, elaborate with read_slang --keep-hierarchy, then pair
every DIRECT instance of the top between the two netlists and SAT-miter each
pair (read_uhdm vs read_slang, bounded from reset).

  chip_flow.py <chip> [inst ...]      # default: every common instance

Environment: PAVONA (Pavona checkout, default test/pavona_chips/pavona),
SEQ (miter depth, default 2), TIMEOUT (per miter, s), JOBS (parallel miters),
SKIP_IMPORT=1 (reuse existing work/<chip>/*.il).

Prints one row per instance in the run_*_equiv.sh format core_sweep.py parses:
  "  ✅ u_uart0  proven (want=proven)"
and a summary line "<CHIP> equivalence: N/M proven".

Memory bounding: large RAMs are shrunk to MEMSIZE words on BOTH sides before
memory_map (identical bounded-address abstraction).  Instances whose RAM has
write ports on different clocks (spi_device) use the global-clock flow:
clk2fflogic + memory_map -formal + a no-simultaneous-clock-edge assumption.
"""
import json, os, re, subprocess, sys, time, concurrent.futures as cf
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
ROOT = HERE.parent.parent
Y = os.environ.get("YOSYS", str(ROOT / "out/current/bin/yosys"))
P = os.environ.get("UHDM_PLUGIN", str(ROOT / "build/uhdm2rtlil.so"))
S = os.environ.get("SURELOG", str(ROOT / "build/third_party/Surelog/bin/surelog"))
PAVONA = os.environ.get("PAVONA", str(HERE / "pavona"))
ADD_CLK_EXCL = ROOT / "test/pavona_periph5_equiv/scripts/add_clk_excl.py"

chip = sys.argv[1]
only = sys.argv[2:]
TOP = f"top_{chip}"
W = HERE / "work" / chip
INST = W / "inst"
SEQ = int(os.environ.get("SEQ", "2"))
TIMEOUT = int(os.environ.get("TIMEOUT", "1800"))
JOBS = int(os.environ.get("JOBS", "2"))
MEMSIZE = int(os.environ.get("MEMSIZE", "16"))
UH = W / f"{chip}_uhdm_hier.il"
SL = W / f"{chip}_slang_keephier.il"

# Instances with a dual-clock RAM: (clock ports, RAM cell glob, words, steps).
GCLK = {
    "u_spi_device": (["clk_i", "cio_sck_i", "scan_clk_i"], "*u_mem.mem", 64, 8),
}


def paths(fname):
    return [l.strip().replace("${PAVONA}", PAVONA)
            for l in (HERE / chip / fname).read_text().splitlines() if l.strip()]


def run(cmd, log, timeout=None):
    t0 = time.time()
    with open(W / log, "w") as fh:
        r = subprocess.run(cmd, cwd=W, stdout=fh, stderr=subprocess.STDOUT,
                           timeout=timeout)
    print(f"# {log}: exit {r.returncode} in {time.time() - t0:.0f}s", flush=True)
    return r.returncode


def elaborate():
    W.mkdir(parents=True, exist_ok=True)
    incs, srcs = paths("incs.txt"), paths("srcs.txt")
    if run([S, "-parse", "-mt", "4", "-DSYNTHESIS"] + [f"-I{d}" for d in incs] +
           ["-top", TOP] + srcs, "surelog.log", timeout=3600):
        pass  # Surelog returns non-zero on warnings; the .uhdm is checked below
    if not (W / "slpp_all/surelog.uhdm").exists():
        print(f"# surelog produced no UHDM"); return False
    errs = re.search(r"\[  ERROR\] : (\d+)", (W / "surelog.log").read_text(errors="replace"))
    print(f"# surelog errors: {errs.group(1) if errs else '?'}")
    (W / "uhdm_read.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\nhierarchy -check -top {TOP}\n"
        f"write_rtlil {UH.name}\n")
    if run([Y, "-q", "-m", P, "uhdm_read.ys"], "uhdm_read.log", timeout=3600) or not UH.exists():
        print("# read_uhdm FAILED"); return False
    sinc = " ".join(f"-I {d}" for d in incs)
    (W / "slang_keep.ys").write_text(
        f"read_slang --ignore-assertions -DSYNTHESIS --single-unit --relax-enum-conversions "
        f"{sinc} {PAVONA}/hw/ip/prim/rtl/prim_assert.sv {' '.join(srcs)} "
        f"--top {TOP} --keep-hierarchy\nhierarchy -check -top {TOP}\nwrite_rtlil {SL.name}\n")
    if run([Y, "-q", "slang_keep.ys"], "slang_keep.log", timeout=3600) or not SL.exists():
        print("# read_slang FAILED"); return False
    return True


def top_cells(il):
    cells, inmod = {}, False
    with open(il, errors="replace") as fh:
        for line in fh:
            if line.startswith("module "):
                inmod = line.strip() == f"module \\{TOP}"
            elif inmod:
                m = re.match(r"  cell (\S+) \\(\S+)$", line)
                if m and (not m.group(1).startswith("$") or m.group(1).startswith("$paramod")):
                    cells[m.group(2)] = m.group(1)
                if line.startswith("end"):
                    inmod = False
    return cells


def split():
    u, s = top_cells(UH), top_cells(SL)
    common = sorted(set(u) & set(s))
    for n in sorted(set(u) ^ set(s)):
        print(f"# only in {'uhdm' if n in u else 'slang'}: {n}")
    INST.mkdir(parents=True, exist_ok=True)
    # The RTLIL type of every common instance ("$paramod\\mod\\P=s32'..." or
    # "\\mod"): core_sweep's per-instance co-sim rebuilds the RTL module with
    # the instance's parameters from it.
    (INST / "instances.json").write_text(json.dumps({n: u[n] for n in common}, indent=1))
    for tag, il, cells in (("uhdm", UH, u), ("slang", SL, s)):
        ys = [f"read_rtlil {il}", "design -save full"]
        for n in common:
            t = cells[n]
            ys += [f"hierarchy -top {t}", f"rename {t} {n}_{tag}",
                   f"write_rtlil {INST}/{n}_{tag}.il", "design -load full"]
        (INST / f"split_{tag}.ys").write_text("\n".join(ys) + "\n")
    for tag in ("uhdm", "slang"):
        subprocess.run([Y, "-q", "-m", P, str(INST / f"split_{tag}.ys")],
                       capture_output=True, text=True)
    return common


FLOW = ("proc; flatten; opt_clean; memory -nomap; "
        "setparam -set SIZE {m} t:$mem_v2 r:SIZE>{m} %i; memory_map; opt; async2sync; "
        "delete t:$check t:$assert t:$assume t:$print t:$scopeinfo")
GFLOW = ("proc; flatten; opt; memory -nordff -nomap; "
         "setparam -set SIZE {m} c:{g} t:$mem_v2 %i; clk2fflogic; memory_map -formal; opt_clean; "
         "delete t:$check t:$assert t:$assume t:$print t:$scopeinfo")


def miter(n):
    d = INST / n
    d.mkdir(parents=True, exist_ok=True)
    flow, cstr, satx, seq = FLOW.format(m=MEMSIZE), "", "", SEQ
    if n in GCLK:
        clks, glob, words, seq = GCLK[n]
        flow = GFLOW.format(m=words, g=glob)
        cstr = (f"write_rtlil {d}/miter.il\n"
                f"!python3 {ADD_CLK_EXCL} {d}/miter.il {' '.join('in_' + c for c in clks)}\n"
                f"design -reset\nread_rtlil {d}/miter.il\n")
        satx = "-set-assumes"
        for ci, c in enumerate(clks):
            for st in range(1, seq + 1):
                v = int(st % 2 == 0) if ci == 0 else int(st % 4 in (3, 0)) if ci == 1 else 0
                satx += f" -set-at {st} in_{c} {v}"
    ys = f"""read_rtlil {INST}/{n}_uhdm.il
hierarchy -top {n}_uhdm
{flow}
rename {n}_uhdm gold
design -stash gold
read_rtlil {INST}/{n}_slang.il
hierarchy -top {n}_slang
{flow}
rename {n}_slang gate
design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert -ignore_gold_x gold gate miter
hierarchy -top miter
{cstr}sat -verify -prove-asserts {satx} -seq {seq} -set-init-zero miter
"""
    (d / "miter.ys").write_text(ys)
    try:
        r = subprocess.run(["timeout", str(TIMEOUT), Y, "-m", P, str(d / "miter.ys")],
                           capture_output=True, text=True, errors="replace")
        out, rc = r.stdout + r.stderr, r.returncode
    except Exception as e:
        out, rc = str(e), -1
    (d / "miter.log").write_text(out)
    if "no model found: SUCCESS" in out: return n, "proven"
    if "model found: FAIL" in out: return n, "cex"
    if rc == 124: return n, "timeout"
    return n, "error"


def main():
    if os.environ.get("SKIP_IMPORT") != "1" or not (UH.exists() and SL.exists()):
        if not elaborate():
            print(f"{chip.upper()} equivalence: 0/0 proven (elaboration failed)")
            return 1
    common = split()
    names = [n for n in common if not only or n in only]
    ok = 0
    with cf.ThreadPoolExecutor(JOBS) as ex:
        for n, v in ex.map(miter, names):
            ico = "✅" if v == "proven" else "❌"
            ok += v == "proven"
            print(f"  {ico} {n:32s} {v} (want=proven)", flush=True)
    print(f"{chip.upper()} equivalence: {ok}/{len(names)} proven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
