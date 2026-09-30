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
  overrides: {name: {"want", "seq", "timeout", "note"}}
                                         per-module entries merged into the auto
                                         list: a row that is NOT a reader defect
                                         (unique-case violation stimulus, a
                                         latch-vs-X class) keeps its verdict
                                         and says why in the note column
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

# Source-closure size above which the textual UHDM dump is suppressed (2 MB),
# and the Surelog wall-clock budget, which scales with the closure: the flat
# 900 s was written for hand-sized modules and is not enough for a generated
# whole-core top.
DUMP_LIMIT = 2 << 20
# Closure size above which the design is checked hierarchically instead of flat.
FLATTEN_LIMIT = 8 << 20
# Optional manifest cap ("max_closure_mb"): a module whose source closure is
# larger is reported as skipped (not comparable) without running Surelog.
# Surelog's peak memory grows with the closure (~0.25 GB per MB of generated
# firtool RTL: XiangShan's 151 MB XSTop needs 36 GB), so a hosted 16 GB runner
# can sweep the 1994 XiangShan core modules under 16 MB but not the 8
# top-level blocks above it; those get an honest row instead of an OOM kill
# that takes the shard down.
MAX_CLOSURE_BYTES = 0
ALWAYS_SRCS = []
# Extra read_slang flags from the manifest ("slang_flags").  caliptra-ss needs
# --single-unit: VeeR's `css_mcu0_RV_BUILD_AXI4` comes from a defines header
# listed as a SOURCE in its flist, and without single-unit the macro dies at
# the end of that file, so the wrapper's `.*` finds no AXI ports.
SLANG_FLAGS = ""


def _sl_timeout(src_bytes):
    return max(900, min(4 * 3600, int(src_bytes / (1 << 20)) * 20))


def sh(cmd, cwd=None, timeout=None, env=None):
    try:
        p = subprocess.run(cmd, cwd=cwd, text=True, timeout=timeout, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, errors="replace")
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        # TimeoutExpired.stdout is BYTES even when subprocess.run was given
        # text=True (the child is killed mid-stream, so the decoder never
        # runs).  Concatenating a str to it raised TypeError from inside the
        # HANDLER, which killed the whole sweep process: the verilog-ethernet
        # job died the moment one read_slang hit the 600 s cap and published
        # an empty "0/0 modules" report.  core_sweep.py already decodes here.
        out = e.stdout or ""
        if isinstance(out, (bytes, bytearray)):
            out = out.decode(errors="replace")
        return 124, out + "\nTIMEOUT"



def _capped(cmd):
    """Cap the address space when MEM_LIMIT_KB is set.

    The miter and the co-sim already do this; Surelog and the two elaborations
    did not, and for an ext family those run FIRST.  A blowup there does not
    fail the row, it takes the whole runner down -- "The runner has received a
    shutdown signal ... exit code 143" -- which is how the cvw family had the
    external-IP nightly red for six nights straight, burying every other
    family's result behind a failed workflow.  Capped, the row fails on its own
    and the rest of the sweep still reports.
    """
    mem = os.environ.get("MEM_LIMIT_KB")
    if not mem:
        return cmd
    return ["bash", "-c", f"ulimit -Sv {mem}; exec \"$@\"", "--"] + [str(c) for c in cmd]


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
# Errors that mean "this module cannot be elaborated standalone with its DEFAULT
# parameters", as opposed to "read_slang cannot handle this construct".  The
# distinction matters: the first is a property of the sweep (we picked a
# meaningless parameterisation), the second may be hiding a real frontend gap,
# so only the first is allowed to become a skip.
_DEFAULT_ELAB_ERRORS = (
    "invalid member access for type",   # struct port typed by `parameter type X = logic`
    "value must be positive",           # a width computed from a default parameter
    "cannot index into",                # array port degraded to a scalar
    "is not a class, package, or type", # type parameter used as a scope
)


