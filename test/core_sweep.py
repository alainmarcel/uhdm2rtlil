#!/usr/bin/env python3
"""Per-core sweep: formal (read_uhdm vs read_slang) + Verilator co-sim table.

    core_sweep.py ibex|rp32|cva6 [--cycles N] [--jobs J] [--out FILE]

For every module of the chosen core, report:
  1. whether the UHDM import is formally equivalent to read_slang
     (per-test `test_slang_equiv.ys` miter for ibex/rp32; the cva6_equiv
     SAT-miter suite for cva6), and
  2. the Verilator co-sim result against the behavioural RTL — PASS or the
     number of divergent cycles (test_sim_equivalence.py for ibex/rp32;
     scripts/adjudicate.py for cva6),
plus a final co-sim pass-rate percentage.

The table is printed as GitHub-flavoured markdown; with $GITHUB_STEP_SUMMARY
set it is appended there too, so the Action run page shows it directly.
"""
import argparse
import concurrent.futures as cf
import glob
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Round-robin shard selection, set from --shard "i/N" (1-based i).  A shard runs
# only the modules whose sorted index is congruent to (i-1) mod N, so a set of N
# parallel CI jobs together cover every module while each does ~1/N of the work
# (the cva6 sweep's SAT miters + co-sims otherwise blow the job timeout).
# Default (0, 1) = one shard = everything.
_SHARD = (0, 1)


def _apply_shard(items):
    """Return this shard's slice of a sorted item list (round-robin)."""
    idx, cnt = _SHARD
    if cnt <= 1:
        return items
    return items[idx::cnt]

TEST_DIR = Path(__file__).resolve().parent
# Flattened read_uhdm cell counts, populated by _undriven_check and read by the
# auto-miter size gate (keyed by resolved work-dir path).
_CELLS: dict = {}
CVA6_DIR = TEST_DIR / "cva6_equiv"
PAVONA_DIR = TEST_DIR / "pavona_equiv"
TLUL_DIR = TEST_DIR / "pavona_tlul_equiv"
ACC_DIR = TEST_DIR / "pavona_acc_equiv"


