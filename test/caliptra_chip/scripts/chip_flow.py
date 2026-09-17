#!/usr/bin/env python3
"""Full-chip flow for caliptra_top: elaborate with Surelog, import with
read_uhdm, elaborate the same sources with read_slang --keep-hierarchy, then
pair every DIRECT instance of the top between the two netlists and SAT-miter
each pair (read_uhdm vs read_slang, bounded from reset).

  chip_flow.py [inst ...]             # default: every common instance

Environment: CALIPTRA (checkout, default test/caliptra_chip/caliptra-rtl),
SEQ (miter depth, default 2), TIMEOUT (per miter, s), JOBS (parallel miters),
MEMSIZE (bounded RAM depth), SKIP_IMPORT=1 (reuse existing work/*.il).

Prints one row per instance in the run_*_equiv.sh format core_sweep.py parses:
  "  ✅ u_soc_ifc_top  proven (want=proven)"
and a summary line "CALIPTRA equivalence: N/M proven".

caliptra_top has six SystemVerilog INTERFACE ports.  read_slang refuses a
top-level module with an unconnected interface port, so both frontends are
pointed at the generated flat-port wrapper `caliptra_top_flat` instead (see
scripts/gen_wrapper.py); the instances that get mitered are the direct
children of caliptra_top either way, since the wrapper adds exactly one level.
"""
import json, os, re, subprocess, sys, time, concurrent.futures as cf
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
ROOT = HERE.parent.parent
Y = os.environ.get("YOSYS", str(ROOT / "out/current/bin/yosys"))
P = os.environ.get("UHDM_PLUGIN", str(ROOT / "build/uhdm2rtlil.so"))
S = os.environ.get("SURELOG", str(ROOT / "build/third_party/Surelog/bin/surelog"))
CALIPTRA = os.environ.get("CALIPTRA", str(HERE / "caliptra-rtl"))
GEN_WRAPPER = HERE / "scripts/gen_wrapper.py"

only = sys.argv[1:]
# SHARD=i/n (set by core_sweep.py): with n > 1 the last shard miters nothing
# (it runs the full-chip co-sim) and the others take the instances
# round-robin — the same plan as core_sweep._chip_shard_plan.
_shard = os.environ.get("SHARD", "1/1").split("/")
SHARD_IDX, SHARD_CNT = int(_shard[0]) - 1, int(_shard[1])
MEM_LIMIT_KB = int(os.environ.get("MEM_LIMIT_KB", "0"))
CHIP = "caliptra"
TOP = "caliptra_top_flat"
INNER = "caliptra_top"
W = HERE / "work"
INST = W / "inst"
WRAPPER = W / "caliptra_top_flat.sv"
SEQ = int(os.environ.get("SEQ", "2"))
TIMEOUT = int(os.environ.get("TIMEOUT", "7200"))
JOBS = int(os.environ.get("JOBS", "2"))
MEMSIZE = int(os.environ.get("MEMSIZE", "16"))
UH = W / "caliptra_uhdm_hier.il"
SL = W / "caliptra_slang_keephier.il"
BARE = W / "caliptra_top_bare.il"


def paths(fname):
    return [l.strip().replace("${CALIPTRA}", CALIPTRA)
            for l in (HERE / fname).read_text().splitlines() if l.strip()]


def run(cmd, log, timeout=None):
    t0 = time.time()
    with open(W / log, "w") as fh:
        r = subprocess.run(cmd, cwd=W, stdout=fh, stderr=subprocess.STDOUT,
                           timeout=timeout)
    print(f"# {log}: exit {r.returncode} in {time.time() - t0:.0f}s", flush=True)
    return r.returncode


def surelog(top, extra, outdir, log):
    incs, srcs = paths("incs.txt"), paths("srcs.txt")
    run([S, "-parse", "-sverilog", "-mt", "4", "-o", outdir] +
        [f"-I{d}" for d in incs] + ["-top", top] + srcs + extra, log, timeout=3600)
    uhdm = W / outdir / "slpp_all/surelog.uhdm"
    if not uhdm.exists():
        # The nightly reported "exit 1 in 0s" with nothing else to go on —
        # show the tail of the Surelog log so a missing checkout, a bad
        # binary or a fatal parse error is readable from the Actions log.
        print(f"# surelog produced no UHDM for {top}; tail of {log}:")
        try:
            for l in (W / log).read_text(errors="replace").splitlines()[-15:]:
                print(f"#   {l}")
        except OSError as e:
            print(f"#   ({e})")
        print(f"# surelog binary: {S} exists={os.path.exists(S)}; "
              f"first source exists={os.path.exists(srcs[0]) if srcs else None}")
        return None
    errs = re.search(r"\[  ERROR\] : (\d+)", (W / log).read_text(errors="replace"))
    print(f"# surelog errors ({top}): {errs.group(1) if errs else '?'}")
    return uhdm


