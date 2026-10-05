#!/usr/bin/env python3
"""Run chipsalliance/sv-tests through read_uhdm, read_verilog and read_slang.

sv-tests (https://github.com/chipsalliance/sv-tests) is the LRM-chapter test
corpus every SystemVerilog tool is scored on.  This runs every test the corpus
does not mark `:unsynthesizable: 1` (its synthesis set -- what its Yosys /
Synlig / yosys-slang columns run) through three frontends with sv-tests' own
rules:

  mode      first of simulation, simulation_without_run, elaboration, parsing,
            preprocessing listed in the test's `:type:` (default "parsing
            elaboration"); the Yosys runner's script per mode:
              parsing/preprocessing  read only (read_verilog -defer)
              elaboration            read; hierarchy; proc; check; clean;
                                     memory_dff; memory_collect; stat; check
              simulation*            the same, then `sim -assert`
  expected  a test with `:should_fail_because:` PASSES when the tool fails
  timeout   the test's `:timeout:` (default 30 s), x4 and at least 120 s here
            because Surelog + a plugin load are slower than one read_verilog

Frontends:
  uhdm      surelog -parse (our workflow flags) + read_uhdm, then the mode script
  verilog   read_verilog -sv (sv-tests' own Yosys runner, the yosys column)
  slang     read_slang with sv-tests' yosys_slang runner flags (-DSYNTHESIS
            --ignore-timing --ignore-initial --ignore-assertions --single-unit
            ...) -- that runner only READS, it never runs the mode script, so
            the slang column means "read_slang elaborates it", nothing more

Usage: python3 sv_tests_sweep.py --repo ~/ext/sv-tests --jobs 8 --out build/sv_tests
Writes <out>/results.tsv (test, mode, should_fail, per-frontend verdict and
first diagnostic) and leaves each test's run under <out>/work/<test>/.
"""
import argparse, concurrent.futures as cf, os, re, shlex, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
YOSYS = os.path.join(ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(ROOT, "build", "uhdm2rtlil.so")
SURELOG = os.path.join(ROOT, "build", "third_party", "Surelog", "bin", "surelog")
MODES = ["simulation", "simulation_without_run", "elaboration", "parsing", "preprocessing"]

def parse_header(path):
    p = {}
    try:
        txt = open(path, errors="replace").read(20000)
    except Exception:
        return None
    m = re.search(r"/\*(.*?)\*/", txt, re.S)
    if not m:
        return None
    for line in m.group(1).splitlines():
        mm = re.match(r"\s*:([a-z_\-]+):\s*(.*?)\s*$", line)
        if mm:
            p[mm.group(1)] = mm.group(2)
    if "name" not in p:
        return None
    p.setdefault("type", "parsing elaboration")
    p.setdefault("timeout", "30")
    p.setdefault("top_module", "")
    p.setdefault("defines", "")
    p.setdefault("incdirs", os.path.dirname(path))
    p.setdefault("unsynthesizable", "0")
    p.setdefault("compatible-runners", "all")
    p["should_fail"] = "1" if p.get("should_fail_because") else p.get("should_fail", "0")
    p["files"] = p.get("files", path).split()
    return p

def mode_for(p):
    feats = p["type"].split()
    for m in MODES:
        if m in feats:
            return m
    return None

def run(cmd, cwd, timeout):
    t0 = time.time()
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout + r.stderr, time.time() - t0
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        return 124, out, time.time() - t0

def first_error(log, frontend):
    pats = [r"^ERROR: .*", r".*: error: .*", r"^\[ERR:.*", r"^\[FAT:.*", r"^\[SNT:.*", r"Assert .* failed", r"terminate called.*"]
    for pat in pats:
        m = re.search(pat, log, re.M)
        if m:
            return re.sub(r"/[^ ]*/(sv-tests|uhdm2rtlil)/", "", m.group(0)).strip()[:200]
    return ""

def mode_script(p, mode):
    top = p["top_module"].strip()
    s = ""
    if mode not in ("parsing", "preprocessing"):
        s += (f"hierarchy {'-top ' + top if top else '-auto-top'}\nproc\ncheck\nclean\nmemory_dff\nmemory_collect\nstat\ncheck\n")
    if mode in ("simulation", "simulation_without_run"):
        s += "sim -assert\n"
    return s

def run_test(args, rel, path, p):
    mode = mode_for(p)
    res = dict(test=rel, mode=mode or "-", should_fail=p["should_fail"])
    if int(p["unsynthesizable"]) or mode is None:
        for fe in ("uhdm", "verilog", "slang"):
            res[fe] = "SKIP"; res[fe + "_err"] = "unsynthesizable" if int(p["unsynthesizable"]) else "no supported mode"
        return res
    work = os.path.join(args.out, "work", rel.replace("/", "__"))
    os.makedirs(work, exist_ok=True)
    timeout = max(int(p["timeout"]) * 4, 120)
    incs = p["incdirs"].split()
    defs = p["defines"].split()
    files = [os.path.abspath(f) if os.path.isabs(f) else os.path.abspath(os.path.join(args.repo, f)) if not os.path.exists(f) else os.path.abspath(f) for f in p["files"]]
    want_fail = p["should_fail"] == "1"
    def verdict(rc, log):
        if rc == 124:
            return "TIMEOUT"
        failed = rc != 0
        return "PASS" if failed == want_fail else "FAIL"
    # ---- verilog (sv-tests' Yosys runner)
    defer = "-defer " if mode in ("parsing", "preprocessing") else ""
    nodisp = "-nodisplay " if mode.startswith("simulation") else ""
    inc = "".join(f" -I {i}" for i in incs); de = "".join(f" -D {d}" for d in defs)
    scr = "".join(f"read_verilog {defer}-sv {nodisp}{inc}{de} {f}\n" for f in files) + mode_script(p, mode)
    open(os.path.join(work, "verilog.ys"), "w").write(scr)
    rc, log, dt = run([YOSYS, "-Q", "-T", "-s", "verilog.ys"], work, timeout)
    open(os.path.join(work, "verilog.log"), "w").write(log)
    res["verilog"] = verdict(rc, log); res["verilog_err"] = first_error(log, "verilog") if rc else ""
    # ---- slang (sv-tests' yosys_slang runner: read only)
    sl = ["-DSYNTHESIS", "--ignore-timing", "--ignore-initial", "--ignore-assertions", "--single-unit", "--timescale=1ns/1ns",
          "-Wno-error=index-oob", "-Wno-error=range-oob", "-Wno-error=range-width-oob"]
    if p["top_module"].strip(): sl.append("--top=" + p["top_module"].strip())
    for i in incs: sl += ["-I", i]
    for d in defs: sl += ["-D", d]
    scr = "read_slang " + " ".join(sl + files) + "\n"
    open(os.path.join(work, "slang.ys"), "w").write(scr)
    rc, log, dt = run([YOSYS, "-Q", "-T", "-s", "slang.ys"], work, timeout)
    open(os.path.join(work, "slang.log"), "w").write(log)
    res["slang"] = verdict(rc, log); res["slang_err"] = first_error(log, "slang") if rc else ""
    # ---- uhdm (our workflow's Surelog flags, then read_uhdm + the mode script)
    cmd = [SURELOG, "-parse", "-nobuiltin", "-nocache", "-DSYNTHESIS", "-filterprotected", "-d", "uhdm", "-sverilog", "-nonote", "-noinfo"]
    if p["top_module"].strip(): cmd += ["--top-module", p["top_module"].strip()]
    cmd += ["-I" + i for i in incs] + ["-D" + d for d in defs] + files
    rc, log, dt = run(cmd, work, timeout)
    open(os.path.join(work, "surelog.log"), "w").write(log)
    uhdm = os.path.join(work, "slpp_all", "surelog.uhdm")
    if rc != 0 or not os.path.exists(uhdm) or re.search(r"^\[(ERR|FAT|SNT):", log, re.M):
        res["uhdm"] = "TIMEOUT" if rc == 124 else ("PASS" if want_fail else "FAIL")
        res["uhdm_err"] = "surelog: " + first_error(log, "uhdm") if rc != 124 else "surelog timeout"
        return res
    if mode in ("parsing", "preprocessing"):
        scr = f"plugin -i {PLUGIN}\nread_uhdm slpp_all/surelog.uhdm\n"
    else:
        scr = f"plugin -i {PLUGIN}\nread_uhdm slpp_all/surelog.uhdm\n" + mode_script(p, mode)
    open(os.path.join(work, "uhdm.ys"), "w").write(scr)
    rc, log, dt = run([YOSYS, "-Q", "-T", "-s", "uhdm.ys"], work, max(timeout - int(dt), 60))
    open(os.path.join(work, "uhdm.log"), "w").write(log)
    res["uhdm"] = verdict(rc, log); res["uhdm_err"] = first_error(log, "uhdm") if rc else ""
    return res

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=os.path.expanduser("~/ext/sv-tests"))
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "sv_tests"))
    ap.add_argument("--filter", help="regex on the test path")
    a = ap.parse_args()
    tests = []
    for dp, dn, fn in os.walk(os.path.join(a.repo, "tests")):
        rel_dir = os.path.relpath(dp, a.repo)
        if rel_dir.startswith(("tests/uvm", "tests/testbenches")):
            continue
        for f in sorted(fn):
            if not f.endswith((".sv", ".v")):
                continue
            path = os.path.join(dp, f); rel = os.path.relpath(path, a.repo)
            if a.filter and not re.search(a.filter, rel):
                continue
            p = parse_header(path)
            if p:
                tests.append((rel, path, p))
    os.makedirs(a.out, exist_ok=True)
    print(f"{len(tests)} tests", flush=True)
    rows = []
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        futs = {ex.submit(run_test, a, rel, path, p): rel for rel, path, p in tests}
        for i, fut in enumerate(cf.as_completed(futs), 1):
            r = fut.result(); rows.append(r)
            if i % 50 == 0: print(f"  {i}/{len(tests)}", flush=True)
    rows.sort(key=lambda r: r["test"])
    cols = ["test", "mode", "should_fail", "uhdm", "verilog", "slang", "uhdm_err", "verilog_err", "slang_err"]
    with open(os.path.join(a.out, "results.tsv"), "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r.get(c, "")).replace("\t", " ") for c in cols) + "\n")
    run_rows = [r for r in rows if r["uhdm"] != "SKIP"]
    print(f"synthesis set: {len(run_rows)} (skipped {len(rows) - len(run_rows)} unsynthesizable / no mode)")
    for fe in ("uhdm", "verilog", "slang"):
        c = {k: sum(1 for r in run_rows if r[fe] == k) for k in ("PASS", "FAIL", "TIMEOUT")}
        print(f"  {fe:8s} PASS {c['PASS']}  FAIL {c['FAIL']}  TIMEOUT {c['TIMEOUT']}")
    print(f"-> {os.path.join(a.out, 'results.tsv')}")

if __name__ == "__main__":
    main()