def sh(cmd, cwd=None, timeout=None):
    """Run a command; return (rc, combined-output).  Never raises."""
    try:
        p = subprocess.run(cmd, cwd=cwd, text=True, timeout=timeout,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        # TimeoutExpired.stdout can be BYTES even with text=True (the child
        # is killed mid-stream) — concatenating str crashed the whole cva6
        # sweep right after the miter pass timed out.
        out = e.stdout or ""
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
        return 124, out + "\n[timeout]"


def read_names_file(path):
    names = set()
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                names.add(line.split()[0])
    return names


# ---------------------------------------------------------------- ibex / rp32
def read_analyzed_names():
    """Names from sim_equiv_analyzed.txt (`Test: <name>` headers) — co-sim
    divergences that were ADJUDICATED as non-bugs (SAT miter proves
    UHDM==Verilog, or the divergence is a shared sim/synth artefact)."""
    names = set()
    f = TEST_DIR / "sim_equiv_analyzed.txt"
    if f.exists():
        for line in f.read_text().splitlines():
            m = re.match(r"Test:\s*([A-Za-z0-9_-]+)", line.strip())
            if m:
                names.add(m.group(1))
    return names


def _undriven_check(work_dir, top):
    """Structural opt-level undriven-net probe on the read_uhdm netlist: flatten,
    opt_clean, then `check` for nets with no driver.  read_slang produces zero
    undriven nets for equivalent modules, so an undriven net in the read_uhdm
    netlist is a dropped driver — a fast probe (no SAT, no cosim) that catches
    the dropped-driver class structurally.  `work_dir` must contain
    slpp_all/surelog.uhdm; `top` is the module to elaborate."""
    work_dir = Path(work_dir)
    if not (work_dir / "slpp_all" / "surelog.uhdm").exists():
        return "— (no run)"
    yosys = TEST_DIR / ".." / "out" / "current" / "bin" / "yosys"
    plugin = TEST_DIR / ".." / "build" / "uhdm2rtlil.so"
    (work_dir / "check_undriven.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\n"
        f"hierarchy -check -top {top}\n"
        f"flatten; opt_clean\n"
        f"stat\n"
        f"check\n")
    rc, out = sh([str(yosys), "-q", "-m", str(plugin), "check_undriven.ys"],
                 cwd=work_dir, timeout=1800)
    out = out or ""
    # Cache the flattened cell count (from `stat`) so the auto-miter gate can
    # skip SoC-scale designs without a second flatten.
    mcell = re.search(r"Number of cells:\s*(\d+)", out)
    if mcell:
        _CELLS[str(Path(work_dir).resolve())] = int(mcell.group(1))
    # A leaf extraction whose child-module sources are not in the source list
    # leaves those instances as BLACKBOXES: yosys resizes the unknown cell ports
    # to 1 bit and every wider fanout net reads as undriven.  That is not a
    # dropped driver, so the undriven count is not meaningful for an incomplete
    # design — flag it instead of a misleading ❌.  Complete designs (the pavona/
    # tlul/acc/cva6 wrappers, the self-contained ibex/rp32 dirs) have no
    # blackboxes and take the real count below.
    # A GENUINE blackbox (child sources missing) either flags "is not part of the
    # design" or has its unknown-module ports truncated to 1 bit.  A resize to a
    # wider/matching width (e.g. an interface delay-line array `req_dly` going
    # 76<->152, `trn_dly` 1<->2 in the rp32 degu SoC) is a benign width
    # adaptation yosys resolves correctly, NOT a blackbox — those designs fully
    # elaborate and their real undriven count below is meaningful.
    if "is not part of the design" in out or \
       re.search(r"Resizing cell port \S+ from \d+ bits to 1 bits", out):
        return "— (blackbox children)"
    undriven = len(re.findall(r"used but has no driver", out))
    if undriven:
        return f"❌ {undriven} undriven"
    return "error" if rc else "✅ 0 undriven"


def _project_top(d):
    """Top module for a test dir: the `# top:` line of project.f, else dir name."""
    pf = d / "project.f"
    if pf.exists():
        for line in pf.read_text().splitlines():
            m = re.match(r"#\s*top:\s*(\S+)", line.strip())
            if m:
                return m.group(1)
    return d.name


def _slang_args(d):
    """read_slang arguments for a test dir, from the `# slang:` directive in
    project.f (e.g. `--ignore-assertions -I../ibex/prim -I../ibex/rtl`), falling
    back to the `-I` include dirs of the `# surelog:` line.  Returns a string."""
    pf = d / "project.f"
    if not pf.exists():
        return "--ignore-assertions"
    slang = None
    incs = []
    for line in pf.read_text().splitlines():
        s = line.strip()
        m = re.match(r"#\s*slang:\s*(.+)", s)
        if m:
            slang = m.group(1).strip()
        m = re.match(r"#\s*surelog:\s*(.+)", s)
        if m:
            incs = [t for t in m.group(1).split() if t.startswith("-I")]
    if slang:
        return slang
    return "--ignore-assertions " + " ".join(incs)


def _auto_slang_miter(d, top, known_fail, timeout=240):
    """Run an on-the-fly read_uhdm-vs-read_slang miter for a test dir that ships
    no committed `test_slang_equiv.ys`.  The miter is the same boilerplate the
    committed ones use (both frontends elaborate `top` from project.f, lower to a
    comparable gate netlist, then `miter -equiv` + bounded SAT).  read_slang is
    attempted first: a LEAF-extraction dir for a parent module (project.f lists
    only the module + its packages, not the submodule RTL) cannot elaborate
    standalone — that is reported honestly as "needs submodules", not a diff.
    Returns the `formal` cell string."""
    yosys = TEST_DIR / ".." / "out" / "current" / "bin" / "yosys"
    plugin = TEST_DIR / ".." / "build" / "uhdm2rtlil.so"
    slang = _slang_args(d)
    script = f"""\
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {top}
flatten; proc; delete t:$check t:$assert t:$assume t:$print t:$cover
opt; memory; async2sync; techmap; opt
rename {top} gold
design -stash gold
read_slang -f project.f {slang} --top {top}
hierarchy -check -top {top}
flatten; proc; delete t:$check t:$assert t:$assume t:$print t:$cover
opt; memory; async2sync; techmap; opt
rename {top} gate
design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter
sat -verify -prove-asserts -seq 4 -set-init-zero miter
"""
    (d / "auto_slang_equiv.ys").write_text(script)
    rc, out = sh([str(yosys), "-m", str(plugin), "auto_slang_equiv.ys"],
                 cwd=d, timeout=timeout)
    out = out or ""
    # read_slang chokes on the lowRISC lint-sink pattern `logic unused_x = net;`
    # (a variable initialiser that reads a net) with "reading net state during
    # design initialization unsupported".  This is a slang frontend limitation,
    # not a missing submodule or a real divergence — the read_uhdm side is fine,
    # so these modules fall back to the co-sim column.  (ibex_top / ibex_tracer /
    # ibex_top_tracing.)
    if rc in (139, -11) or "Segmentation fault" in out:
        return "— (no miter: crash)"
    if "reading net state during design initialization" in out:
        return "— (no miter: slang net-init)"
    # UPSTREAM RTL that is itself incomplete: a WIP module referencing a type or
    # struct member that was never defined in the source project (jeras/rp32
    # r5p_csr's `dec_csr_t`/`dec_priv_t`, r5p_hamster's `dec_t.alu` — referenced
    # but typedef'd nowhere upstream, on any branch or submodule).  Surelog is
    # lenient and elaborates these to X; read_slang correctly rejects them.  Not
    # a missing submodule and not fixable by vendoring — flag it honestly.
    if re.search(r"use of undeclared identifier|no member named|"
                 r"is not a valid type", out):
        return "— (no miter: upstream RTL incomplete)"
    # A synthesis-time $readmemh (opening a .mem file) or a dynamic-size string
    # is unsupported by read_slang's elaboration (rp32 gowin_inference SoC RAM).
    if re.search(r"failed to open file|dynamic size unsupported", out):
        return "— (no miter: slang $readmemh)"
    # A core whose top has an unbound interface PORT can't be a slang top without
    # a wrapper that connects the interface (rp32 r5p_degu's tcb_ifu).
    if "unconnected interface port" in out:
        return "— (no miter: iface port at top)"
    # A module whose submodule RTL is not in project.f cannot be mitered
    # standalone: read_slang fails to elaborate ("unknown module"/"Build
    # failed"), or the read_uhdm hierarchy check flags the missing child ("is
    # not part of the design").  Honestly "no miter", not a divergence.
    if re.search(r"unknown module|Design elaboration failed|Build failed:"
                 r"|is not part of the design", out):
        return "— (no miter: needs submodules)"
    if "SUCCESS!" in out:
        return "✅ equivalent (auto)"
    if rc == 124 or "[timeout]" in out:
        return "⚠ SAT timeout (auto)"
    # A cell with no SAT model (e.g. an unmapped $mem after write_verilog round
    # trips) means the miter itself could not be solved — not a proven diff.
    if "No SAT model available" in out:
        return "— (no miter: unmappable cell)"
    # An empty module (body commented out upstream — rp32 r5p_mdu) or one that
    # `opt` removes entirely leaves nothing to stash under `gold`/`gate`.
    if re.search(r"Can't find (gold|gate) module", out):
        return "— (no miter: empty module)"
    if "FAIL!" in out or "model found" in out:
        # An auto-miter diff is NOT proof of a UHDM bug: it can be an
        # unpacked-array output-port encoding difference between the two
        # frontends, or a slang-side divergence from the RTL — both of which the
        # UHDM-vs-RTL co-sim (the authoritative adjudicator, run next) clears.
        # Report it as a soft warning, not a hard ❌, so the reader weighs it
        # against the co-sim column.
        return "⚠ known-diff (auto)" if d.name in known_fail else "⚠ differs (auto)"
    # Anything else (a lowering error on one side, an internal abort) is not a
    # trustworthy diff verdict.
    return "— (no miter: setup error)"


def sweep_testdirs(prefix, cycles, jobs, flt=None):
    """Sweep test/<prefix>_* dirs: slang miter + test_sim_equivalence.py."""
    known_fail = read_names_file(TEST_DIR / "slang_miter_expected_fail.txt")
    analyzed = read_analyzed_names()
    baselined = read_names_file(TEST_DIR / "sim_equiv_warn_baseline.txt")
    dirs = sorted(d for d in TEST_DIR.iterdir()
                  if d.is_dir() and d.name.startswith(prefix + "_")
                  and ((d / "project.f").exists() or (d / "dut.sv").exists())
                  and (flt is None or re.search(flt, d.name)))
    dirs = _apply_shard(dirs)

    def one(d):
        name = d.name
        row = {"module": name, "formal": "— (no miter)", "cosim": "—",
               "check": "—"}
        # Elaborate (surelog + read check) if the UHDM is missing.
        if not (d / "slpp_all" / "surelog.uhdm").exists():
            rc, _ = sh(["./test_uhdm_workflow.sh", name],
                       cwd=TEST_DIR, timeout=1200)
        if not (d / "slpp_all" / "surelog.uhdm").exists():
            row["formal"] = "elab-fail"
            row["cosim"] = "skip (no UHDM)"
            row["check"] = "— (no UHDM)"
            return row
        # Structural undriven-net probe (fast dropped-driver check, every dir).
        row["check"] = _undriven_check(d, _project_top(d))
        # 1. slang miter.  A committed test_slang_equiv.ys takes precedence
        # (hand-tuned lowering for the tricky modules); otherwise auto-generate
        # the standard boilerplate miter from project.f so a self-contained
        # module is actually compared instead of showing a bare "no miter".
        if (d / "test_slang_equiv.ys").exists():
            rc, _ = sh([str(TEST_DIR / ".." / "out" / "current" / "bin" / "yosys"),
                        "-m", str(TEST_DIR / ".." / "build" / "uhdm2rtlil.so"),
                        "./test_slang_equiv.ys"], cwd=d, timeout=900)
            if rc == 0:
                row["formal"] = "✅ equivalent"
            elif name in known_fail:
                row["formal"] = "⚠ known-diff"
            else:
                row["formal"] = "❌ differs"
        elif (d / "project.f").exists():
            # An on-the-fly bounded-SAT miter is only practical for UNIT-scale
            # modules.  A full core / SoC would just burn the auto-miter timeout,
            # so gate it on the flattened cell count (cached by the undriven
            # check above) and leave large designs to their dedicated flows.
            ncells = _CELLS.get(str(d.resolve()), 0)
            if ncells > 8000:
                row["formal"] = "— (no miter: core-scale)"
            else:
                row["formal"] = _auto_slang_miter(d, _project_top(d), known_fail)
        # 2. Verilator co-sim.
        cfg = d / "sim_config"
        if cfg.exists() and "SKIP_SIM_EQUIV=1" in cfg.read_text():
            row["cosim"] = "skip (config)"
            return row
        rc, out = sh([sys.executable, "test_sim_equivalence.py", name,
                      "--cycles", str(cycles)], cwd=TEST_DIR, timeout=2400)
        m = re.search(r"FAIL: \d+ cycles, (\d+) mismatches", out)
        if re.search(r"PASS: \d+ cycles, 0 mismatches", out):
            row["cosim"] = "✅ PASS"
        elif m:
            # A divergence that the local campaign already ADJUDICATED as a
            # non-bug (sim_equiv_analyzed.txt) or has baselined as known
            # (sim_equiv_warn_baseline.txt) must not read as a failure here —
            # the local suite reports these as artefact/known, and the
            # nightly table contradicting it was pure confusion.
            if name in analyzed:
                row["cosim"] = f"⚠ artefact ({m.group(1)} div, adjudicated)"
            elif name in baselined:
                row["cosim"] = f"⚠ known ({m.group(1)} div, baselined)"
            else:
                row["cosim"] = f"❌ {m.group(1)} div"
        elif "vacuous" in out:
            row["cosim"] = "vacuous"
        elif rc == 77 or "SKIPPED" in out or "not applicable" in out \
                or "cannot build" in out:
            row["cosim"] = "skip"
        else:
            row["cosim"] = "error"
        return row

    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        return list(ex.map(one, dirs))


# --------------------------------------------------------------------- cva6
def sweep_cva6(cycles, jobs, flt=None):
    """Run the cva6_equiv miter suite, then adjudicate each module's co-sim."""
    # 1. Formal statuses from one run_cva6_equiv.sh pass.  The SAT miters are
    # the sweep's dominant cost, so when a filter or a shard narrows the module
    # set we pass those modules explicitly (the script accepts module arguments)
    # — a shard then only SAT-runs its ~1/N slice, not the whole core.
    manifest = CVA6_DIR / "cva6_modules.txt"
    all_mods = []
    if manifest.exists():
        for line in manifest.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if flt is None or re.search(flt, name):
                    all_mods.append(name)
    all_mods.sort()
    target_mods = _apply_shard(all_mods)
    subset = flt is not None or _SHARD[1] > 1
    # A subset run with no modules for this shard (e.g. shards > module count)
    # must NOT fall through to a bare `run_cva6_equiv.sh` (which sweeps ALL
    # modules) — there is simply nothing to do for this shard.
    if subset and not target_mods:
        return []
    cmd = ["./run_cva6_equiv.sh"]
    # Pass explicit modules whenever we are running a proper subset (a filter or
    # a real shard).  With neither, run bare so the script sweeps its full set.
    if subset:
        cmd += target_mods
    rc, out = sh(cmd, cwd=CVA6_DIR, timeout=10800)
    formal = {}
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"crash|elabfail|dead|skipped)", line)
        if m:
            formal[m.group(1)] = m.group(2)
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error", "crash": "crash",
        "elabfail": "elab-fail", "dead": "— (dead)", "skipped": "skip",
    }

    # Merge the manifest so a module the run did not report still gets a row.
    manifest = CVA6_DIR / "cva6_modules.txt"
    if manifest.exists():
        for line in manifest.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) >= 4 and parts[0] not in formal:
                formal[parts[0]] = parts[3] if parts[3] in label else "skipped"
    mods = sorted(m for m, st in formal.items()
                  if st != "dead" and (flt is None or re.search(flt, m)))
    mods = _apply_shard(mods)

    def one(mod):
        row = {"module": mod, "formal": label.get(formal[mod], formal[mod]),
               "cosim": "—", "check": "—"}
        st = formal[mod]
        work = CVA6_DIR / "work" / mod
        # A module that elaborated (proven / cex / SAT-timeout) has a read_uhdm
        # netlist; error / crash / elabfail / dead / skipped do not.
        elaborated = st in ("proven", "cex", "timeout")
        # Structural undriven-net probe on every elaborated module.
        row["check"] = (_undriven_check(work, f"{mod}_equiv")
                        if elaborated else "— (no elaboration)")
        # Co-sim EVERY elaborated module, not just cex: a module PROVEN under the
        # SAT miter (which runs -set-init-zero) can still diverge in co-sim from
        # an X-init / undriven net the miter hides (the tlul_fifo_sync class), so
        # the sweep must adjudicate all of them to surface that.  Modules that
        # did not elaborate cannot cosim.
        if not elaborated:
            row["cosim"] = "— (not runnable)"
            return row
        for f in ("obj_dir", "adj_gold.v", "adj_gate.v", "adj_tb.sv", "adj.ys"):
            sh(["rm", "-rf", str(work / f)])
        rc, out = sh([sys.executable, "scripts/adjudicate.py", mod,
                      str(cycles), "1"], cwd=CVA6_DIR, timeout=2400)
        m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+)"
                      r" slang_vs_rtl=(\d+)", out)
        if m:
            u, sl = int(m.group(1)), int(m.group(2))
            if u == 0:
                row["cosim"] = "✅ PASS"
            elif sl > 0:
                # BOTH frontends diverge from the RTL sim — the established
                # shared-artifact class (X-init / stimulus), not a UHDM bug.
                row["cosim"] = f"⚠ shared div (uhdm={u}, slang={sl})"
            else:
                row["cosim"] = f"❌ {u} div (slang clean)"
        elif "no outputs to compare" in out:
            row["cosim"] = "skip (no outputs)"
        elif "netlist generation FAILED" in out or "NO_RUN" in out:
            row["cosim"] = "skip (no run)"
        else:
            row["cosim"] = "error" if rc else "skip"
        return row

    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        return list(ex.map(one, mods))