def slang_failure_reason(log: str) -> str:
    """The one line of a failed read_slang log worth putting in the report.

    slang prints one `<file>:<line>:<col>: error: ...` diagnostic per problem
    and yosys then aborts with the generic `ERROR: Design elaboration failed;
    see full log for details`.  Yosys 0.68 flushed the diagnostics first;
    0.69 emits the generic line BEFORE them, so "first line mentioning error"
    turned every reason column into the same useless sentence (the 2026-09-28
    ext sweep on the 0.69 branch: 354 of 544 caliptra-ss rows changed text and
    none changed verdict).  Prefer the diagnostic wherever it lands; the
    generic line is the fallback for a failure that produced none.
    """
    diag = re.search(r"^[^\n]*\berror: [^\n]*", log, re.M)
    if diag:
        return diag.group(0)
    generic = re.search(r"(ERROR|error)[^\n]*", log)
    return generic.group(0) if generic else ""


def _defaults_unelaboratable(files, mod, slang_out):
    """True when read_slang's rejection is caused by the module's own DEFAULT
    parameters rather than by a construct read_slang does not support.

    Requires BOTH signals, so a slang limitation is never silently skipped:
      * the error text is one of the default-parameterisation failures above, and
      * the module actually declares a `parameter type`, i.e. it is meant to be
        instantiated with real types bound by a parent.
    """
    if not any(e in (slang_out or "") for e in _DEFAULT_ELAB_ERRORS):
        return False
    pat = re.compile(r"\bmodule\s+" + re.escape(mod) + r"\b")
    for f in files:
        try:
            src = open(f, "r", errors="replace").read()
        except OSError:
            continue
        mm = pat.search(src)
        if not mm:
            continue
        # header = everything up to the end of the port list
        head = src[mm.start():mm.start() + 8000]
        if re.search(r"parameter\s+type\s+\w+", head):
            return True
    return False


def _degenerate_ports(il_path, top):
    """Ports whose declared width came out of a parameter that is 0 by default.

    `parameter type req_t = logic` or `parameter int MaxIds = 0` makes a port
    `logic [MaxIds-1:0]`, i.e. `[-1:0]` -- which RTLIL writes as a NEGATIVE
    offset (`upto offset -1`).  A design cannot legally have such a port; it is
    only ever reached by reading a module standalone with defaults its author
    never intended, the same situation `_defaults_unelaboratable` already
    skips.  It slips past that check when read_slang accepts the degenerate
    declaration instead of erroring on it, and then shows up as undriven bits
    and a spurious `differs` (the two frontends normalise `[-1:0]` differently:
    read_uhdm keeps `upto offset -1`, read_slang rewrites it to `[1:0]`).

    PULP's axi does this in five modules -- axi_xbar, axi_xp,
    axi_interleaved_xbar, axi_xbar_unmuxed (type params) and
    axi_id_remap_table (`MaxUniqInpIds = 0`).
    """
    names, inmod = [], False
    try:
        for line in open(il_path, errors="replace"):
            if line.startswith("module "):
                inmod = line.strip() == "module \\" + top
                continue
            if not inmod:
                continue
            if line.startswith("end"):
                break
            mm = re.match(r"\s+wire\s+.*\boffset\s+(-\d+)\b.*\b(?:input|output|inout)\s+\d+\s+\\(\S+)\s*$",
                          line.rstrip("\n"))
            if mm:
                names.append(mm.group(2))
    except OSError:
        pass
    return names




def _with_wrapper_packages(cl, files, wrapper):
    """The GENERATED binding wrapper can reference a package the module itself
    never mentions -- gen_param_wrapper emits `typedef axi_pkg::xbar_rule_32_t
    rule_t` for a rule type -- and the closure was built from the module, so
    that package is not in it.  read_slang then refuses the design ("unknown
    class or package 'axi_pkg'") and the row is reported as a slang
    limitation, when the truth is that WE handed it an incomplete project.
    Six axi rows read that way.

    Worse, Surelog accepts the unresolved package quietly, so read_uhdm
    "reads" the module and every type that came from the package is wrong
    without a word.  Pulling the package into the closure fixes both halves.
    """
    have = set(files)
    extra = []
    try:
        txt = open(wrapper, errors="replace").read()
    except OSError:
        return files
    for pkg in sorted(set(re.findall(r"\b(\w+)\s*::", txt))):
        f = cl.defs.get(pkg)
        if not f or f in have:
            continue
        for g in cl.closure(pkg):
            if g not in have:
                have.add(g)
                extra.append(g)
    # Packages must precede their users for a per-file compilation unit.
    return extra + files


