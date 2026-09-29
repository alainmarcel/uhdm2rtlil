#!/usr/bin/env python3
"""CVA6 full-core equivalence: elaborate the `cva6` top ONCE with read_uhdm and
read_slang (hierarchy kept), enumerate every instance at every level of the
elaborated hierarchy, pair the two hierarchies by instance path, and miter one
representative per distinct elaborated parameterisation ($paramod) -- i.e.
every module the core instantiates, with exactly the parameters it has under
the chip's configuration, the way the pavona / caliptra chip flows do it for
their tops.  The per-module sweep (cva6_equiv) instead wraps each module with
cva6.sv's parameter block, which cannot see an instantiation's own overrides
(a load port vs a store port of the same adapter, a 2- vs 5-way LZC...).

Usage: chip_flow.py [instance-path ...]   (env: SHARD=i/n, JOBS, SEQ, TIMEOUT,
MEMSIZE, MEM_LIMIT_KB, SKIP_IMPORT=1 to reuse the elaborated netlists)
Prints one `  ✅/❌ <path> <verdict> (want=proven)` line per representative
instance, then `CVA6-CHIP equivalence: k/n proven`."""
import concurrent.futures as cf
import json, os, re, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent          # test/cva6_chip
TEST = HERE.parent
ROOT = TEST.parent
Y = os.environ.get("YOSYS", str(ROOT / "out/current/bin/yosys"))
P = os.environ.get("UHDM_PLUGIN", str(ROOT / "build/uhdm2rtlil.so"))
S = os.environ.get("SURELOG", str(ROOT / "build/third_party/Surelog/bin/surelog"))
RTL = os.environ.get("CVA6_RTL", str(TEST / "cva6_equiv" / "rtl"))
TOP = "cva6"
W = HERE / "work"
INST = W / "inst"
only = sys.argv[1:]
_shard = os.environ.get("SHARD", "1/1").split("/")
SHARD_IDX, SHARD_CNT = int(_shard[0]) - 1, int(_shard[1])
MEM_LIMIT_KB = int(os.environ.get("MEM_LIMIT_KB", "0"))
SEQ = int(os.environ.get("SEQ", "2"))
TIMEOUT = int(os.environ.get("TIMEOUT", "900"))
JOBS = int(os.environ.get("JOBS", "2"))
if SHARD_CNT > 1:
    JOBS = 1        # one miter at a time so each proof gets the whole MEM_LIMIT_KB
MEMSIZE = int(os.environ.get("MEMSIZE", "16"))
UH = W / "cva6_uhdm_hier.il"
SL = W / "cva6_slang_keephier.il"
FLIST = W / "cva6.f"


def run(cmd, log, timeout=None):
    t0 = time.time()
    if MEM_LIMIT_KB > 0:
        cmd = ["bash", "-c", "ulimit -v 15000000; exec \"$@\"", "--"] + list(cmd)
    with open(W / log, "w") as fh:
        r = subprocess.run(cmd, cwd=W, stdout=fh, stderr=subprocess.STDOUT, timeout=timeout)
    print(f"# {log}: exit {r.returncode} in {time.time() - t0:.0f}s", flush=True)
    return r.returncode


def elaborate():
    W.mkdir(parents=True, exist_ok=True)
    FLIST.write_text((TEST / "cva6_equiv" / "cva6.flist").read_text().replace("__CVA6_RTL__", RTL))
    # Same invocations as the per-module flow (run_cva6_equiv.sh), on the core
    # top itself: cva6.sv's defaults ARE the chip configuration
    # (build_config(cva6_config_pkg::cva6_cfg)).
    run([S, "-parse", "-sverilog", "-mt", "4", "-f", str(FLIST), "-top", TOP],
        "surelog.log", timeout=3600)
    if not (W / "slpp_all/surelog.uhdm").exists():
        print("# surelog produced no UHDM"); return False
    errs = re.search(r"\[  ERROR\] : (\d+)", (W / "surelog.log").read_text(errors="replace"))
    print(f"# surelog errors: {errs.group(1) if errs else '?'}")
    (W / "uhdm_read.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\nhierarchy -check -top {TOP}\nwrite_rtlil {UH.name}\n")
    if run([Y, "-q", "-m", P, "uhdm_read.ys"], "uhdm_read.log", timeout=3600) or not UH.exists():
        print("# read_uhdm FAILED"); return False
    (W / "slang_keep.ys").write_text(
        f"read_slang --ignore-assertions -f {FLIST} --top {TOP} --keep-hierarchy\n"
        f"hierarchy -check -top {TOP}\nwrite_rtlil {SL.name}\n")
    if run([Y, "-q", "slang_keep.ys"], "slang_keep.log", timeout=3600) or not SL.exists():
        print("# read_slang FAILED"); return False
    return True