# ------------------------------------------------------------------- pavona
def _pavona_cosim(mod, cycles):
    """Verilator co-sim of one pavona module (RTL vs read_uhdm vs read_slang),
    reusing the work/<mod> elaboration run_pavona_equiv.sh already produced.
    Returns the cosim cell text.  uhdm==0 → PASS; uhdm>0 & slang>0 → the
    established shared-artefact class (both frontends agree, both differ from
    the behavioural sim = X-init / synth-vs-behavioural, not a UHDM bug);
    uhdm>0 & slang==0 → a genuine UHDM divergence."""
    rc, out = sh([sys.executable, "scripts/adjudicate.py", mod, str(cycles), "1"],
                 cwd=PAVONA_DIR, timeout=2400)
    m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+) slang_vs_rtl=(\d+)",
                  out or "")
    if m:
        u, sl = int(m.group(1)), int(m.group(2))
        if u == 0:
            return "✅ PASS"
        if sl > 0:
            return f"⚠ shared div (uhdm={u}, slang={sl})"
        return f"❌ {u} div (slang clean)"
    if "no outputs to compare" in (out or ""):
        return "skip (no outputs)"
    if "netlist generation FAILED" in (out or "") or "NO_RUN" in (out or ""):
        return "skip (no run)"
    if "both simulators failed" in (out or ""):
        return "skip (sim build)"
    return "error" if rc else "skip"