def _config_wrapper(w, fam, mod, files):
    """Bind a module's CONFIGURATION parameter (`#(parameter cvw_t P)`, no
    default) so read_slang can make it a top level.

    cvw is written around one struct parameter that carries the whole
    configuration and has NO default -- `module alu import cvw::*; #(parameter
    cvw_t P)` -- and the repository supplies the value as an INCLUDE
    (`config/shared/parameter-defs.vh` builds `localparam cvw_t P` out of the
    132 localparams in `config/rv64gc/config.vh`).  Read standalone the
    parameter is unbound, so read_slang refuses the module as a top level and
    136 cvw rows were reported as "read_slang cannot read this design" when we
    had simply never handed it the configuration.  See gen_config_wrapper.py."""
    out = w / f"{mod}_cfg.sv"
    rc, log = sh([sys.executable, str(HERE / "gen_config_wrapper.py"),
                  "--module", mod, "--manifest", str(HERE / f"{fam}.json"),
                  "--out", str(out), *files], timeout=300)
    (w / "cfgbind.log").write_text(log or "")
    if rc != 0 or not out.exists():
        return None
    return str(out), f"{mod}_cfg"


def _bind_wrapper(w, fam, mod, files):
    """Generate a type-bound wrapper for a module whose defaults cannot
    elaborate, and return (wrapper_path, top) -- or None.

    A sweep reads every module standalone, and PULP-style RTL is not written
    for that: `parameter type axi_req_t = logic` plus `mst_req_o.aw_valid`
    means that at its defaults the module takes a member of a 1-BIT LOGIC.
    That is not legal SystemVerilog, so read_slang rejects it and there is no
    reference to judge our netlist against -- 94 of the axi family's 108
    modules were excluded for exactly that reason and only 4 were ever really
    checked.  When the manifest carries a "bind" section, bind the type
    parameters to concrete types instead and sweep the wrapper.

    Only attempted for a module that actually declares `parameter type ... =
    logic`, so nothing that elaborates today changes.
    """
    if not (HERE / f"{fam}.json").exists():
        return None
    man = json.loads((HERE / f"{fam}.json").read_text())
    if not man.get("bind"):
        return None
    pat = re.compile(r"\bmodule\s+" + re.escape(mod) + r"\b")
    declares_type_param = False
    for f in files:
        try:
            src = open(f, "r", errors="replace").read()
        except OSError:
            continue
        mm = pat.search(src)
        if mm and re.search(r"parameter\s+type\s+\w+\s*=\s*logic\b",
                            src[mm.start():mm.start() + 8000]):
            declares_type_param = True
            break
    if not declares_type_param:
        return None
    # NOT `<mod>.sv`: a wrapper file whose basename matches the module's own
    # source file shadows it, and the module then never reaches the netlist
    # ("Module `\axi_cut' ... is not part of the design").
    out = w / f"{mod}_bound.sv"
    rc, log = sh([sys.executable, str(HERE / "gen_param_wrapper.py"),
                  "--module", mod, "--manifest", str(HERE / f"{fam}.json"),
                  "--out", str(out), *files], timeout=300)
    (w / "bind.log").write_text(log or "")
    if rc != 0 or not out.exists():
        return None
    return str(out), f"{mod}_bound"



