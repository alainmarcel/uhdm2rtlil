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
import shlex
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


def _chip_shard_plan(names):
    """Chip families (egret / dragonfly / caliptra) fan out differently from
    the per-module sweeps: with N > 1 shards the LAST shard runs only the
    full-chip co-sim (three whole-chip Verilator builds) and the instance
    miters + per-instance co-sims are split round-robin over the other N-1.
    Every shard still elaborates the chip (it needs the netlists).  Returns
    (this shard's instance names, run the chip co-sim?).  One shard = all.
    A single 16 GB runner died mid-sweep once the vault miters became real
    proofs (two multi-million-variable SATs) with the chip co-sim still ahead."""
    idx, cnt = _SHARD
    if cnt <= 1:
        return list(names), True
    if idx == cnt - 1:
        return [], True
    return sorted(names)[idx::cnt - 1], False

TEST_DIR = Path(__file__).resolve().parent
# Flattened read_uhdm cell counts, populated by _undriven_check and read by the
# auto-miter size gate (keyed by resolved work-dir path).
_CELLS: dict = {}
# Driver-CONFLICT counts from the same `check` run (keyed the same way).  A
# conflict means two drivers on one net, or -- the case that motivated this
# column -- an assignment whose TARGET is a constant or an input port, which
# `check` reports as "Drivers conflicting with a constant" plus
# `action <const> <= <sig>`.  Such a netlist is not merely wrong: the bogus
# feedback CONSTRAINS a SAT miter to the inputs where gold and gate agree, so
# the miter passes VACUOUSLY.  Never read the formal column without this one.
_CONFLICTS: dict = {}
CVA6_DIR = TEST_DIR / "cva6_equiv"
PAVONA_DIR = TEST_DIR / "pavona_equiv"
# Upstream lowRISC OpenTitan.  DELIBERATELY SEPARATE from PAVONA_DIR: pavona is
# a hard FORK whose RTL has diverged (of the 120 files the trees share across
# aes/kmac/hmac/csrng/edn/keymgr/entropy_src/lc_ctrl only 66 are byte-identical;
# kmac_app.sv differs by 1531 lines), so a pavona verdict is not an upstream
# verdict.  Own vendored sources, own manifest, own sweep.
OPENTITAN_DIR = TEST_DIR / "opentitan_equiv"
TLUL_DIR = TEST_DIR / "pavona_tlul_equiv"
ACC_DIR = TEST_DIR / "pavona_acc_equiv"
KMAC_DIR = TEST_DIR / "pavona_kmac_equiv"
HMAC_DIR = TEST_DIR / "pavona_hmac_equiv"
EDN_DIR = TEST_DIR / "pavona_edn_equiv"
CSRNG_DIR = TEST_DIR / "pavona_csrng_equiv"
AES_DIR = TEST_DIR / "pavona_aes_equiv"
ENTROPY_SRC_DIR = TEST_DIR / "pavona_entropy_src_equiv"
KEYMGR_DIR = TEST_DIR / "pavona_keymgr_equiv"
PERIPH_DIR = TEST_DIR / "pavona_periph_equiv"
PERIPH2_DIR = TEST_DIR / "pavona_periph2_equiv"
PERIPH3_DIR = TEST_DIR / "pavona_periph3_equiv"
PERIPH4_DIR = TEST_DIR / "pavona_periph4_equiv"
PERIPH5_DIR = TEST_DIR / "pavona_periph5_equiv"
CHIPS_DIR = TEST_DIR / "pavona_chips"
CALIPTRA_DIR = TEST_DIR / "caliptra_chip"


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
    # `proc` BEFORE `flatten`: flattening a design that still holds processes
    # keeps every process temp as a wire of the full signal width, which on the
    # masked KMAC modules explodes (kmac_reduced: 12.7M wire bits, 25.6 GB peak
    # — enough to get the 16 GB nightly runner killed; 2.1 GB with proc first).
    # It also removes FALSE undriven reports: a wire driven only inside a
    # process has no driver until proc converts it (kmac / kmac_app each showed
    # 1 such phantom).  A genuinely undriven net is still reported.
    (work_dir / "check_undriven.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\n"
        f"hierarchy -check -top {top}\n"
        f"proc\n"
        f"flatten; opt_clean\n"
        f"stat\n"
        f"check\n")
    # Belt and braces on a 16 GB CI runner: cap the address space so a blowup
    # fails this row instead of taking the whole job down with it.
    mem = os.environ.get("MEM_LIMIT_KB")
    cmd = [str(yosys), "-q", "-m", str(plugin), "check_undriven.ys"]
    if mem:
        cmd = ["bash", "-c", f"ulimit -Sv {mem}; exec " +
               " ".join(shlex.quote(c) for c in cmd)]
    rc, out = sh(cmd, cwd=work_dir, timeout=1800)
    out = out or ""
    # Cache the flattened cell count (from `stat`) so the auto-miter gate can
    # skip SoC-scale designs without a second flatten.
    mcell = re.search(r"Number of cells:\s*(\d+)", out)
    if mcell:
        _CELLS[str(Path(work_dir).resolve())] = int(mcell.group(1))
    # Driver conflicts from the same run (see _CONFLICTS).  Counted per
    # reported signal, plus every `action <const> <= …` line, which is a write
    # whose target is a literal -- the write goes nowhere.
    _CONFLICTS[str(Path(work_dir).resolve())] = (
        len(re.findall(r"conflicting drivers for", out)) +
        len(re.findall(r"Drivers conflicting with", out)) +
        len(re.findall(r"^\s+action \d+'[01xz]+ <= ", out, re.M)))
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