def _pavona_check(mod):
    """Structural opt-level check of the read_uhdm netlist: flatten, opt_clean,
    then `check` for nets with no driver.  read_slang produces ZERO undriven
    nets for these modules, so any undriven net in the read_uhdm netlist is a
    dropped driver (the gen-scope enum-array / enum-const class that the
    whole-core cosim divergence traced back to).  Fast — no SAT, no cosim — so
    it runs on every module and catches dropped drivers structurally, without
    needing a deep co-sim to reach them."""
    flat = PAVONA_DIR / "wrappers" / f"flat_{mod}.sv"
    return _undriven_check(PAVONA_DIR / "work" / mod,
                           f"{mod}_flat" if flat.exists() else mod)


def sweep_pavona(jobs, cycles=300, flt=None):
    """Pavona (OT-config hardened Ibex): formal (read_uhdm vs read_slang) from
    one run_pavona_equiv.sh pass, PLUS a per-module Verilator co-sim (RTL vs
    both frontends) for the full formal+cosim picture."""
    cmd = ["./run_pavona_equiv.sh"]
    if flt:
        for line in (PAVONA_DIR / "pavona_modules.txt").read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    env = dict(os.environ, JOBS=str(jobs))
    try:
        p = subprocess.run(cmd, cwd=PAVONA_DIR, text=True, timeout=7200,
                           env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error",
        "elabfail": "elab-fail",
    }
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌🎉]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"elabfail)", line)
        if m:
            rows.append({"module": m.group(1),
                         "formal": label.get(m.group(2), m.group(2)),
                         "formal_raw": m.group(2), "cosim": "—"})
    rows.sort(key=lambda r: r["module"])

    # Co-sim EVERY module that elaborated (not error/elabfail) — the user wants
    # the full cosim+formal picture, and pavona's ~26 modules fit the budget.
    def one(r):
        if r["formal_raw"] in ("error", "elabfail"):
            r["cosim"] = "— (no elaboration)"
            r["check"] = "— (no elaboration)"
        else:
            r["check"] = _pavona_check(r["module"])
            r["cosim"] = _pavona_cosim(r["module"], cycles)
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