# --- undriven-net classification -------------------------------------------
# read_uhdm stamps `(* uhdm_src_lhs *)` on every wire the SOURCE assigns
# somewhere (any procedural / continuous LHS, a child's output actual).  An
# undriven net WITHOUT it is one the RTL never assigns under this
# configuration -- cva6's trigger_module registers under SDTRIG=0, id_stage's
# dcache_req_ports_o under RVZCMT=0, the CLAUDE.md source-class table --
# which read_slang hides by driving a constant X.  Only an undriven net WITH
# the attribute is a driver the reader dropped, and only those stay red.
_UNDRIVEN_RE = re.compile(r"Wire (\S+?)(?: \[\d+\])? is used but has no driver")
_SELLIST_RE = re.compile(r"^[^\s/]+/(\S+)$", re.M)

def _wire_key(n):
    """Flattened `top.\\a.b` / `top/\\a.b` / `\\a.b [3]` -> `a.b`."""
    n = n.strip()
    if n.startswith("\\"):
        n = n[1:]
    else:
        # `check` prefixes the module: `kmac_ss.\\gen.u.seed` -> after the first
        # `.\\`; a plain `kmac_ss.seed` -> after the first `.`
        i = n.find(".\\")
        if i >= 0:
            n = n[i + 2:]
        elif "." in n and not n.startswith("$"):
            n = n.split(".", 1)[1]
    return n

def classify_undriven(out):
    """(dropped, source_never_assigns) counts from a check log that ends with
    `select -list a:uhdm_src_lhs`."""
    out = out or ""
    listed = {_wire_key(m) for m in _SELLIST_RE.findall(out)}
    dropped = never = 0
    for m in _UNDRIVEN_RE.finditer(out):
        if _wire_key(m.group(1)) in listed:
            dropped += 1
        else:
            never += 1
    return dropped, never

def undriven_cell(dropped, never):
    if dropped == 0 and never == 0:
        return "✅ 0 undriven"
    if dropped == 0:
        return f"✅ 0 undriven ({never} never assigned in the source)"
    if never:
        return f"❌ {dropped} undriven (+{never} never assigned in the source)"
    return f"❌ {dropped} undriven"

def _flat_wrapper(w, mod, files):
    """Generate the flat shim for a module with UNPACKED-ARRAY ports and return
    (wrapper_path, top) -- or None when it has none.

    `output tl_h2d_t tl_d_o [N]` is flattened to one vector by every frontend,
    but for an ASCENDING dimension (`[N]` is `[0:N-1]`) read_slang puts element
    0 at the MSBs and read_uhdm at the LSBs (they agree for `[N-1:0]`), so the
    miter reported a pure convention as "differs" -- tlul_socket_1n / _m1, the
    two reg_top windows, VeeR's pmp / dec_pmp_ctl / dec_tlu_ctl in caliptra-ss
    -- and Verilator cannot connect the co-sim testbench's vector to an array
    port at all ("skip (sim build)").  The shim (gen_flat_wrapper.py) makes
    the element order explicit index arithmetic that both frontends read the
    same way, exactly like the hand-written pavona shims
    (test/pavona_tlul_equiv/wrappers/flat_tlul_socket_1n.sv), and instantiates
    the module with its default parameters under `.*`.
    """
    out = w / f"{mod}_flat.sv"
    rc, log = sh([sys.executable, str(HERE / "gen_flat_wrapper.py"),
                  "--module", mod, "--out", str(out), *files], timeout=120)
    (w / "flat.log").write_text(log or "")
    if rc != 0 or not out.exists():
        return None
    return str(out), f"{mod}_flat"



