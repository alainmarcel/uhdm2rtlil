#!/usr/bin/env python3
"""Run chipsalliance/sv-tests through read_uhdm, read_verilog and read_slang.

sv-tests (https://github.com/chipsalliance/sv-tests) is the LRM-chapter test
corpus every SystemVerilog tool is scored on.  This runs sv-tests' OWN local
tests -- the `tests/chapter-*` trees, `tests/generic` and `tests/sanity.sv` --
that the corpus does not mark `:unsynthesizable: 1` (its synthesis set, what
its Yosys / Synlig / yosys-slang columns run) through three frontends with
sv-tests' own rules.  The CORE tests sv-tests also defines (ariane/CVA6, ibex,
VeeR, black-parrot, scr1, ...) are NOT swept here: its generators/* build them
from the third_party/cores submodules, and each core gets its own sweep.
Rules:

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

# The other sweeps' structural probes (undriven nets, driver conflicts,
# unresolved reads), reused verbatim so sv-tests rows are measured the same
# way core / ext / pavona rows are.
sys.path.insert(0, HERE)
import core_sweep
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

def _netlist(work, scr_name, script, timeout):
    """Run a yosys script in `work`; return (rc, log)."""
    open(os.path.join(work, scr_name), "w").write(script)
    rc, log, _ = run([YOSYS, "-Q", "-T", "-s", scr_name], work, timeout)
    open(os.path.join(work, scr_name.replace(".ys", ".log")), "w").write(log)
    return rc, log


def _cosim_cells(log, cycles):
    """Render the co-sim columns the way every other sweep does."""
    act = re.search(r"ACTIVITY (\d+) cycles", log)
    a = f" ({cycles + 1} cycles, {act.group(1)} active)" if act else ""
    m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+)(?:\s+slang_vs_rtl=(\d+))?", log)
    if not m:
        if "no outputs to compare" in log or "no clocks found" in log:
            return "— (comb/no clk)", "— (comb/no clk)"
        # Say WHY, don't collapse four different reasons into one opaque
        # "skip (no run)".  For this corpus the answer is almost always
        # structural and worth stating: an LRM snippet is usually a
        # self-contained module with NO PORTS and an `initial` block, so there
        # is nothing for a testbench to drive or compare -- that is the corpus,
        # not a defect.  Reading `skip (no run)` on 526 rows told nobody that.
        nr = re.search(r"NO_RUN \(([^)]*)\)", log)
        if nr:
            why = nr.group(1)
            if "no ports parsed" in why:
                cell = "— (top has no ports)"
            elif "has no outputs" in why:
                cell = "— (top has no outputs)"
            elif "escaped port names" in why:
                cell = "— (interface ports)"
            elif "netlist generation failed" in why:
                cell = "skip (netlist gen failed)"
            else:
                cell = f"— ({why[:40]})"
            return cell, cell
        if "netlist generation FAILED" in log:
            return "skip (netlist gen failed)", "skip (netlist gen failed)"
        if "both simulators failed" in log or "build FAILED" in log:
            return "skip (sim build)", "skip (sim build)"
        if "verilator: not found" in log or "No such file or directory: 'verilator'" in log:
            return "skip (no verilator)", "skip (no verilator)"
        return "— (no run)", "— (no run)"
    if "VERDICT RTL_INERT" in log:
        return "— (RTL inert: no oracle)", "— (RTL inert: no oracle)"
    u = int(m.group(1))
    ours = ("✅ PASS" + a) if u == 0 else f"❌ {u} div"
    if m.group(2) is None:
        return ours, "— (no slang netlist)"
    sv = int(m.group(2))
    return ours, (("✅ PASS" + a) if sv == 0 else f"❌ {sv} div")


def deep_check(args, rel, work, p, files, incs, defs, sl_args, timeout):
    """The checks every other sweep reports, for one sv-tests test.

    sv-tests' own verdict is only "did the frontend read it".  That says
    nothing about whether what we built is RIGHT, which is what the core /
    ext / pavona sweeps measure per module.  This adds the same columns:
    formal equivalence against read_slang, the structural opt-check for
    dropped drivers (undriven nets) and driver conflicts, and the Verilator
    co-simulation of both netlists against the original RTL.
    """
    out = dict(formal="—", undriven="—", conflicts="—", unresolved="—",
               cosim="—", slang_cosim="—")
    # Only 4 of the ~1000 sv-tests declare `:top_module:`, so keying these
    # columns off that header would leave every other row unmeasured.  Let
    # yosys pick, exactly as mode_script does, and read back the name it
    # chose -- `hierarchy -auto-top` prints "Automatically selected <top> as
    # design top module."
    top = p["top_module"].strip()
    if not top:
        rc, log = _netlist(work, "deep_top.ys",
                           f"plugin -i {PLUGIN}\nread_uhdm slpp_all/surelog.uhdm\n"
                           f"hierarchy -auto-top\n", timeout)
        m = re.search(r"Automatically selected (\S+) as design top module", log or "")
        if rc != 0 or not m:
            out["formal"] = "— (no top)"
            return out
        top = m.group(1).lstrip("\\")

    rc, _ = _netlist(work, "deep_uhdm.ys",
                     f"plugin -i {PLUGIN}\nread_uhdm slpp_all/surelog.uhdm\n"
                     f"hierarchy -check -top {top}\nwrite_rtlil uhdm_hier.il\n", timeout)
    if rc != 0:
        out["formal"] = "— (uhdm netlist failed)"
        return out
    rc, _ = _netlist(work, "deep_slang.ys",
                     "read_slang " + " ".join(sl_args + files) +
                     f"\nhierarchy -check -top {top}\nwrite_rtlil slang_hier.il\n", timeout)
    have_slang = rc == 0

    try:
        out["undriven"] = core_sweep._undriven_check(work, top)
        out["conflicts"] = core_sweep._conflict_cell(work)
        out["unresolved"] = core_sweep._unresolved_cell(work)
    except Exception as e:                     # never fail the sweep on a probe
        out["undriven"] = f"error ({type(e).__name__})"

    if not have_slang:
        out["formal"] = "no reference (read_slang fails)"
    else:
        rc, log = _netlist(work, "deep_miter.ys", f"""\