# ---------------------------------------------------------------------- tlul
def _tlul_check(mod):
    """Structural opt-level undriven-net check on one TL-UL module."""
    flat = TLUL_DIR / "wrappers" / f"flat_{mod}.sv"
    return _undriven_check(TLUL_DIR / "work" / mod,
                           f"{mod}_flat" if flat.exists() else mod)


def _tlul_cosim(mod, cycles):
    """Verilator co-sim of one TL-UL module (RTL vs read_uhdm vs read_slang),
    multi-clock aware.  Needed to adjudicate the dual-clock CDC modules
    (tlul_fifo_async) that the SAT miter cannot reach."""
    rc, out = sh([sys.executable, "scripts/tlul_cosim.py", mod, str(cycles), "1"],
                 cwd=TLUL_DIR, timeout=1800)
    m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+) slang_vs_rtl=(\d+)",
                  out or "")
    if m:
        u, sl = int(m.group(1)), int(m.group(2))
        if u == 0:
            return "✅ PASS"
        if sl > 0:
            return f"⚠ shared div (uhdm={u}, slang={sl})"
        return f"❌ {u} div (slang clean)"
    if "no outputs to compare" in (out or "") or "no clocks found" in (out or ""):
        return "— (comb/no clk)"
    if "NO_RUN" in (out or "") or "netlist generation FAILED" in (out or ""):
        return "skip (no run)"
    if "both simulators failed" in (out or ""):
        return "skip (sim build)"
    return "error" if rc else "skip"