def _uhdm_only_cosim(w, m, top, cycles, ties, mem):
    """Co-simulate the read_uhdm netlist against the behavioural RTL with NO
    slang netlist.  netlist_cosim.py takes `--slang-il` as optional, so a
    module read_slang cannot read is still measurable on our side -- which is
    the point: the RTL is the reference, not the other frontend."""
    (w / "ren_uhdm.ys").write_text(
        f"read_rtlil uhdm_hier.il\nhierarchy -top {top}\nrename {top} {m}_uhdm\n"
        f"write_rtlil {m}_uhdm.il\n")
    sh([str(Y), "-q", "ren_uhdm.ys"], cwd=w, timeout=600)
    cw = w / "cosim"
    cw.mkdir(exist_ok=True)
    (cw / "ties.json").write_text(json.dumps(ties))
    ccmd = [sys.executable, str(TEST / "netlist_cosim.py"), "--work", str(cw),
            "--uhdm-il", str(w / f"{m}_uhdm.il"),
            "--top", f"{m}_uhdm", "--rtl-top", top,
            "--srcs", str(w / "srcs.txt"), "--incs", str(w / "incs.txt"),
            "--cycles", str(cycles), "--ties", str(cw / "ties.json")]
    if mem:
        ccmd = ["bash", "-c", f"ulimit -Sv {mem}; exec " + " ".join(shlex.quote(c) for c in ccmd)]
    rc, out = sh(ccmd, cwd=w, timeout=3600)
    (cw / "cosim.log").write_text(out or "")
    mm = re.search(r"ADJUDICATION \d+ cycles: uhdm_vs_rtl=(\d+)", out or "")
    act = re.search(r"ACTIVITY (\d+) cycles", out or "")
    if mm:
        u = int(mm.group(1))
        a = f" ({cycles + 1} cycles, {act.group(1)} active)" if act else ""
        return ("✅ PASS" + a) if u == 0 else f"❌ {u} div"
    if "no outputs to compare" in (out or "") or "no clocks found" in (out or ""):
        return "— (comb/no clk)"
    if "NO_RUN" in (out or "") or "netlist generation FAILED" in (out or ""):
        return "skip (no run)"
    if "both simulators failed" in (out or "") or "build FAILED" in (out or ""):
        return "skip (sim build)"
    return "error"

