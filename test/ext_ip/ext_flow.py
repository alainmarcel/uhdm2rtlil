#!/usr/bin/env python3
"""ext_flow.py <family> [module ...] [--filter RE] [--jobs N] [--cycles N]
                        [--no-cosim] [--survey] [--out rows.json]

Generic per-module equivalence sweep for an EXTERNAL IP repository described
by test/ext_ip/<family>.json (no vendored copy: the repo is fetched at a pinned
commit under $EXT_IP_ROOT, default ~/ext).  For every module of the manifest
(or every module found under its source roots when "modules" is "auto"):

  1. dependency closure of the module's sources (identifier scan over the
     roots, packages first — the same closure the Pavona per-IP campaigns use)
  2. Surelog + read_uhdm  vs  read_slang, SAT-mitered from reset (bounded)
  3. structural opt-check (undriven nets after read_uhdm; hierarchy -check)
  4. Verilator co-sim of the read_uhdm and read_slang netlists against the
     behavioural RTL (test/netlist_cosim.py), unless --no-cosim / --survey

Writes <work>/rows.json in core_sweep's row schema and prints the table.
"--survey" only elaborates (read_uhdm / read_slang), no miter, no co-sim: the
first pass on a new repository.

Manifest keys:
  repos:    [{"url", "commit", "dir"}]   dir is relative to $EXT_IP_ROOT
  roots:    [glob, ...]                  source roots, relative to $EXT_IP_ROOT
  incdirs:  [dir, ...]                   relative to $EXT_IP_ROOT
  defines:  ["SYNTHESIS", ...]
  modules:  "auto" | [{"name", "seq", "timeout", "want", "top"?}]
  exclude:  [regex, ...]                 module names to skip in auto mode
  seq / timeout / want:                  defaults for auto mode
"""
import argparse, concurrent.futures as cf, glob, json, os, re, shlex, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEST = HERE.parent
ROOT = TEST.parent
Y = ROOT / "out/current/bin/yosys"
P = ROOT / "build/uhdm2rtlil.so"
S = ROOT / "build/third_party/Surelog/bin/surelog"
EXT = Path(os.environ.get("EXT_IP_ROOT", os.path.expanduser("~/ext")))


def sh(cmd, cwd=None, timeout=None, env=None):
    try:
        p = subprocess.run(cmd, cwd=cwd, text=True, timeout=timeout, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, errors="replace")
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or "") + "\nTIMEOUT"


# ----------------------------------------------------------------- closure
class Closure:
    """Identifier-scan dependency closure over the manifest's source roots."""

    def __init__(self, roots, exts=(".sv", ".v")):
        self.defs, self.files, self.macros = {}, {}, {}
        self.mod_files = {}
        for r in roots:
            for pat in (str(EXT / r),):
                for f in sorted(glob.glob(pat, recursive=True)):
                    if not os.path.isfile(f) or not f.endswith(exts):
                        continue
                    t = open(f, errors="replace").read()
                    is_pkg = False
                    for m in re.findall(r"^\s*(?:module|interface)\s+(\w+)", t, re.M):
                        self.defs.setdefault(m, f)
                        self.mod_files.setdefault(m, f)
                    for p in re.findall(r"^\s*package\s+(\w+)", t, re.M):
                        self.defs.setdefault(p, f)
                        is_pkg = True
                    self.files.setdefault(f, is_pkg)
                    lines = t.split("\n")
                    i = 0
                    while i < len(lines):
                        m = re.match(r"\s*`define\s+(\w+)", lines[i])
                        if m:
                            name, body = m.group(1), [lines[i]]
                            while lines[i].rstrip().endswith("\\") and i + 1 < len(lines):
                                i += 1
                                body.append(lines[i])
                            self.macros[name] = "\n".join(body)
                        i += 1
        self._mcache, self._tcache = {}, {}

    def _macro_refs(self, mname, seen=None):
        if mname in self._mcache:
            return self._mcache[mname]
        seen = seen or set()
        if mname in seen:
            return set()
        seen.add(mname)
        toks = set(re.findall(r"[A-Za-z_]\w*", self.macros.get(mname, "")))
        r = toks & set(self.defs)
        for sub in toks & set(self.macros):
            r |= self._macro_refs(sub, seen)
        self._mcache[mname] = r
        return r

    def refs(self, f):
        if f in self._tcache:
            return self._tcache[f]
        txt = re.sub(r"//[^\n]*", "", open(f, errors="replace").read())
        txt = re.sub(r"/\*.*?\*/", "", txt, flags=re.S)
        toks = set(re.findall(r"[A-Za-z_]\w*", txt))
        r = toks & set(self.defs)
        for mname in toks & set(self.macros):
            r |= self._macro_refs(mname)
        self._tcache[f] = r
        return r

    def closure(self, target):
        seen, st = set(), [target]
        while st:
            n = st.pop()
            if n in seen or n not in self.defs:
                continue
            seen.add(n)
            for r in self.refs(self.defs[n]):
                if r in self.defs and r not in seen:
                    st.append(r)
        files = {self.defs[n] for n in seen}
        # packages first, in dependency order (a package may import another)
        pkgs = [f for f in files if self.files.get(f)]
        rest = sorted(f for f in files if not self.files.get(f))
        ordered, placed = [], set()

        def place(f, stack=()):
            if f in placed or f in stack:
                return
            for r in self.refs(f):
                g = self.defs.get(r)
                if g and g != f and self.files.get(g):
                    place(g, stack + (f,))
            placed.add(f)
            ordered.append(f)
        for f in sorted(pkgs):
            place(f)
        return ordered + rest