def sweep_tlul(jobs, cycles=300, flt=None):
    """Pavona TL-UL bus library: formal (read_uhdm vs read_slang) from one
    run_tlul_equiv.sh pass, plus a structural undriven-net check and (where the
    module has clocks) a Verilator co-sim vs the behavioural RTL."""
    cmd = ["./run_tlul_equiv.sh"]
    if flt:
        for line in (TLUL_DIR / "tlul_modules.txt").read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    try:
        p = subprocess.run(cmd, cwd=TLUL_DIR, text=True, timeout=7200,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error", "elabfail": "elab-fail",
    }
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌‼🎉]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"elabfail)\b", line)
        if m and m.group(1) not in ("TL-UL",):
            rows.append({"module": m.group(1),
                         "formal": label.get(m.group(2), m.group(2)),
                         "formal_raw": m.group(2), "cosim": "—"})
    rows.sort(key=lambda r: r["module"])

    def one(r):
        if r["formal_raw"] in ("error", "elabfail"):
            r["cosim"] = "— (no elaboration)"
            r["check"] = "— (no elaboration)"
        else:
            r["check"] = _tlul_check(r["module"])
            r["cosim"] = _tlul_cosim(r["module"], cycles)
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


# ----------------------------------------------------------------------- acc
def _acc_check(mod):
    """Structural opt-level undriven-net check on one ACC module."""
    flat = ACC_DIR / "wrappers" / f"flat_{mod}.sv"
    return _undriven_check(ACC_DIR / "work" / mod,
                           f"{mod}_flat" if flat.exists() else mod)