def run_module(fam, cl, m, seq, tmo, want, incs, defines, cycles, do_cosim, survey, work_root, ties):
    w = work_root / m
    w.mkdir(parents=True, exist_ok=True)
    top = m
    files = cl.closure(m)
    # "always_srcs": files (globs, relative to $EXT_IP_ROOT) prepended to
    # every closure -- packages a module reaches only through an included
    # .svh, which the identifier scan of .sv/.v roots cannot see
    # (caliptra-ss's caliptra_prim_ram_1p_pkg behind caliptra_prim_assert.svh).
    if files and ALWAYS_SRCS:
        files = [f for f in ALWAYS_SRCS if f not in files] + files
    if not files:
        return {"module": m, "formal": "elab-fail", "formal_raw": "elabfail",
                "check": "— (no elaboration)", "cosim": "—", "slang_cosim": "—",
                "note": "no source found"}
    if MAX_CLOSURE_BYTES > 0:
        cbytes = sum(os.path.getsize(f) for f in files if os.path.exists(f))
        if cbytes > MAX_CLOSURE_BYTES:
            return {"module": m,
                    "formal": f"skip (closure {cbytes / (1 << 20):.0f} MB of {len(files)} "
                              f"files > {MAX_CLOSURE_BYTES >> 20} MB cap)",
                    "formal_raw": "skip", "check": "— (not comparable)",
                    "cosim": "—", "slang_cosim": "—",
                    "note": "too big for a hosted runner; sweep it from a workstation"}
    bound = _bind_wrapper(w, fam, m, files)
    if bound:
        files = _with_wrapper_packages(cl, files, bound[0]) + [bound[0]]
        top = bound[1]
    else:
        cfgw = _config_wrapper(w, fam, m, files)
        if cfgw:
            # The generated wrapper names a package the module itself never
            # mentions (`import cvw::*;`), so pull it into the closure.
            files = _with_wrapper_packages(cl, files, cfgw[0]) + [cfgw[0]]
            top = cfgw[1]
        flat = None if cfgw else _flat_wrapper(w, m, files)
        if flat:
            files = files + [flat[0]]
            top = flat[1]
    # The closure is part of the UHDM's identity: a manifest that gains a
    # root (cvfpu's vendored T-Head fdsu, cv32e40p's bhv clock gate) changes
    # srcs.txt, and a surelog.uhdm built from the old list must not be
    # reused -- it was, and the new module stayed "Cannot find a module
    # definition" on the read_uhdm side while read_slang saw it.
    old_srcs = (w / "srcs.txt").read_text() if (w / "srcs.txt").exists() else None
    old_incs = (w / "incs.txt").read_text() if (w / "incs.txt").exists() else None
    (w / "srcs.txt").write_text("\n".join(files) + "\n")
    (w / "incs.txt").write_text("\n".join(str(EXT / d) for d in incs) + "\n")
    inc_flags = [f"-I{EXT / d}" for d in incs]
    def_flags = [f"-D{d}" for d in defines]
    uhdm = w / "slpp_all" / "surelog.uhdm"
    stale = (not uhdm.exists()) or S.stat().st_mtime > uhdm.stat().st_mtime \
        or old_srcs != (w / "srcs.txt").read_text() or old_incs != (w / "incs.txt").read_text() \
        or any(os.path.exists(f) and os.path.getmtime(f) > uhdm.stat().st_mtime for f in files)
    # Closure size drives three budgets below, and is needed whether or not the
    # UHDM has to be rebuilt.
    src_bytes = sum(os.path.getsize(f) for f in files if os.path.exists(f))
    if stale:
        for old in ("slpp_all",):
            subprocess.run(["rm", "-rf", str(w / old)])
        # `-d uhdm` only adds the TEXTUAL UHDM dump on stdout (the binary
        # slpp_all/surelog.uhdm comes from `-parse` alone).  That dump is the
        # debugging aid we want on a small module and a disk hazard on a big
        # one: XiangShan's XSTop (3.2 M lines) dumps 8.5 GB of text.  Keep it
        # only while the closure is small.
        dump = ["-d", "uhdm"] if src_bytes <= DUMP_LIMIT else []
        rc, out = sh(_capped([str(S), "-parse", *dump, *def_flags, *inc_flags,
                              "-top", top, *files]),
                     cwd=w, timeout=_sl_timeout(src_bytes))
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

    # --- reference FIRST.  Whether a valid reference exists decides how to read
    # everything after it.  These repos are swept module-by-module with each
    # module's DEFAULT parameters, and PULP-style RTL declares its struct ports
    # through type parameters:
    #
    #     parameter type axi_resp_t = logic,
    #     output axi_resp_t slv_resp_o,
    #     .req_o ( slv_resp_o.b_valid )
    #
    # With the default binding that is a member access on a 1-BIT LOGIC -- not
    # valid SystemVerilog.  read_slang says so ("invalid member access for type
    # 'axi_resp_t' (aka 'logic')"); read_uhdm folds the actual to a constant and
    # yosys only objects later at flatten ("driving constant bits").  Judging our
    # netlist against an elaboration that is not legal in the first place tells
    # us nothing, so such a module is SKIPPED, not failed: 17 of 108 axi rows
    # were being reported as read-failures purely for this reason.
    (w / "slang.ys").write_text(
        f"read_slang --ignore-assertions {SLANG_FLAGS} {slang_defs} {slang_incs} {srcs_q} --top {top}\n"
        f"hierarchy -check -top {top}\nwrite_rtlil slang_hier.il\n")
    # NOT -q: the per-line slang diagnostics are what tell a default-parameter
    # elaboration failure apart from a slang limitation, and -q collapses them
    # to a bare "Design elaboration failed".
    rc2, out2 = sh(_capped([str(Y), "slang.ys"]), cwd=w, timeout=600)
    (w / "slang.log").write_text(out2 or "")
    slang_ok = rc2 == 0 and (w / "slang_hier.il").exists()
    if not slang_ok:
        serr_txt = slang_failure_reason(out2 or "")
        if _defaults_unelaboratable(files, m, out2 or ""):
            return {"module": m, "formal": "skip (defaults don't elaborate)",
                    "formal_raw": "skip", "check": "— (not comparable)",
                    "cosim": "—", "slang_cosim": "—",
                    "note": serr_txt[:140]}
        # A module read_slang cannot read has no FORMAL reference -- but the
        # behavioural RTL is still there, and neither the undriven check nor
        # the Verilator co-sim needs slang at all.  Returning here measured
        # NOTHING on 349 rows across the families, and those rows are where
        # the interesting designs are: an interface port at the top,
        # $readmemh, a package slang cannot resolve.  Carry on with the
        # read_uhdm side and report it; only the miter and the slang co-sim
        # are skipped.
        noref_note = serr_txt[:140]
    else:
        noref_note = None

    # --- survey / opt-check: read_uhdm, hierarchy -check, flatten, check
    # `flatten` is what makes `check` see the whole cone at once, but a
    # generated whole-core top (XiangShan's XSTop: 1980 modules, 6.5 M cells)
    # cannot be flattened in any sane amount of memory.  Above the limit run
    # `check` HIERARCHICALLY: it then reports per module, where an input port
    # counts as a driver -- still exactly the granularity an undriven net is
    # found at, since `hierarchy -top` has already pruned unreachable modules.
    flat = "flatten\n" if src_bytes <= FLATTEN_LIMIT else ""
    (w / "check.ys").write_text(
        f"read_uhdm slpp_all/surelog.uhdm\nhierarchy -check -top {top}\n"
        f"write_rtlil uhdm_hier.il\nproc\n{flat}opt_clean\nstat\ncheck\n"
        f"select -list a:uhdm_src_lhs\n")
    rc, out = sh(_capped([str(Y), "-q", "-m", str(P), "check.ys"]), cwd=w,
                 timeout=_sl_timeout(src_bytes))
    (w / "check.log").write_text(out or "")
    if rc != 0 or not (w / "uhdm_hier.il").exists():
        err = re.search(r"ERROR:[^\n]*", out or "")
        return {"module": m, "formal": "read-fail (uhdm)", "formal_raw": "error",
                "check": "—", "cosim": "—", "slang_cosim": "—",
                "note": (err.group(0)[:140] if err else "read_uhdm failed")}
    # A degenerate port means the module's own defaults are not a legal
    # configuration -- skip it like the other default-parameter cases rather
    # than reporting its undriven bits as a frontend defect.
    degen = (_degenerate_ports(w / "uhdm_hier.il", f"{top}") or
             _degenerate_ports(w / "slang_hier.il", f"{top}"))
    if degen:
        return {"module": m, "formal": "skip (defaults degenerate)",
                "formal_raw": "skip", "check": "— (not comparable)",
                "cosim": "—", "slang_cosim": "—",
                "note": f"port {degen[0]} has a negative range (parameter 0 by default)"}
    dropped, never = classify_undriven(out or "")
    undriven = dropped + never
    cells = re.search(r"Number of cells:\s*(\d+)", out or "")
    check = undriven_cell(dropped, never)
    # A module whose manifest entry asks only for "read" stops here, as does a
    # --survey run: that is how a whole-core top is swept, where the question
    # is "does it elaborate and is every net driven", not "is a 6.5 M-cell SAT
    # miter satisfiable".
    if survey or want == "read":
        return {"module": m, "formal": "read OK", "formal_raw": "read",
                "check": check, "cosim": "—", "slang_cosim": "—",
                "note": f"{cells.group(1)} cells" if cells else ""}
    if noref_note is not None:
        row = {"module": m, "formal": "no reference (read_slang fails)",
               "formal_raw": "noref", "check": check, "cosim": "—",
               "slang_cosim": "— (read_slang cannot read it)",
               "note": noref_note}
        if do_cosim and cycles > 0:
            row["cosim"] = _uhdm_only_cosim(w, m, top, cycles, ties,
                                            os.environ.get("MEM_LIMIT_KB"))
        return row

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
    # Intermixed: a sharded caller may put the module names after the options.
    args = ap.parse_intermixed_args()
    man = json.loads((HERE / f"{args.family}.json").read_text())
    work_root = TEST / "ext_ip" / "work" / args.family
    work_root.mkdir(parents=True, exist_ok=True)
    cl = Closure(man["roots"])
    excl = [re.compile(x) for x in man.get("exclude", [])]
    global MAX_CLOSURE_BYTES, ALWAYS_SRCS, SLANG_FLAGS
    SLANG_FLAGS = " ".join(man.get("slang_flags", []))
    MAX_CLOSURE_BYTES = int(float(man.get("max_closure_mb", 0)) * (1 << 20))
    ALWAYS_SRCS = sorted({f for g in man.get("always_srcs", [])
                          for f in glob.glob(str(EXT / g), recursive=True) if os.path.isfile(f)})
    if man.get("modules") == "auto":
        pref = man.get("only_prefix")
        # "sweep_paths": sweep only the modules DEFINED under these prefixes
        # (relative to $EXT_IP_ROOT); the roots outside them stay available
        # to the closures.  caliptra-ss vendors caliptra-rtl and i3c-core as
        # submodules: its own RTL needs them to elaborate, but the Caliptra
        # core has its own chip sweep and would otherwise be counted twice.
        sp = [str(EXT / d) for d in man.get("sweep_paths", [])]
        mods = [{"name": n} for n in sorted(cl.mod_files)
                if not any(x.search(n) for x in excl)
                and (not pref or n.startswith(pref))
                and (not sp or any(cl.mod_files[n].startswith(d) for d in sp))]
        ov = man.get("overrides", {})
        mods = [{**x, **ov.get(x["name"], {})} for x in mods]
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
        # skip / noref are "not comparable", not failures: mark them ⏭ so the
        # eye does not read a harness limitation as a frontend defect.
        if r.get("formal_raw") in ("skip", "noref"):
            ico = "⏭"
        else:
            ico = "✅" if r.get("formal_raw") in ("proven", "read") else ("‼" if r.get("formal_raw") == "elabfail" else "❌")
        if r.get("formal_raw") == want:
            ico = "✅"
        if x.get("note") and not r.get("note"):
            r["note"] = x["note"]
        print(f"  {ico} {r['module']:<34} {r['formal']:<28} {r['check']:<16} {r['cosim']:<32} "
              f"{r.get('note','')[:60]}  [{time.time() - t0:.0f}s]", flush=True)
        return r
    with cf.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
        rows = list(ex.map(one, mods))
    rows.sort(key=lambda r: r["module"])
    n = len(rows)
    # Rows with no valid reference are NOT COMPARABLE and are excluded from the
    # denominator: `skip` is a module whose own default parameters do not give a
    # legal elaboration (see _defaults_unelaboratable), `noref` is one read_slang
    # cannot read for its own reasons.  Counting either as a failure made the
    # family score a measure of the harness rather than of the frontend -- axi
    # read as 8/108 while 99 of those rows had no reference at all.
    skipped = sum(1 for r in rows if r.get("formal_raw") == "skip")
    noref = sum(1 for r in rows if r.get("formal_raw") == "noref")
    comparable = [r for r in rows if r.get("formal_raw") not in ("skip", "noref")]
    nc = len(comparable)
    prov = sum(1 for r in comparable if r.get("formal_raw") == "proven")
    read = sum(1 for r in comparable
               if r.get("formal_raw") in ("proven", "cex", "timeout", "memlimit", "read"))
    den = nc if nc else 1
    print(f"{args.family.upper()} equivalence: {prov}/{nc} proven, {read}/{nc} elaborate "
          f"({sum(1 for r in comparable if r.get('formal_raw') == 'elabfail')} elab-fail, "
          f"{sum(1 for r in comparable if r.get('formal_raw') == 'error')} error"
          f"{f'; {skipped} skipped (default params), {noref} no reference — excluded of {n}' if (skipped or noref) else ''})")
    out = args.out or (work_root / "rows.json")
    out.write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