read_rtlil uhdm_hier.il
hierarchy -top {top}
flatten; proc; opt; memory; async2sync
rename {top} gold; design -stash gold
read_rtlil slang_hier.il
hierarchy -top {top}
flatten; proc; opt; memory; async2sync
rename {top} gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq 4 -set-init-zero miter
""", timeout)
        if rc == 0:
            out["formal"] = "✅ equivalent"
        elif rc == 124 or "Interrupted" in log:
            out["formal"] = "❓ SAT timeout"
        elif "Can't find module" in log:
            out["formal"] = "— (not comparable)"
        else:
            out["formal"] = "❌ differs"

    if args.cycles > 0:
        cw = os.path.join(work, "cosim")
        os.makedirs(cw, exist_ok=True)
        open(os.path.join(work, "srcs.txt"), "w").write("\n".join(files) + "\n")
        open(os.path.join(work, "incs.txt"), "w").write("\n".join(incs) + "\n")
        ccmd = [sys.executable, os.path.join(ROOT, "test", "netlist_cosim.py"),
                "--work", cw, "--uhdm-il", os.path.join(work, "uhdm_hier.il"),
                "--top", top, "--rtl-top", top,
                "--srcs", os.path.join(work, "srcs.txt"),
                "--incs", os.path.join(work, "incs.txt"),
                "--cycles", str(args.cycles)]
        if have_slang:
            ccmd += ["--slang-il", os.path.join(work, "slang_hier.il")]
        rc, log, _ = run(ccmd, work, max(timeout, 600))
        open(os.path.join(cw, "cosim.log"), "w").write(log or "")
        out["cosim"], out["slang_cosim"] = _cosim_cells(log or "", args.cycles)
    return out


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
    # The columns every other sweep reports.  Only where a netlist exists:
    # `parsing` / `preprocessing` tests never elaborate, and a read failure
    # has nothing to measure.
    if args.deep and mode not in ("parsing", "preprocessing") and res["uhdm"] == "PASS":
        try:
            res.update(deep_check(args, rel, work, p, files, incs, defs, sl, timeout))
        except Exception as e:
            res["formal"] = f"error ({type(e).__name__})"
    return res

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=os.path.expanduser("~/ext/sv-tests"))
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "sv_tests"))
    ap.add_argument("--filter", help="regex on the test path")
    ap.add_argument("--cycles", type=int, default=300,
                    help="co-sim cycles per test; 0 disables the co-sim columns")
    ap.add_argument("--no-deep", dest="deep", action="store_false",
                    help="only sv-tests' own read verdict -- skip formal / undriven / co-sim")
    ap.set_defaults(deep=True)
    a = ap.parse_args()
    # sv-tests' OWN tests only: the LRM chapter trees, `generic`, and
    # sanity.sv.  Everything else under tests/ is out of scope here --
    # `uvm/` and `testbenches/` are simulation-only, and sv-tests' CORE
    # tests (ariane/CVA6, ibex, VeeR, black-parrot, scr1, rsd, tnoc, rggen,
    # fx68k) do not exist in a clone at all: its generators/* write them
    # into tests/<subdir> from the third_party/cores submodules.  Each of
    # those cores gets its own per-core sweep instead (scr1 is the first),
    # where a module list, parameters and a co-simulation make sense.
    def is_local_test_dir(rel_dir):
        head = rel_dir.split(os.sep)
        if len(head) < 2:
            return True                      # tests/ itself (sanity.sv)
        return head[1].startswith("chapter-") or head[1] == "generic"

    tests = []
    for dp, dn, fn in os.walk(os.path.join(a.repo, "tests")):
        rel_dir = os.path.relpath(dp, a.repo)
        if not is_local_test_dir(rel_dir):
            dn[:] = []                       # do not descend
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
    cols = ["test", "mode", "should_fail", "uhdm", "verilog", "slang",
            "slang_cosim", "formal", "conflicts", "undriven", "unresolved", "cosim",
            "uhdm_err", "verilog_err", "slang_err"]
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