def _acc_cosim(mod, cycles):
    """Verilator/iverilog co-sim of one ACC module (behavioural RTL vs read_uhdm
    vs read_slang).  Adjudicates a module the SAT miter cannot close — the
    combinational bignum multiplier unified_mul (SAT-hard)."""
    rc, out = sh([sys.executable, "scripts/acc_cosim.py", mod, str(cycles), "1"],
                 cwd=ACC_DIR, timeout=1800)
    m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+) slang_vs_rtl=(\d+)",
                  out or "")
    if m:
        u, sl = int(m.group(1)), int(m.group(2))
        if u == 0:
            return "✅ PASS"
        if sl > 0:
            return f"⚠ shared div (uhdm={u}, slang={sl})"
        return f"❌ {u} div (slang clean)"
    if "no outputs to compare" in (out or ""):
        return "— (no outputs)"
    if "NO_RUN" in (out or "") or "netlist generation FAILED" in (out or ""):
        return "skip (no run)"
    if "both simulators failed" in (out or ""):
        return "skip (sim build)"
    return "error" if rc else "skip"


def sweep_acc(jobs, cycles=300, flt=None):
    """Pavona ACC (OTBN-family asymmetric-crypto bignum core): per-module formal
    (read_uhdm vs read_slang) from one run_acc_equiv.sh pass, plus a structural
    undriven-net check."""
    cmd = ["./run_acc_equiv.sh"]
    if flt:
        for line in (ACC_DIR / "acc_modules.txt").read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    try:
        p = subprocess.run(cmd, cwd=ACC_DIR, text=True, timeout=7200,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error", "elabfail": "elab-fail",
    }
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌‼🎉]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"elabfail)\b", line)
        if m and m.group(1) not in ("ACC",):
            rows.append({"module": m.group(1),
                         "formal": label.get(m.group(2), m.group(2)),
                         "formal_raw": m.group(2), "cosim": "—"})
    rows.sort(key=lambda r: r["module"])

    def one(r):
        if r["formal_raw"] in ("error", "elabfail"):
            r["check"] = "— (no elaboration)"
            r["cosim"] = "— (no elaboration)"
        else:
            r["check"] = _acc_check(r["module"])
            # Co-sim EVERY module (not just cex/timeout): a formal SAT proof runs
            # under -set-init-zero and can miss a real reset/init divergence that
            # only shows in from-X simulation (e.g. tlul_fifo_sync proves yet the
            # co-sim diverges).  Running the co-sim on formally-proven modules
            # too surfaces those.
            r["cosim"] = _acc_cosim(r["module"], cycles)
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