def elaborate():
    W.mkdir(parents=True, exist_ok=True)
    # Pass 1: import the bare chip, purely to read the elaborated geometry of
    # its interface ports back out -- that netlist is the only place axi_if's
    # AW/DW/IW/UW, el2_mem_if's `pt` struct and abr_mem_if's macro-generated
    # widths are all resolved, so it is what the wrapper is generated from.
    uhdm = surelog(INNER, [], "sl_bare", "surelog_bare.log")
    if not uhdm:
        return False
    (W / "bare_read.ys").write_text(
        f"read_uhdm {uhdm}\nhierarchy -check -top {INNER}\nwrite_rtlil {BARE.name}\n")
    if run([Y, "-q", "-m", P, "bare_read.ys"], "bare_read.log", timeout=3600) \
            or not BARE.exists():
        print("# read_uhdm (bare) FAILED"); return False
    if subprocess.run([sys.executable, str(GEN_WRAPPER), str(BARE), str(WRAPPER)]).returncode:
        print("# wrapper generation FAILED"); return False

    # Pass 2: both frontends on the wrapper.
    incs, srcs = paths("incs.txt"), paths("srcs.txt")
    uhdm = surelog(TOP, [str(WRAPPER)], "sl_flat", "surelog_flat.log")
    if not uhdm:
        return False
    (W / "uhdm_read.ys").write_text(
        f"read_uhdm {uhdm}\nhierarchy -check -top {TOP}\nwrite_rtlil {UH.name}\n")
    if run([Y, "-q", "-m", P, "uhdm_read.ys"], "uhdm_read.log", timeout=3600) \
            or not UH.exists():
        print("# read_uhdm FAILED"); return False
    sinc = " ".join(f"-I {d}" for d in incs)
    (W / "slang_keep.ys").write_text(
        f"read_slang --ignore-assertions --single-unit --relax-enum-conversions "
        f"{sinc} {' '.join(srcs)} {WRAPPER} "
        f"--top {TOP} --keep-hierarchy\nhierarchy -check -top {TOP}\n"
        f"write_rtlil {SL.name}\n")
    if run([Y, "-q", "slang_keep.ys"], "slang_keep.log", timeout=3600) or not SL.exists():
        print("# read_slang FAILED"); return False
    return True


def cells_of(il, top):
    """{instance name: cell type} for the direct cells of `top` in `il`.

    `top` is the module name exactly as it appears after "module " in the
    RTLIL -- i.e. WITH its leading "\\" for a public name, and WITHOUT one for
    an auto-generated "$paramod..." name, which is how a cell line spells its
    type too.  (Prefixing a "$paramod" name with a backslash finds nothing.)
    """
    cells, inmod = {}, False
    with open(il, errors="replace") as fh:
        for line in fh:
            if line.startswith("module "):
                inmod = line.strip() == f"module {top}"
            elif inmod:
                m = re.match(r"  cell (\S+) \\(\S+)$", line)
                if m and (not m.group(1).startswith("$")
                          or m.group(1).startswith("$paramod")):
                    cells[m.group(2)] = m.group(1)
                if line.startswith("end"):
                    inmod = False
    return cells


def chip_type(il):
    """The type the wrapper instantiates caliptra_top as, as RTLIL spells it.

    read_uhdm stamps the parameters into the name ("$paramod\\caliptra_top\\pt=...")
    while read_slang --keep-hierarchy appends the instance path
    ("\\caliptra_top$caliptra_top_flat.chip"), so neither side can be predicted
    -- look it up from the wrapper's own cell list instead.
    """
    for name, typ in cells_of(il, f"\\{TOP}").items():
        # "$paramod\\caliptra_top\\pt=s32'..." -> "caliptra_top";
        # "\\caliptra_top$caliptra_top_flat.chip" -> "caliptra_top$...".
        bare = typ[len("$paramod\\"):] if typ.startswith("$paramod\\") else typ.lstrip("\\")
        bare = bare.split("\\", 1)[0]
        if bare.startswith(INNER):
            return typ
    return f"\\{INNER}"


def split():
    u = cells_of(UH, chip_type(UH))
    s = cells_of(SL, chip_type(SL))
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


def miter(n):
    d = INST / n
    d.mkdir(parents=True, exist_ok=True)
    flow = FLOW.format(m=MEMSIZE)
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
sat -verify -prove-asserts -seq {SEQ} -set-init-zero miter
"""
    (d / "miter.ys").write_text(ys)
    try:
        # Cap each miter's address space (MEM_LIMIT_KB shared by the JOBS
        # concurrent SATs): an over-budget proof then dies as "error" instead
        # of taking the 16 GB runner down with it.
        cmd = ["timeout", str(TIMEOUT), Y, "-m", P, str(d / "miter.ys")]
        if MEM_LIMIT_KB > 0:
            cmd = ["bash", "-c", f"ulimit -v {MEM_LIMIT_KB // max(1, JOBS)}; exec \"$@\"", "--"] + cmd
        r = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
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
            print("CALIPTRA equivalence: 0/0 proven (elaboration failed)")
            return 1
    common = split()
    names = [n for n in common if not only or n in only]
    if SHARD_CNT > 1:
        names = [] if SHARD_IDX == SHARD_CNT - 1 else sorted(names)[SHARD_IDX::SHARD_CNT - 1]
        print(f"# shard {SHARD_IDX + 1}/{SHARD_CNT}: {len(names)} instance(s) to miter")
    ok = 0
    with cf.ThreadPoolExecutor(JOBS) as ex:
        for n, v in ex.map(miter, names):
            ico = "✅" if v == "proven" else "❌"
            ok += v == "proven"
            print(f"  {ico} {n:32s} {v} (want=proven)", flush=True)
    print(f"CALIPTRA equivalence: {ok}/{len(names)} proven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