def module_cells(il):
    """{module name: {cell name: cell type}} for every user/paramod cell."""
    mods, cur = {}, None
    with open(il, errors="replace") as fh:
        for line in fh:
            if line.startswith("module "):
                cur = line.split(None, 1)[1].strip()
                mods[cur] = {}
            elif cur is not None:
                m = re.match(r"  cell (\S+) (\S+)$", line)
                if m and (not m.group(1).startswith("$") or m.group(1).startswith("$paramod")):
                    mods[cur][m.group(2)] = m.group(1)
                elif line.startswith("end"):
                    cur = None
    return mods


def norm(name):
    return name.lstrip("\\")


# read_uhdm numbers every generate construct of a module (untaken `if` arms
# included) while read_slang numbers only the elaborated ones, so an unnamed
# block is `genblk3` on one side and `genblk1` on the other
# (store_unit's amo_buffer).  Pair on a key that drops the number; a module
# with two unnamed generate blocks at the same level would collide, and the
# first one wins (reported as "only in" for the other).
def key(path):
    return re.sub(r"genblk\d+", "genblk", path)


def walk(mods, top):
    """{instance path: module type} over the whole hierarchy under `top`."""
    out = {}
    def rec(mod, prefix):
        for cell, typ in mods.get(mod, {}).items():
            path = (prefix + "." if prefix else "") + norm(cell)
            out[path] = typ
            if typ in mods:
                rec(typ, path)
    rec(top, "")
    return out


def top_name(mods):
    for m in mods:
        if norm(m) == TOP or m == f"\\{TOP}":
            return m
    return f"\\{TOP}"


def split():
    um, sm = module_cells(UH), module_cells(SL)
    u_raw, s_raw = walk(um, top_name(um)), walk(sm, top_name(sm))
    u, s = {}, {}
    for pth, typ in u_raw.items():
        u.setdefault(key(pth), typ)
    for pth, typ in s_raw.items():
        s.setdefault(key(pth), typ)
    common = sorted(set(u) & set(s))
    odd = sorted(set(u) ^ set(s))
    for n in odd[:40]:
        print(f"# only in {'uhdm' if n in u else 'slang'}: {n}")
    if len(odd) > 40:
        print(f"# ... {len(odd) - 40} more unpaired instance(s)")
    # One representative per distinct read_uhdm parameterisation: the
    # shortest path (stable: sorted) among the instances that share it.
    groups = {}
    for p in common:
        groups.setdefault(u[p], []).append(p)
    # Row / file names are the MODULE's base name (numbered when several
    # distinct parameterisations share it), never the instance path: a deep
    # fpnew generate path exceeds the 255-byte file-name limit and killed the
    # whole split script.  The representative path and the group's instance
    # list travel in groups.json.
    reps = {}
    for typ, paths in groups.items():
        paths.sort(key=lambda x: (x.count("."), x))
        reps[paths[0]] = (typ, paths)
    def base(typ):
        t = typ.lstrip("\\")
        if t.startswith("$paramod"):
            t = t[len("$paramod"):].lstrip("\\").split("\\", 1)[0]
        return re.split(r"[$\\]", t)[0]
    counts, short = {}, {}
    for path in sorted(reps, key=lambda x: (base(reps[x][0]), x)):
        b = base(reps[path][0])
        counts[b] = counts.get(b, 0) + 1
        short[path] = b if counts[b] == 1 else f"{b}#{counts[b]}"
    names = sorted(short.values())
    by_short = {short[pth]: pth for pth in short}
    print(f"# {len(u)} instances (uhdm), {len(s)} (slang), {len(common)} paired, "
          f"{len(names)} distinct parameterisations", flush=True)
    INST.mkdir(parents=True, exist_ok=True)
    (INST / "instances.json").write_text(
        json.dumps({n: reps[by_short[n]][0] for n in names}, indent=1))
    (INST / "groups.json").write_text(
        json.dumps({n: {"rep": by_short[n], "paths": reps[by_short[n]][1]} for n in names}, indent=1))
    for tag, il, cells in (("uhdm", UH, u), ("slang", SL, s)):
        ys = [f"read_rtlil {il}", "design -save full"]
        for n in names:
            t = cells[by_short[n]]
            ys += [f"hierarchy -top {t}", f"rename {t} {n}_{tag}",
                   f"write_rtlil {INST}/{n}_{tag}.il", "design -load full"]
        (INST / f"split_{tag}.ys").write_text("\n".join(ys) + "\n")
        r = subprocess.run([Y, "-q", "-m", P, str(INST / f"split_{tag}.ys")],
                           capture_output=True, text=True)
        (INST / f"split_{tag}.log").write_text(r.stdout + r.stderr)
    return names