def _il_check(il, top):
    """Structural check of an ALREADY-WRITTEN netlist (`work/inst/<n>_uhdm.il`),
    for the chip families whose rows come from the miter log rather than a
    per-module elaboration.  Returns (undriven cell, conflicts cell); costs one
    read_rtlil + proc + flatten + opt_clean, no Surelog re-run."""
    il = Path(il)
    if not il.exists():
        return "— (no netlist)", "—"
    yosys = TEST_DIR / ".." / "out" / "current" / "bin" / "yosys"
    plugin = TEST_DIR / ".." / "build" / "uhdm2rtlil.so"
    ys = il.parent / f"chk_{il.stem}.ys"
    ys.write_text(f"read_rtlil {il.name}\n"
                  f"hierarchy -top {top}\n"
                  f"proc\nflatten; opt_clean\n"
                  f"delete t:$check t:$assert t:$assume t:$print t:$scopeinfo\n"
                  f"opt_clean\ncheck\n")
    rc, out = sh([str(yosys), "-q", "-m", str(plugin), ys.name],
                 cwd=il.parent, timeout=1800)
    out = out or ""
    if rc and "found and reported" not in out.lower():
        return "error", "—"
    undriven = len(re.findall(r"used but has no driver", out))
    conf = (len(re.findall(r"conflicting drivers for", out)) +
            len(re.findall(r"Drivers conflicting with", out)) +
            len(re.findall(r"^\s+action \d+'[01xz]+ <= ", out, re.M)))
    ucell = f"❌ {undriven} undriven" if undriven else "✅ 0 undriven"
    ccell = f"❌ {conf} conflict{'s' if conf != 1 else ''}" if conf else "✅ 0"
    return ucell, ccell


def _conflict_cell(work_dir):
    """Render the driver-conflict count gathered by _undriven_check."""
    n = _CONFLICTS.get(str(Path(work_dir).resolve()))
    if n is None:
        return "—"
    return "✅ 0" if n == 0 else f"❌ {n} conflict{'s' if n != 1 else ''}"


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
               "check": "—", "conflicts": "—"}
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
        row["conflicts"] = _conflict_cell(d)
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
        # Slang correctness baseline: the same co-sim with the read_slang
        # netlist on the netlist side.
        rc2, out2 = sh([sys.executable, "test_sim_equivalence.py", name,
                        "--cycles", str(cycles), "--frontend", "slang"],
                       cwd=TEST_DIR, timeout=2400)
        m2 = re.search(r"FAIL: \d+ cycles, (\d+) mismatches", out2)
        if re.search(r"PASS: \d+ cycles, 0 mismatches", out2):
            row["slang_cosim"] = "✅ PASS"
        elif m2:
            row["slang_cosim"] = f"❌ {m2.group(1)} div"
        elif "vacuous" in out2:
            row["slang_cosim"] = "vacuous"
        else:
            row["slang_cosim"] = "skip" if (rc2 == 77 or "SKIPPED" in out2) else "error"
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
               "cosim": "—", "check": "—", "conflicts": "—"}
        st = formal[mod]
        work = CVA6_DIR / "work" / mod
        # A module that elaborated (proven / cex / SAT-timeout) has a read_uhdm
        # netlist; error / crash / elabfail / dead / skipped do not.
        elaborated = st in ("proven", "cex", "timeout")
        # Structural undriven-net probe on every elaborated module.
        row["check"] = (_undriven_check(work, f"{mod}_equiv")
                        if elaborated else "— (no elaboration)")
        row["conflicts"] = _conflict_cell(work) if elaborated else "—"
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
        row["slang_cosim"] = _slang_cell(out)
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
# ---------------------------------------------------------------- slang co-sim
# The 3-way co-sims (behavioural RTL vs read_uhdm vs read_slang netlists) also
# tell how the read_slang netlist tracks the RTL: that is the CORRECTNESS
# BASELINE of the reference frontend the formal column compares against.  It is
# reported as the left-most column of every sweep table.
_SLANG_COSIM = {}   # module -> cell text, filled by the co-sim helpers


def _slang_cell(out):
    m = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+) slang_vs_rtl=(\d+)",
                  out or "")
    if m:
        sl = int(m.group(2))
        return "✅ PASS" if sl == 0 else f"❌ {sl} div"
    if "no outputs to compare" in (out or "") or "no clocks found" in (out or ""):
        return "— (comb/no clk)"
    if "NO_RUN" in (out or "") or "netlist generation FAILED" in (out or ""):
        return "skip (no run)"
    if "both simulators failed" in (out or ""):
        return "skip (sim build)"
    return "skip"


def _record_slang(mod, out):
    _SLANG_COSIM[mod] = _slang_cell(out)


def _pavona_cosim(mod, cycles):
    """Verilator co-sim of one pavona module (RTL vs read_uhdm vs read_slang),
    reusing the work/<mod> elaboration run_pavona_equiv.sh already produced.
    Returns the cosim cell text.  uhdm==0 → PASS; uhdm>0 & slang>0 → the
    established shared-artefact class (both frontends agree, both differ from
    the behavioural sim = X-init / synth-vs-behavioural, not a UHDM bug);
    uhdm>0 & slang==0 → a genuine UHDM divergence."""
    rc, out = sh([sys.executable, "scripts/adjudicate.py", mod, str(cycles), "1"],
                 cwd=PAVONA_DIR, timeout=2400)
    _record_slang(mod, out)
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
            r["conflicts"] = _conflict_cell(PAVONA_DIR / "work" / r["module"])
            r["cosim"] = _pavona_cosim(r["module"], cycles)
            r["slang_cosim"] = _SLANG_COSIM.get(r["module"], "—")
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


# ----------------------------------------------------------------- opentitan
def _opentitan_cosim(mod, cycles):
    """Verilator co-sim of one upstream OpenTitan module (RTL vs read_uhdm vs
    read_slang), reusing the work/<mod> elaboration the runner produced.
    Same three-way adjudication as the pavona family, but its own harness --
    the two families share no sources and no scripts."""
    rc, out = sh([sys.executable, "scripts/adjudicate.py", mod, str(cycles), "1"],
                 cwd=OPENTITAN_DIR, timeout=2400)
    _record_slang(mod, out)
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


def _opentitan_check(mod):
    """Structural opt-level undriven-net check on one upstream OpenTitan
    module, reusing the work/<mod> elaboration the runner produced."""
    return _undriven_check(OPENTITAN_DIR / "work" / mod, mod)