# ----------------------------------------------------------------- one module
def run_module(fam, cl, m, seq, tmo, want, incs, defines, cycles, do_cosim, survey, work_root, ties):
    w = work_root / m
    w.mkdir(parents=True, exist_ok=True)
    top = m
    files = cl.closure(m)
    if not files:
        return {"module": m, "formal": "elab-fail", "formal_raw": "elabfail",
                "check": "— (no elaboration)", "cosim": "—", "slang_cosim": "—",
                "note": "no source found"}
    (w / "srcs.txt").write_text("\n".join(files) + "\n")
    (w / "incs.txt").write_text("\n".join(str(EXT / d) for d in incs) + "\n")
    inc_flags = [f"-I{EXT / d}" for d in incs]
    def_flags = [f"-D{d}" for d in defines]
    uhdm = w / "slpp_all" / "surelog.uhdm"
    stale = (not uhdm.exists()) or S.stat().st_mtime > uhdm.stat().st_mtime
    if stale:
        for old in ("slpp_all",):
            subprocess.run(["rm", "-rf", str(w / old)])
        rc, out = sh([str(S), "-parse", "-d", "uhdm", *def_flags, *inc_flags, "-top", top, *files],
                     cwd=w, timeout=900)
        (w / "surelog.log").write_text(out or "")
    if not uhdm.exists():
        err = ""
        try:
            log = (w / "surelog.log").read_text()
            m2 = re.search(r"\[(?:FATAL|ERROR)\][^\n]*", log)
            err = m2.group(0)[:120] if m2 else ""
        except OSError:
            pass
        return {"module": m, "formal": "elab-fail", "formal_raw": "elabfail",
                "check": "— (no elaboration)", "cosim": "—", "slang_cosim": "—", "note": err}
    slang_incs = " ".join(f"-I {shlex.quote(str(EXT / d))}" for d in incs)
    slang_defs = " ".join(f"-D{d}" for d in defines)
    srcs_q = " ".join(shlex.quote(f) for f in files)
    # --- survey / opt-check: read_uhdm, hierarchy -check, flatten, check
    (w / "check.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\nhierarchy -check -top {top}\n"
        f"write_rtlil uhdm_hier.il\nproc\nflatten\nopt_clean\nstat\ncheck\n")
    rc, out = sh([str(Y), "-q", "-m", str(P), "check.ys"], cwd=w, timeout=900)
    (w / "check.log").write_text(out or "")
    if rc != 0 or not (w / "uhdm_hier.il").exists():
        err = re.search(r"ERROR:[^\n]*", out or "")
        return {"module": m, "formal": "read-fail (uhdm)", "formal_raw": "error",
                "check": "—", "cosim": "—", "slang_cosim": "—",
                "note": (err.group(0)[:140] if err else "read_uhdm failed")}
    undriven = len(re.findall(r"is used but has no driver", out or ""))
    cells = re.search(r"Number of cells:\s*(\d+)", out or "")
    check = "✅ 0 undriven" if undriven == 0 else f"❌ {undriven} undriven"
    (w / "slang.ys").write_text(
        f"read_slang --ignore-assertions {slang_defs} {slang_incs} {srcs_q} --top {top}\n"
        f"hierarchy -check -top {top}\nwrite_rtlil slang_hier.il\n")
    rc2, out2 = sh([str(Y), "-q", "slang.ys"], cwd=w, timeout=600)
    (w / "slang.log").write_text(out2 or "")
    slang_ok = rc2 == 0 and (w / "slang_hier.il").exists()
    if survey:
        return {"module": m, "formal": "read OK" if slang_ok else "read OK (slang fails)",
                "formal_raw": "read", "check": check, "cosim": "—", "slang_cosim": "—",
                "note": f"{cells.group(1)} cells" if cells else ""}
    if not slang_ok:
        err = re.search(r"(ERROR|error)[^\n]*", out2 or "")
        return {"module": m, "formal": "no reference (read_slang fails)", "formal_raw": "error",
                "check": check, "cosim": "—", "slang_cosim": "—",
                "note": (err.group(0)[:140] if err else "")}
    # --- miter
    (w / "miter.ys").write_text(f"""read_rtlil uhdm_hier.il
hierarchy -top {top}
flatten; proc; opt; memory; async2sync; delete t:$check t:$assert t:$assume t:$print t:$scopeinfo
rename {top} gold; design -stash gold
read_rtlil slang_hier.il
hierarchy -top {top}
flatten; proc; opt; memory; async2sync; delete t:$check t:$assert t:$assume t:$print t:$scopeinfo
rename {top} gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq {seq} -set-init-zero miter
""")
    mem = os.environ.get("MEM_LIMIT_KB")
    cmd = ["timeout", str(tmo), str(Y), "miter.ys"]
    if mem:
        cmd = ["bash", "-c", f"ulimit -v {mem}; exec \"$@\"", "--"] + cmd
    rc3, out3 = sh(cmd, cwd=w, timeout=tmo + 60)
    (w / "miter.log").write_text(out3 or "")
    if "no model found: SUCCESS" in (out3 or ""):
        got = "proven"
    elif "model found: FAIL" in (out3 or ""):
        got = "cex"
    elif rc3 == 124 or "TIMEOUT" in (out3 or ""):
        got = "timeout"
    elif rc3 in (134, 137, -6, -9) or "bad_alloc" in (out3 or "") or "OutOfMemory" in (out3 or ""):
        got = "memlimit"
    else:
        got = "error"
    label = {"proven": "✅ equivalent", "cex": "❌ differs", "timeout": "❓ SAT timeout",
             "memlimit": "❓ SAT over memory cap", "error": "error"}
    row = {"module": m, "formal": label[got], "formal_raw": got, "check": check,
           "cosim": "—", "slang_cosim": "—", "want": want}
    # --- co-sim
    if do_cosim and cycles > 0:
        for tag in ("uhdm", "slang"):
            (w / f"ren_{tag}.ys").write_text(
                f"read_rtlil {tag}_hier.il\nhierarchy -top {top}\nrename {top} {m}_{tag}\n"
                f"write_rtlil {m}_{tag}.il\n")
            sh([str(Y), "-q", f"ren_{tag}.ys"], cwd=w, timeout=600)
        cw = w / "cosim"
        cw.mkdir(exist_ok=True)
        (cw / "ties.json").write_text(json.dumps(ties))
        ccmd = [sys.executable, str(TEST / "netlist_cosim.py"), "--work", str(cw),
                "--uhdm-il", str(w / f"{m}_uhdm.il"), "--slang-il", str(w / f"{m}_slang.il"),
                "--top", f"{m}_uhdm", "--rtl-top", top,
                "--srcs", str(w / "srcs.txt"), "--incs", str(w / "incs.txt"),
                "--cycles", str(cycles), "--ties", str(cw / "ties.json")]
        if mem:
            ccmd = ["bash", "-c", f"ulimit -Sv {mem}; exec " + " ".join(shlex.quote(c) for c in ccmd)]
        rc4, out4 = sh(ccmd, cwd=w, timeout=3600)
        (cw / "cosim.log").write_text(out4 or "")
        mm = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+) slang_vs_rtl=(\d+)", out4 or "")
        act = re.search(r"ACTIVITY (\d+) cycles", out4 or "")
        if mm:
            u, sl = int(mm.group(1)), int(mm.group(2))
            a = f" ({cycles + 1} cycles, {act.group(1)} active)" if act else ""
            row["cosim"] = ("✅ PASS" + a) if u == 0 else (
                f"⚠ shared div (uhdm={u}, slang={sl})" if sl > 0 else f"❌ {u} div (slang clean)")
            row["slang_cosim"] = "✅ PASS" if sl == 0 else f"❌ {sl} div"
        elif "no outputs to compare" in (out4 or "") or "no clocks found" in (out4 or ""):
            row["cosim"] = "— (comb/no clk)"
        elif "NO_RUN" in (out4 or "") or "netlist generation FAILED" in (out4 or ""):
            row["cosim"] = "skip (no run)"
        elif "both simulators failed" in (out4 or "") or "build FAILED" in (out4 or ""):
            row["cosim"] = "skip (sim build)"
        else:
            row["cosim"] = "error" if rc4 else "skip"
    return row


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("family")
    ap.add_argument("modules", nargs="*")
    ap.add_argument("--filter")
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--cycles", type=int, default=300)
    ap.add_argument("--no-cosim", action="store_true")
    ap.add_argument("--survey", action="store_true")
    ap.add_argument("--out", type=Path)
    ap.add_argument("--list", action="store_true", help="print the module list and exit")
    args = ap.parse_args()
    man = json.loads((HERE / f"{args.family}.json").read_text())
    work_root = TEST / "ext_ip" / "work" / args.family
    work_root.mkdir(parents=True, exist_ok=True)
    cl = Closure(man["roots"])
    excl = [re.compile(x) for x in man.get("exclude", [])]
    if man.get("modules") == "auto":
        pref = man.get("only_prefix")
        mods = [{"name": n} for n in sorted(cl.mod_files)
                if not any(x.search(n) for x in excl)
                and (not pref or n.startswith(pref))]
    else:
        mods = man["modules"]
    if args.modules:
        mods = [x for x in mods if x["name"] in set(args.modules)]
    if args.filter:
        mods = [x for x in mods if re.search(args.filter, x["name"])]
    if args.list:
        print("\n".join(x["name"] for x in mods))
        return
    seq0, tmo0, want0 = man.get("seq", 4), man.get("timeout", 300), man.get("want", "proven")
    ties = man.get("ties", {})
    print(f"# ext_ip {args.family}: {len(mods)} module(s), roots {man['roots']}", flush=True)

    def one(x):
        t0 = time.time()
        r = run_module(args.family, cl, x["name"], x.get("seq", seq0), x.get("timeout", tmo0),
                       x.get("want", want0), man.get("incdirs", []), man.get("defines", ["SYNTHESIS"]),
                       args.cycles, not args.no_cosim, args.survey, work_root, ties)
        want = x.get("want", want0)
        ico = "✅" if r.get("formal_raw") in ("proven", "read") else ("‼" if r.get("formal_raw") == "elabfail" else "❌")
        if r.get("formal_raw") == want:
            ico = "✅"
        print(f"  {ico} {r['module']:<34} {r['formal']:<28} {r['check']:<16} {r['cosim']:<32} "
              f"{r.get('note','')[:60]}  [{time.time() - t0:.0f}s]", flush=True)
        return r
    with cf.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
        rows = list(ex.map(one, mods))
    rows.sort(key=lambda r: r["module"])
    n = len(rows)
    prov = sum(1 for r in rows if r.get("formal_raw") == "proven")
    read = sum(1 for r in rows if r.get("formal_raw") in ("proven", "cex", "timeout", "memlimit", "read"))
    print(f"{args.family.upper()} equivalence: {prov}/{n} proven, {read}/{n} elaborate "
          f"({sum(1 for r in rows if r.get('formal_raw') == 'elabfail')} elab-fail, "
          f"{sum(1 for r in rows if r.get('formal_raw') == 'error')} error)")
    out = args.out or (work_root / "rows.json")
    out.write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