FLOW = ("proc; flatten; opt_clean; memory -nomap; "
        "setparam -set SIZE {m} t:$mem_v2 r:SIZE>{m} %i; memory_map; opt; async2sync; "
        "delete t:$check t:$assert t:$assume t:$print t:$scopeinfo")


def _ports(il, top):
    """{name: direction} of the top module's ports in a split .il"""
    ports, inside = {}, False
    for line in open(il, errors="replace"):
        if line.startswith("module "):
            inside = line.split()[1] == "\\" + top
        elif inside and line.startswith("end"):
            break
        elif inside and line.startswith("  wire "):
            m = re.search(r"\b(input|output|inout) \d+ (\S+)$", line.rstrip())
            if m:
                ports[m.group(2)] = m.group(1)
    return ports


def miter(n):
    d = INST / n
    d.mkdir(parents=True, exist_ok=True)
    flow = FLOW.format(m=MEMSIZE)
    pu = _ports(INST / f"{n}_uhdm.il", f"{n}_uhdm")
    ps = _ports(INST / f"{n}_slang.il", f"{n}_slang")
    # A module with no output at all (cva6's `unread` sink, `input d_i` and
    # nothing else) has nothing to compare: `design -copy-from` finds no
    # module to copy once flatten/opt have emptied it, and the miter errored
    # on a row that is trivially equivalent.
    if not any(v != "input" for v in pu.values()) and not any(v != "input" for v in ps.values()):
        (d / "miter.log").write_text("no output port on either side: nothing to compare "
                                     "(sink module) -- trivially equivalent\n")
        return n, "proven"
    # An upward hierarchical reference from OUTSIDE the instance
    # (`issue_stage_i.i_scoreboard.issue_instr_o` read by cva6's instr_tracer,
    # which is `ifndef VERILATOR` and elaborated by read_uhdm only) is exported
    # as an extra dotted port of the instance on that side alone; miter -equiv
    # then aborts with "No matching port in gate module".  Those exports carry
    # no logic of the instance: drop the one-sided dotted ports before the
    # miter.  Ports both sides have (interface members, `\iface.sig`) stay.
    def drop(side_ports, other):
        return [f"delete -port w:{p}" for p in side_ports
                if "." in p.lstrip("\\") and p not in other]
    drop_u = "\n".join(drop(pu, ps))
    drop_s = "\n".join(drop(ps, pu))
    ys = f"""read_rtlil {INST}/{n}_uhdm.il
hierarchy -top {n}_uhdm
{drop_u}
{flow}
rename {n}_uhdm gold
design -stash gold
read_rtlil {INST}/{n}_slang.il
hierarchy -top {n}_slang
{drop_s}
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
    if rc in (134, 137, -6, -9) or "bad_alloc" in out or "Out of memory" in out \
            or "OutOfMemory" in out or "Killed" in out:
        return n, "memlimit"
    return n, "error"


def main():
    if os.environ.get("SKIP_IMPORT") != "1" or not (UH.exists() and SL.exists()):
        if not elaborate():
            print("CVA6-CHIP equivalence: 0/0 proven (elaboration failed)")
            return 1
    names = split()
    if only:
        groups = json.loads((INST / "groups.json").read_text())
        names = [n for n in names
                 if any(re.search(o, n) or re.search(o, groups[n]["rep"]) for o in only)]
    if SHARD_CNT > 1:
        names = sorted(names)[SHARD_IDX::SHARD_CNT]
        print(f"# shard {SHARD_IDX + 1}/{SHARD_CNT}: {len(names)} instance(s) to miter")
    ok = 0
    with cf.ThreadPoolExecutor(JOBS) as ex:
        for n, v in ex.map(miter, names):
            ico = "✅" if v == "proven" else "❌"
            ok += v == "proven"
            print(f"  {ico} {n:48s} {v} (want=proven)", flush=True)
    print(f"CVA6-CHIP equivalence: {ok}/{len(names)} proven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