def sweep_opentitan(jobs, cycles=300, flt=None):
    """Upstream lowRISC OpenTitan (pinned in opentitan_equiv/opentitan.commit):
    per-module read_uhdm vs read_slang SAT miter from one
    run_opentitan_equiv.sh pass, plus the structural columns."""
    cmd = ["./run_opentitan_equiv.sh"]
    if flt:
        for line in (OPENTITAN_DIR / "opentitan_modules.txt").read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    env = dict(os.environ, JOBS=str(jobs))
    try:
        p = subprocess.run(cmd, cwd=OPENTITAN_DIR, text=True, timeout=10800,
                           env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    print(out)
    label = {
        "proven": "✅ equivalent", "cex": "❌ differs",
        "timeout": "❓ SAT timeout", "error": "error",
        "elabfail": "elab-fail",
    }
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s*[✅⚠❓💥❌🎉⏭]*\s*(\S+)\s+(proven|cex|timeout|error|"
                     r"elabfail)", line)
        if m:
            rows.append({"module": m.group(1),
                         "formal": label.get(m.group(2), m.group(2)),
                         "formal_raw": m.group(2), "cosim": "—"})
    rows.sort(key=lambda r: r["module"])

    def one(r):
        if r["formal_raw"] in ("error", "elabfail"):
            r["check"] = "— (no elaboration)"
            r["conflicts"] = "—"
            r["cosim"] = "— (no elaboration)"
        else:
            r["check"] = _opentitan_check(r["module"])
            r["conflicts"] = _conflict_cell(OPENTITAN_DIR / "work" / r["module"])
            r["cosim"] = _opentitan_cosim(r["module"], cycles)
            r["slang_cosim"] = _SLANG_COSIM.get(r["module"], "—")
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
    _record_slang(mod, out)
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
            r["conflicts"] = _conflict_cell(TLUL_DIR / "work" / r["module"])
            r["cosim"] = _tlul_cosim(r["module"], cycles)
            r["slang_cosim"] = _SLANG_COSIM.get(r["module"], "—")
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
    _record_slang(mod, out)
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
            r["conflicts"] = _conflict_cell(ACC_DIR / "work" / r["module"])
            # Co-sim EVERY module (not just cex/timeout): a formal SAT proof runs
            # under -set-init-zero and can miss a real reset/init divergence that
            # only shows in from-X simulation (e.g. tlul_fifo_sync proves yet the
            # co-sim diverges).  Running the co-sim on formally-proven modules
            # too surfaces those.
            r["cosim"] = _acc_cosim(r["module"], cycles)
            r["slang_cosim"] = _SLANG_COSIM.get(r["module"], "—")
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


# ---------------------------------------------------------------------- kmac
# The KMAC, HMAC, EDN and CSRNG campaigns share one layout (test/pavona_<ip>_equiv:
# run_<ip>_equiv.sh, <ip>_modules.txt, scripts/<ip>_cosim.py, wrappers/
# flat_<mod>.sv), so the helpers below take the ip name and its directory.
_IP_DIRS = {"kmac": KMAC_DIR, "hmac": HMAC_DIR, "edn": EDN_DIR, "csrng": CSRNG_DIR,
            "aes": AES_DIR, "entropy_src": ENTROPY_SRC_DIR,
            "keymgr": KEYMGR_DIR, "periph": PERIPH_DIR, "periph2": PERIPH2_DIR, "periph3": PERIPH3_DIR, "periph4": PERIPH4_DIR, "periph5": PERIPH5_DIR}


def _kmac_check(mod, ip="kmac"):
    """Structural opt-level undriven-net check on one KMAC/HMAC module."""
    d = _IP_DIRS[ip]
    flat = d / "wrappers" / f"flat_{mod}.sv"
    return _undriven_check(d / "work" / mod,
                           f"{mod}_flat" if flat.exists() else mod)


def _kmac_cosim(mod, cycles, ip="kmac"):
    """Verilator co-sim of one KMAC/HMAC module (behavioural RTL vs read_uhdm
    vs read_slang).  Adjudicates the modules the SAT miter cannot close — the
    1600-bit Keccak-f permutation keccak_round (SAT-hard, like acc's
    unified_mul) and any msgfifo residual the bounded miter misses — and, since
    the seq=4 miter never completes a hash, the deep-state bugs only a
    simulation reaches (hmac_core's 64-bit size-cast message lengths)."""
    rc, out = sh([sys.executable, f"scripts/{ip}_cosim.py", mod, str(cycles), "1"],
                 cwd=_IP_DIRS[ip], timeout=1800)
    _record_slang(mod, out)
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


def sweep_kmac(jobs, cycles=300, flt=None, ip="kmac"):
    """Pavona KMAC (OpenTitan Keccak-MAC / SHA3 core) or HMAC (HMAC-SHA2
    core): per-module formal (read_uhdm vs read_slang) from one
    run_<ip>_equiv.sh pass, plus a structural undriven-net check and a
    Verilator co-sim vs the behavioural RTL (adjudicates the SAT-hard Keccak
    permutation / prim_packer the bounded miter times out on)."""
    d = _IP_DIRS[ip]
    cmd = [f"./run_{ip}_equiv.sh"]
    if flt:
        for line in (d / f"{ip}_modules.txt").read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split()[0]
                if re.search(flt, name):
                    cmd.append(name)
    try:
        p = subprocess.run(cmd, cwd=d, text=True, timeout=7200,
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
        # Skip the "KMAC equivalence: …" summary line (its first token is KMAC).
        if m and m.group(1) not in ("KMAC", "HMAC", "EDN", "CSRNG", "AES", "ENTROPY_SRC", "KEYMGR", "PERIPH", "PERIPH2", "PERIPH3", "PERIPH4", "PERIPH5"):
            rows.append({"module": m.group(1),
                         "formal": label.get(m.group(2), m.group(2)),
                         "formal_raw": m.group(2), "cosim": "—"})
    rows.sort(key=lambda r: r["module"])

    def one(r):
        if r["formal_raw"] in ("error", "elabfail"):
            r["check"] = "— (no elaboration)"
            r["cosim"] = "— (no elaboration)"
        else:
            r["check"] = _kmac_check(r["module"], ip)
            r["conflicts"] = _conflict_cell(_IP_DIRS[ip] / "work" / r["module"])
            # Co-sim EVERY elaborated module (not just cex/timeout): a from-X sim
            # can catch a reset/init divergence the -set-init-zero SAT proof
            # misses, and it adjudicates the SAT-hard keccak_round.
            r["cosim"] = _kmac_cosim(r["module"], cycles, ip)
            r["slang_cosim"] = _SLANG_COSIM.get(r["module"], "—")
        return r
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        rows = list(ex.map(one, rows))
    for r in rows:
        r.pop("formal_raw", None)
    return rows


def _fetch_pavona():
    """Pavona checkout for the full-chip families: $PAVONA if set, else a
    sparse clone of hw/ at the pinned commit (pavona_chips/pavona.commit)."""
    if os.environ.get("PAVONA"):
        return os.environ["PAVONA"]
    dest = CHIPS_DIR / "pavona"
    commit = (CHIPS_DIR / "pavona.commit").read_text().strip()
    if not (dest / "hw").exists():
        sh(["bash", str(CHIPS_DIR / "scripts" / "fetch_pavona.sh"), str(dest), commit],
           timeout=1800)
    return str(dest)



# ------------------------------------------------------- per-instance co-sim
# Pavona's chip-level tie-offs (test/scan controls off, AST ready, power good);
# the same pin names recur on the instances, so they get the same values.
_PAVONA_TIES = {
    "scan_rst_ni": "1'b1", "scan_en_i": "1'b0", "scanmode_i": "4'h9",
    "ast_init_done_i": "4'h6", "calib_rdy_i": "4'h6",
    "flash_bist_enable_i": "4'h9", "io_clk_byp_ack_i": "4'h9",
    "all_clk_byp_ack_i": "4'h9", "div_step_down_req_i": "4'h9",
    "pwrmgr_ast_rsp_i": "'1", "dft_hold_tap_sel_i": "1'b0",
    "ram_1p_cfg_i": "'0", "sram_ctrl_main_cfg_i": "'0", "sram_ctrl_ret_aon_cfg_i": "'0",
    "sram_ctrl_mbox_cfg_i": "'0", "spi_ram_2p_cfg_i": "'0", "usb_ram_1p_cfg_i": "'0",
    "rom_cfg_i": "'0", "rom_ctrl0_cfg_i": "'0", "rom_ctrl1_cfg_i": "'0",
    "sensor_ctrl_ast_alert_req_i": "'0", "flash_power_down_h_i": "1'b0",
    "flash_power_ready_h_i": "1'b1", "otp_macro_pwr_seq_h_i": "'0",
}
_CALIPTRA_TIES = {"scan_mode": "1'b0", "cptra_in_debug_scan_mode": "1'b0"}


def _paramod(typ):
    """RTLIL instance type -> (rtl module, ["P=32'hXX", ...], ok).
    "$paramod\\mod\\P=s32'bits\\Q=\"str\"" carries the instance's parameters;
    a type parameter ($typaram) or an unrecognised value form cannot be passed
    to Verilator's -G, so ok=False and the row is skipped honestly."""
    if not typ.startswith("$paramod\\"):
        return typ.lstrip("\\"), [], True
    parts = typ[len("$paramod\\"):].split("\\")
    mod, params = parts[0], []
    for kv in parts[1:]:
        if "=" not in kv:
            continue
        k, v = kv.split("=", 1)
        if "$typaram" in v:
            return mod, params, False
        m = re.match(r"^s?(\d*)'([01]+)$", v)
        if m:
            bits = m.group(2)
            w = int(m.group(1) or len(bits))
            params.append(f"{k}={w}'h{int(bits, 2):x}")
        elif v.startswith('"') and v.endswith('"'):
            params.append(f"{k}={v}")
        else:
            return mod, params, False
    return mod, params, True


def _cosim_cells(out, rc, cycles):
    """netlist_cosim.py / chip_cosim.py output -> (uhdm cell, slang cell)."""
    out = out or ""
    m = re.search(r"ADJUDICATION (\d+) cycles: uhdm_vs_rtl=(\d+)(?: slang_vs_rtl=(-?\d+))?", out)
    act = re.search(r"ACTIVITY (\d+)", out)
    if m:
        u = int(m.group(2))
        s = int(m.group(3)) if m.group(3) is not None else -1
        if u == 0:
            cell = f"✅ PASS ({m.group(1)} cycles, {act.group(1) if act else '?'} active)"
        elif s > 0:
            # Both netlists diverge from the RTL the same way: a netlist-sim
            # artefact (X-init, memory model), not a read_uhdm defect.
            cell = f"⚠ shared div (uhdm={u}, slang={s})"
        else:
            cell = f"❌ {u} div"
        scell = "—" if s < 0 else ("✅ PASS" if s == 0 else f"❌ {s} div")
        return cell, scell
    if "NO_RUN" in out:
        why = re.search(r"NO_RUN \(([^)]*)\)", out)
        return f"skip ({why.group(1)[:40] if why else 'no run'})", "—"
    b = re.search(r"(rtl|uhdm|slang) Verilator build FAILED", out)
    if b:
        # A build failure on the UHDM (or slang) NETLIST is not a skip: Verilator
        # rejects a netlist that assigns to an input port, which is exactly what
        # a malformed lowering produces (`assign a[0] = a[3] ^ a[0];`).  Such a
        # row silently counted as "not comparable" while the netlist went
        # unexamined -- and the SAT miter passes vacuously on it.  Flag it.
        if b.group(1) in ("uhdm", "slang"):
            return f"❌ netlist unbuildable ({b.group(1)})", "—"
        return f"skip ({b.group(1)} sim build)", "—"
    if rc == 124 or "[timeout]" in out:
        return "❓ timeout", "—"
    return "error", "—"


def _iface_wrapper(inst_dir, name, rtl_top, params, srcs, var):
    """Flat-port wrapper for an instance with interface ports (see
    caliptra_chip/scripts/gen_inst_wrapper.py); None when the instance's
    netlist has no escaped `\\a.b` port."""
    il = inst_dir / f"{name}_uhdm.il"
    try:
        dotted = False
        with open(il, errors="replace") as fh:
            inmod = False
            for line in fh:
                if line.startswith("module "):
                    inmod = line.strip() == f"module \\{name}_uhdm"
                    continue
                if not inmod:
                    continue
                if line.startswith("end"):
                    break
                if re.match(r"\s+wire .*(input|output|inout) \d+ \\\S+\.\S+$", line.rstrip()):
                    dotted = True
                    break
    except OSError:
        return None
    if not dotted:
        return None
    gen = CALIPTRA_DIR / "scripts" / "gen_inst_wrapper.py"
    if not gen.exists():
        return None
    # the RTL file declaring the module, for the overridable-parameter filter
    rtl_src = None
    subst = dict(v.split("=", 1) for v in var if "=" in v)
    for l in Path(srcs).read_text().splitlines():
        l = l.strip()
        if not l or l.startswith("#"):
            continue
        for k, v in subst.items():
            l = l.replace("${" + k + "}", v)
        try:
            if re.search(r"^\s*module\s+" + re.escape(rtl_top) + r"\b", Path(l).read_text(errors="replace"), re.M):
                rtl_src = l
                break
        except OSError:
            continue
    out = inst_dir / name / "cosim" / f"{rtl_top}_flat.sv"
    cmd = [sys.executable, str(gen), str(il), f"{name}_uhdm", rtl_top, str(out)]
    for p in params:
        cmd += ["--param", p]
    if rtl_src:
        cmd += ["--rtl-src", rtl_src]
    rc, o = sh(cmd, timeout=300)
    print(f"# iface wrapper {name}: rc={rc} {(o or '').strip()[:200]}", flush=True)
    return out if rc == 0 and out.exists() else None


def _inst_cosim(inst_dir, name, typ, srcs, incs, var, extra, ties, cycles):
    """Co-sim one direct instance: its read_uhdm and read_slang netlists
    (chip_flow's split) vs the RTL module rebuilt with the instance's
    parameters.  Returns (uhdm cell, slang cell)."""
    rtl_top, params, ok = _paramod(typ)
    if not ok:
        return "skip (type param)", "—"
    work = inst_dir / name / "cosim"
    work.mkdir(parents=True, exist_ok=True)
    (work / "ties.json").write_text(json.dumps(ties))
    cmd = [sys.executable, str(TEST_DIR / "netlist_cosim.py"), "--work", str(work),
           "--uhdm-il", str(inst_dir / f"{name}_uhdm.il"),
           "--slang-il", str(inst_dir / f"{name}_slang.il"),
           "--top", f"{name}_uhdm",
           "--srcs", str(srcs), "--incs", str(incs), "--cycles", str(cycles),
           "--ties", str(work / "ties.json")]
    # An instance whose RTL module has INTERFACE ports (soc_ifc_top's four
    # axi_if modports, VeeR's el2_mem_if exports, ABR's memory export) has
    # them flattened to escaped `\<port>.<member>` netlist ports, which no
    # port-by-port testbench can drive.  Generate a flat-port wrapper around
    # the RTL module (the instance's parameters baked in, so no --param) and
    # co-simulate through it with the netlist ports renamed to match.
    wrapper = _iface_wrapper(inst_dir, name, rtl_top, params, srcs, var)
    if wrapper:
        cmd += ["--extra-src", str(wrapper), "--rtl-top", f"{rtl_top}_flat", "--iface-flat"]
    else:
        cmd += ["--rtl-top", rtl_top]
        for p in params:
            cmd += ["--param", p]
    for v in var:
        cmd += ["--var", v]
    for e in extra:
        cmd += ["--extra-src", str(e)]
    # Same address-space cap as the miters: a Verilator build that blows up
    # (rv_core_ibex-class instances on a 16 GB runner) then fails its own row
    # as "skip (sim build)" instead of taking the runner down mid-shard.
    mem = os.environ.get("MEM_LIMIT_KB")
    if mem:
        cmd = ["bash", "-c", f"ulimit -Sv {mem}; exec " +
               " ".join(shlex.quote(c) for c in cmd)]
    rc, out = sh(cmd, timeout=7200)
    (work / "cosim.log").write_text(out or "")
    return _cosim_cells(out, rc, cycles)


def _inst_cosims(rows, inst_dir, srcs, incs, var, extra, ties, cycles, jobs):
    """Fill the co-sim columns of every instance row, `jobs` at a time."""
    types = {}
    tf = inst_dir / "instances.json"
    if tf.exists():
        types = json.loads(tf.read_text())
    todo = [r for r in rows if r["module"] in types]
    # Sharded (CI) runs co-simulate one instance at a time: two concurrent
    # whole-chip-source Verilator builds killed the egret shard-1 runner
    # (memory) right after its miters had all proven.
    if _SHARD[1] > 1:
        jobs = 1
    with cf.ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
        futs = {ex.submit(_inst_cosim, inst_dir, r["module"], types[r["module"]],
                          srcs, incs, var, extra, ties, cycles): r for r in todo}
        for f in cf.as_completed(futs):
            r = futs[f]
            try:
                r["cosim"], r["slang_cosim"] = f.result()
            except Exception as e:      # never lose the formal column to a co-sim crash
                r["cosim"], r["slang_cosim"] = f"error ({type(e).__name__})", "—"
            print(f"  cosim {r['module']:32s} {r['cosim']}  slang: {r['slang_cosim']}", flush=True)
    for r in rows:
        if r["module"] not in types and "slang_cosim" not in r:
            r["slang_cosim"] = "—"

def sweep_chip(chip, jobs, cycles=300, flt=None):
    """Pavona full chip (top_egret / top_dragonfly): Surelog + read_uhdm +
    read_slang of the WHOLE top, a read_uhdm-vs-read_slang SAT miter per
    direct instance (one row each), and a full-chip Verilator co-sim of the
    read_uhdm netlist vs the behavioural RTL (the `top_<chip>` row)."""
    env = dict(os.environ, PAVONA=_fetch_pavona(), JOBS=str(max(1, jobs)))
    inst_dir = CHIPS_DIR / "work" / chip / "inst"
    # chip_flow.py applies the same shard plan itself (SHARD=i/n): it is the
    # one that knows the instance list, after its split().
    env["SHARD"] = f"{_SHARD[0] + 1}/{_SHARD[1]}"
    cmd = [sys.executable, "scripts/chip_flow.py", chip]
    try:
        p = subprocess.run(cmd, cwd=CHIPS_DIR, text=True, timeout=4 * 3600, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    print(out)
    label = {"proven": "✅ equivalent", "cex": "❌ differs",
             "timeout": "❓ SAT timeout", "memlimit": "❓ SAT over memory cap",
             "error": "error"}
    rows = []
    for line in out.splitlines():
        m = re.match(r"\s*[✅❌]\s*(u_\S+)\s+(proven|cex|timeout|memlimit|error)\b", line)
        if m and (not flt or re.search(flt, m.group(1))):
            rows.append({"module": m.group(1), "formal": label[m.group(2)],
                         "cosim": "—"})
    rows.sort(key=lambda r: r["module"])
    # Structural columns from the per-instance netlists the split already
    # wrote — cheap (no re-elaboration) and it is what tells you whether to
    # believe the `formal` column on this row.
    for r in rows:
        r["check"], r["conflicts"] = _il_check(
            inst_dir / f"{r['module']}_uhdm.il", f"{r['module']}_uhdm")
    all_names = []
    if (inst_dir / "instances.json").exists():
        all_names = sorted(json.loads((inst_dir / "instances.json").read_text()))
    my_names, do_chip_cosim = _chip_shard_plan(all_names)
    # Full-chip co-sim row (its own shard when sharded).
    cs, scs = "—", "—"
    if do_chip_cosim:
        try:
            rc = subprocess.run([sys.executable, "scripts/chip_cosim.py", chip, str(cycles), "1"],
                                cwd=CHIPS_DIR, text=True, timeout=4 * 3600, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            cout = rc.stdout
        except subprocess.TimeoutExpired as e:
            cout = e.stdout or "timeout"
        print(cout)
        # chip_cosim.py also simulates the read_slang netlist of the top: that is
        # the slang-baseline column (it used to be parsed for the verdict only).
        cs, scs = _cosim_cells(cout, 0, cycles)
    # Every direct instance: its read_uhdm / read_slang netlists vs the RTL
    # module rebuilt with the instance's parameters.
    if _SHARD[1] > 1:
        rows = [r for r in rows if r["module"] in set(my_names)]
    _inst_cosims(rows, CHIPS_DIR / "work" / chip / "inst",
                 CHIPS_DIR / chip / "srcs.txt", CHIPS_DIR / chip / "incs.txt",
                 [f"PAVONA={env['PAVONA']}"],
                 [Path(env["PAVONA"]) / "hw/ip/prim/rtl/prim_assert.sv"],
                 _PAVONA_TIES, cycles, jobs)
    nproven = sum(1 for r in rows if r["formal"].startswith("✅"))
    # The merge job adds the shards' top rows together (see --merge).
    rows.insert(0, {"module": f"top_{chip} (full chip)",
                    "formal": f"{nproven}/{len(rows)} instances equivalent",
                    "cosim": cs, "slang_cosim": scs})
    return rows



def _fetch_caliptra():
    """caliptra-rtl checkout: $CALIPTRA if set, else a shallow clone at the
    pinned commit (caliptra_chip/caliptra.commit)."""
    if os.environ.get("CALIPTRA"):
        return os.environ["CALIPTRA"]
    dest = CALIPTRA_DIR / "caliptra-rtl"
    if not (dest / "src").exists():
        # The script clones into $CALIPTRA, defaulting to exactly `dest`.
        rc, out = sh(["bash", str(CALIPTRA_DIR / "scripts" / "fetch_caliptra.sh")],
                     timeout=1800)
        print(f"# fetch_caliptra.sh: exit {rc}\n{out}", flush=True)
    return str(dest)


EXT_DIR = TEST_DIR / "ext_ip"


def _ext_families():
    """External-IP families: one JSON manifest each under test/ext_ip/."""
    return sorted(p.stem for p in EXT_DIR.glob("*.json"))


def _ext_root():
    """Where the external repositories live: $EXT_IP_ROOT, else ~/ext when it
    exists (developer machines), else test/ext_ip/repos (CI)."""
    if os.environ.get("EXT_IP_ROOT"):
        return Path(os.environ["EXT_IP_ROOT"])
    home = Path(os.path.expanduser("~/ext"))
    return home if home.is_dir() else EXT_DIR / "repos"


def _fetch_ext(family):
    """Shallow-clone every repository of the family's manifest at its pinned
    commit (skipped when the directory already exists)."""
    man = json.loads((EXT_DIR / f"{family}.json").read_text())
    root = _ext_root()
    root.mkdir(parents=True, exist_ok=True)
    for r in man.get("repos", []):
        dest = root / r["dir"]
        if dest.is_dir() and any(dest.iterdir()):
            continue
        dest.mkdir(parents=True, exist_ok=True)
        # Shallow-fetch the pinned FULL commit (GitHub refuses abbreviated
        # SHAs); if the server will not serve the object directly, fall back
        # to a shallow clone of the default branch and say which commit ran.
        ok = True
        cmds = [["git", "init", "-q"], ["git", "remote", "add", "origin", r["url"]],
                ["git", "fetch", "-q", "--depth", "1", "origin", r["commit"]],
                ["git", "checkout", "-q", "FETCH_HEAD"]]
        for c in cmds:
            rc, out = sh(c, cwd=dest, timeout=1800)
            if rc:
                print(f"# fetch {r['dir']}: {' '.join(c)} -> exit {rc}\n{out}", flush=True)
                ok = False
                break
        if not ok:
            sh(["rm", "-rf", str(dest)], timeout=300)
            rc, out = sh(["git", "clone", "-q", "--depth", "1", r["url"], str(dest)], timeout=1800)
            if rc:
                print(f"# clone {r['dir']} FAILED: {out}", flush=True)
                continue
        if r.get("submodules"):
            sh(["git", "submodule", "update", "-q", "--init", "--depth", "1"], cwd=dest, timeout=1800)
        rc, head = sh(["git", "rev-parse", "--short", "HEAD"], cwd=dest, timeout=60)
        print(f"# fetched {r['dir']} @ {(head or '').strip()} (pinned {r['commit'][:9]})", flush=True)
    return root


def sweep_ext(family, jobs, cycles=300, flt=None):
    """One external-IP family (test/ext_ip/<family>.json): per-module read_uhdm
    vs read_slang SAT miter, opt-check and Verilator co-sim through
    ext_ip/ext_flow.py; rows come back in the common schema.  Sharded runs
    take every N-th module of the manifest's list."""
    root = _fetch_ext(family)
    os.environ["EXT_IP_ROOT"] = str(root)   # ext_flow.py reads it
    flow = EXT_DIR / "ext_flow.py"
    mods = []
    if _SHARD[1] > 1:
        rc, out = sh([sys.executable, str(flow), family, "--list"] +
                     (["--filter", flt] if flt else []), timeout=600)
        names = [l.strip() for l in (out or "").splitlines() if l.strip() and not l.startswith("#")]
        mods = sorted(names)[_SHARD[0]::_SHARD[1]]
        if not mods:
            return []
    work = EXT_DIR / "work" / family
    work.mkdir(parents=True, exist_ok=True)
    out_json = work / (f"rows_shard{_SHARD[0] + 1}.json" if _SHARD[1] > 1 else "rows.json")
    cmd = [sys.executable, str(flow), family, "--jobs", str(max(1, jobs)),
           "--cycles", str(cycles), "--out", str(out_json)] + mods
    if flt and not mods:
        cmd += ["--filter", flt]
    rc, out = sh(cmd, timeout=6 * 3600)
    print(out or "", flush=True)
    rows = json.loads(out_json.read_text()) if out_json.exists() else []
    for r in rows:
        r.pop("formal_raw", None)
        r.pop("want", None)
        if r.get("note"):
            r["formal"] = f"{r['formal']} ({r.pop('note')})" if r["formal"] in ("elab-fail", "read-fail (uhdm)", "no reference (read_slang fails)", "error") else r["formal"]
            r.pop("note", None)
    return rows


def sweep_caliptra(jobs, cycles=300, flt=None):
    """chipsalliance/caliptra-rtl full chip: Surelog + read_uhdm + read_slang
    of caliptra_top (through the generated flat-port wrapper, since read_slang
    refuses a top with unconnected interface ports), then a read_uhdm-vs-
    read_slang SAT miter per direct instance of the chip -- one row each --
    plus Verilator co-sim of the flat wrapper (read_uhdm and read_slang
    netlists vs the RTL) and of every instance's netlists vs the RTL module
    rebuilt with the instance's parameters (netlist_cosim.py)."""
    env = dict(os.environ, CALIPTRA=_fetch_caliptra(), JOBS=str(max(1, jobs)))
    inst_dir = CALIPTRA_DIR / "work" / "inst"
    env["SHARD"] = f"{_SHARD[0] + 1}/{_SHARD[1]}"
    cmd = [sys.executable, "scripts/chip_flow.py"]
    try:
        p = subprocess.run(cmd, cwd=CALIPTRA_DIR, text=True, timeout=4 * 3600,
                           env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT)
        out = p.stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
    print(out)
    label = {"proven": "✅ equivalent", "cex": "❌ differs",
             "timeout": "❓ SAT timeout", "memlimit": "❓ SAT over memory cap",
             "error": "error"}
    rows = []
    # Caliptra instance names are not u_-prefixed (abr_inst, rvtop, sha256 ...).
    for line in out.splitlines():
        m = re.match(r"\s*[✅❌]\s*(\S+)\s+(proven|cex|timeout|memlimit|error)\b", line)
        if m and (not flt or re.search(flt, m.group(1))):
            rows.append({"module": m.group(1), "formal": label[m.group(2)],
                         "cosim": "—"})
    rows.sort(key=lambda r: r["module"])
    # Structural columns from the per-instance netlists the split already
    # wrote — cheap (no re-elaboration) and it is what tells you whether to
    # believe the `formal` column on this row.
    for r in rows:
        r["check"], r["conflicts"] = _il_check(
            inst_dir / f"{r['module']}_uhdm.il", f"{r['module']}_uhdm")
    all_names = []
    if (inst_dir / "instances.json").exists():
        all_names = sorted(json.loads((inst_dir / "instances.json").read_text()))
    my_names, do_chip_cosim = _chip_shard_plan(all_names)
    if _SHARD[1] > 1:
        rows = [r for r in rows if r["module"] in set(my_names)]
    work = CALIPTRA_DIR / "work"
    cs, scs = "—", "—"
    if do_chip_cosim and cycles > 0 and (work / "caliptra_uhdm_hier.il").exists():
        cw = work / "cosim"
        cw.mkdir(parents=True, exist_ok=True)
        (cw / "ties.json").write_text(json.dumps(_CALIPTRA_TIES))
        cmd = [sys.executable, str(TEST_DIR / "netlist_cosim.py"), "--work", str(cw),
               "--uhdm-il", str(work / "caliptra_uhdm_hier.il"),
               "--slang-il", str(work / "caliptra_slang_keephier.il"),
               "--top", "caliptra_top_flat", "--rtl-top", "caliptra_top_flat",
               "--srcs", str(CALIPTRA_DIR / "srcs.txt"), "--incs", str(CALIPTRA_DIR / "incs.txt"),
               "--var", f"CALIPTRA={env['CALIPTRA']}",
               "--extra-src", str(work / "caliptra_top_flat.sv"),
               "--cycles", str(cycles), "--ties", str(cw / "ties.json")]
        rc, cout = sh(cmd, timeout=4 * 3600)
        (cw / "cosim.log").write_text(cout or "")
        print(cout)
        cs, scs = _cosim_cells(cout, rc, cycles)
    if cycles > 0:
        _inst_cosims(rows, work / "inst", CALIPTRA_DIR / "srcs.txt", CALIPTRA_DIR / "incs.txt",
                     [f"CALIPTRA={env['CALIPTRA']}"], [], _CALIPTRA_TIES, cycles, jobs)
    nproven = sum(1 for r in rows if r["formal"].startswith("✅"))
    rows.insert(0, {"module": "caliptra_top (full chip)",
                    "formal": f"{nproven}/{len(rows)} instances equivalent",
                    "cosim": cs, "slang_cosim": scs})
    return rows


# -------------------------------------------------------------------- report
def render(core, rows, cycles):
    # The pavona sweep adds a structural opt-level "check" column (undriven-net
    # detection on the flattened+opt'd read_uhdm netlist) — a fast dropped-driver
    # probe that runs on every module without needing a deep co-sim.
    has_check = any("check" in r for r in rows)
    # The driver-CONFLICT column (see _CONFLICTS): reported next to `formal`
    # because it is what tells you whether to BELIEVE the formal column.
    has_conf = any(r.get("conflicts", "—") != "—" for r in rows)
    lines = [f"## {core} sweep — formal (vs read_slang) + Verilator co-sim "
             f"({cycles} cycles)", ""]
    # Left-most column: the read_slang netlist's own co-sim vs the behavioural
    # RTL — the correctness baseline of the reference frontend that the
    # "formal vs slang" column compares read_uhdm against.
    sc = lambda r: r.get("slang_cosim", "—")
    hdr = ["slang co-sim vs RTL", "module", "formal vs slang"]
    if has_conf:
        hdr.append("driver conflicts")
    if has_check:
        hdr.append("opt check (undriven)")
    hdr.append("co-sim vs RTL")
    lines += ["| " + " | ".join(hdr) + " |",
              "|" + "---|" * len(hdr)]
    for r in rows:
        cells = [sc(r), r["module"], r["formal"]]
        if has_conf:
            cells.append(r.get("conflicts", "—"))
        if has_check:
            cells.append(r.get("check", "—"))
        cells.append(r["cosim"])
        lines.append("| " + " | ".join(cells) + " |")
    spass = sum(1 for r in rows if sc(r).startswith("✅"))
    sfail = sum(1 for r in rows if sc(r).startswith("❌"))
    npass = sum(1 for r in rows if r["cosim"].startswith("✅"))
    nfail = sum(1 for r in rows if r["cosim"].startswith("❌"))
    nadj = sum(1 for r in rows if r["cosim"].startswith("⚠"))
    comparable = npass + nfail
    pct = (100.0 * npass / comparable) if comparable else 100.0
    nequiv = sum(1 for r in rows if r["formal"].startswith("✅"))
    lines += ["",
              f"**Slang co-sim baseline:** {spass}/{spass + sfail} read_slang "
              f"netlists track the RTL ({sfail} diverge; "
              f"{len(rows) - spass - sfail} not comparable).",
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
    if has_conf:
        cclean = sum(1 for r in rows if r.get("conflicts", "").startswith("✅"))
        cdirty = sum(1 for r in rows if r.get("conflicts", "").startswith("❌"))
        lines.append(
            f"**Driver conflicts:** {cclean}/{cclean + cdirty} modules with "
            f"none ({cdirty} with a net driven twice, or an assignment whose "
            f"target is a constant / input port). A row with conflicts makes "
            f"the formal column UNRELIABLE — the bogus feedback constrains the "
            f"miter to the inputs where gold and gate agree, so it can pass "
            f"vacuously.")
    nunbuild = sum(1 for r in rows if "netlist unbuildable" in r.get("cosim", ""))
    if nunbuild:
        lines.append(
            f"**Unbuildable netlists:** {nunbuild} — Verilator refused the "
            f"generated netlist (it rejects an assignment to an input port). "
            f"These used to count as a co-sim skip; they are a malformed "
            f"lowering, not a missing run.")
    return "\n".join(lines) + "\n"


def main():
    global _SHARD
    ap = argparse.ArgumentParser()
    ap.add_argument("core", choices=["ibex", "rp32", "cva6", "pavona", "tlul",
                                     "acc", "kmac", "hmac", "edn", "csrng", "aes",
                                     "entropy_src", "keymgr", "periph", "periph2", "periph3", "periph4", "periph5",
                                     "egret", "dragonfly", "caliptra",
                                     "opentitan"] + _ext_families())
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
        # A chip family's "(full chip)" row appears in EVERY shard: add the
        # instance tallies together and take the co-sim cells from the shard
        # that ran the chip co-sim.
        seen, uniq, tops = set(), [], {}
        for r in sorted(rows, key=lambda r: r["module"]):
            if r["module"].endswith("(full chip)"):
                t = tops.setdefault(r["module"], dict(r, _n=0, _d=0))
                m = re.match(r"(\d+)/(\d+) instances", r.get("formal", ""))
                if m:
                    t["_n"] += int(m.group(1)); t["_d"] += int(m.group(2))
                for k in ("cosim", "slang_cosim"):
                    if r.get(k, "—") != "—":
                        t[k] = r[k]
                continue
            if r["module"] in seen:
                continue
            seen.add(r["module"])
            uniq.append(r)
        for name, t in tops.items():
            t["formal"] = f"{t.pop('_n')}/{t.pop('_d')} instances equivalent"
            uniq.insert(0, t)
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
    elif args.core == "opentitan":
        rows = sweep_opentitan(args.jobs, args.cycles, args.filter)
    elif args.core == "tlul":
        rows = sweep_tlul(args.jobs, args.cycles, args.filter)
    elif args.core == "acc":
        rows = sweep_acc(args.jobs, args.cycles, args.filter)
    elif args.core == "kmac":
        rows = sweep_kmac(args.jobs, args.cycles, args.filter)
    elif args.core == "hmac":
        rows = sweep_kmac(args.jobs, args.cycles, args.filter, ip="hmac")
    elif args.core in ("edn", "csrng", "aes", "entropy_src", "keymgr", "periph", "periph2", "periph3", "periph4", "periph5"):
        rows = sweep_kmac(args.jobs, args.cycles, args.filter, ip=args.core)
    elif args.core in ("egret", "dragonfly"):
        rows = sweep_chip(args.core, args.jobs, args.cycles, args.filter)
    elif args.core == "caliptra":
        rows = sweep_caliptra(args.jobs, args.cycles, args.filter)
    elif args.core in _ext_families():
        rows = sweep_ext(args.core, args.jobs, args.cycles, args.filter)
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