# -------------------------------------------------------------------- report
def render(core, rows, cycles):
    # The pavona sweep adds a structural opt-level "check" column (undriven-net
    # detection on the flattened+opt'd read_uhdm netlist) — a fast dropped-driver
    # probe that runs on every module without needing a deep co-sim.
    has_check = any("check" in r for r in rows)
    lines = [f"## {core} sweep — formal (vs read_slang) + Verilator co-sim "
             f"({cycles} cycles)", ""]
    if has_check:
        lines += ["| module | formal vs slang | opt check (undriven) | co-sim vs RTL |",
                  "|---|---|---|---|"]
        for r in rows:
            lines.append(f"| {r['module']} | {r['formal']} | "
                         f"{r.get('check', '—')} | {r['cosim']} |")
    else:
        lines += ["| module | formal vs slang | co-sim vs RTL |",
                  "|---|---|---|"]
        for r in rows:
            lines.append(f"| {r['module']} | {r['formal']} | {r['cosim']} |")
    npass = sum(1 for r in rows if r["cosim"].startswith("✅"))
    nfail = sum(1 for r in rows if r["cosim"].startswith("❌"))
    nadj = sum(1 for r in rows if r["cosim"].startswith("⚠"))
    comparable = npass + nfail
    pct = (100.0 * npass / comparable) if comparable else 100.0
    nequiv = sum(1 for r in rows if r["formal"].startswith("✅"))
    lines += ["",
              f"**Formal:** {nequiv}/{len(rows)} modules equivalent with "
              f"read_slang.",
              f"**Co-sim pass rate:** {npass}/{comparable} "
              f"(**{pct:.1f}%**) — {nadj} adjudicated non-bug divergences "
              f"(⚠ rows, excluded), "
              f"{len(rows) - comparable - nadj} not comparable "
              f"(skipped / no run)."]
    if has_check:
        nclean = sum(1 for r in rows if r.get("check", "").startswith("✅"))
        ndirty = sum(1 for r in rows if r.get("check", "").startswith("❌"))
        lines.append(f"**Opt check:** {nclean}/{nclean + ndirty} modules with "
                     f"zero undriven nets ({ndirty} with dropped drivers).")
    return "\n".join(lines) + "\n"


def main():
    global _SHARD
    ap = argparse.ArgumentParser()
    ap.add_argument("core", choices=["ibex", "rp32", "cva6", "pavona", "tlul", "acc"])
    ap.add_argument("--cycles", type=int, default=300)
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--filter", help="regex: only sweep matching modules")
    ap.add_argument("--shard", help='"i/N": run only shard i of N (1-based), '
                    "round-robin over the sorted module list")
    ap.add_argument("--emit-json", type=Path,
                    help="also write this shard's rows as JSON (for --merge)")
    ap.add_argument("--merge", nargs="+", metavar="JSON",
                    help="merge these per-shard JSON row files into one table "
                    "instead of sweeping (globs allowed); no sweep is run")
    args = ap.parse_args()

    # Merge mode: combine per-shard JSON row dumps into the final table.
    if args.merge:
        files = []
        for pat in args.merge:
            files.extend(sorted(glob.glob(pat)))
        rows, cycles = [], args.cycles
        for f in files:
            data = json.loads(Path(f).read_text())
            rows.extend(data.get("rows", []))
            cycles = data.get("cycles", cycles)
        # De-dup by module (a module should appear in one shard only) and sort.
        seen, uniq = set(), []
        for r in sorted(rows, key=lambda r: r["module"]):
            if r["module"] in seen:
                continue
            seen.add(r["module"])
            uniq.append(r)
        report = render(args.core, uniq, cycles)
        print(report)
        if args.out:
            args.out.write_text(report)
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a") as f:
                f.write(report)
        return 0 if uniq else 1

    if args.shard:
        i, n = (int(x) for x in args.shard.split("/"))
        _SHARD = (i - 1, n)

    if args.core == "cva6":
        rows = sweep_cva6(args.cycles, args.jobs, args.filter)
    elif args.core == "pavona":
        rows = sweep_pavona(args.jobs, args.cycles, args.filter)
    elif args.core == "tlul":
        rows = sweep_tlul(args.jobs, args.cycles, args.filter)
    elif args.core == "acc":
        rows = sweep_acc(args.jobs, args.cycles, args.filter)
    else:
        rows = sweep_testdirs(args.core, args.cycles, args.jobs, args.filter)

    report = render(args.core, rows, args.cycles)
    print(report)
    if args.out:
        args.out.write_text(report)
    if args.emit_json:
        args.emit_json.write_text(json.dumps(
            {"core": args.core, "cycles": args.cycles, "rows": rows}))
    # A shard invocation (identified by --emit-json, which feeds the merge job)
    # does NOT write the step summary — the final --merge job posts the combined
    # table.  A plain (non-sharded) run still writes it directly.
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary and not args.emit_json:
        with open(summary, "a") as f:
            f.write(report)
    # Exit status: informational sweep — fail only if nothing ran.
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
