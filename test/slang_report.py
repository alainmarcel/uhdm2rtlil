#!/usr/bin/env python3
"""One report for everything read_slang cannot do that the regression asks of it.

Sources, all in the same row format (set, test, reason, diagnostic, recipe):
  * the nightly IP / core sweeps (build/sweeps/<dir>/*/<family>-sweep-report/*.md,
    downloaded with `gh run download <run> --pattern '*sweep-report*'`):
    modules read_slang cannot elaborate, and modules whose read_slang netlist
    diverges from the RTL under Verilator while read_uhdm's does not
  * the internal regression tests (test/*/) and the upstream yosys tests
    (test/run/**): the TSV of slang_coverage_sweep.sh

Every failing row gets ONE class in one of these kinds:
  sim-only     slang refuses a simulation-only construct the other frontends
               accept (# delays, $past/$stable, SVA, NBA in initial, $fopen)
  strict       slang enforces an LRM rule read_verilog / read_uhdm relax
  synth-limit  sv-elab (read_slang's synthesis layer) does not lower it yet
  bug          read_slang crashed, or its netlist diverges from the RTL
A row the harness could not give slang a fair run on -- a module no file of
the test defines, a test invalid on purpose, a design NO frontend elaborates,
a co-sim both netlists fail identically -- is not a slang verdict; those go to
docs/incomplete_testcases.md with a statement of who fails on them.

Usage (from test/):
  ./slang_coverage_sweep.sh -j 8 slang_coverage.tsv
  python3 slang_report.py --tests slang_coverage.tsv --sweeps ../build/sweeps/latest \
          --out ../docs/slang_unsupported.md --incomplete ../docs/incomplete_testcases.md
"""
import argparse, glob, json, os, re, subprocess, sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = "https://github.com/alainmarcel/uhdm2rtlil/blob/main/"
EXT_ROOT = os.environ.get("EXT_IP_ROOT", os.path.expanduser("~/ext"))

# ---------------------------------------------------------------- classes
CLASSES = [  # (kind, label, regex) -- first match wins; "incomplete" rows leave the report
    ("incomplete", "test invalid on purpose (yosys `tests/errors`)", r"^run/errors/"),
    ("incomplete", "a module no file of the test defines", r"unknown module|unknown class or package"),
    ("incomplete", "a file the test does not ship", r"No such file or directory|failed to open file"),
    ("sim-only", "`#` delay / timing control", r"unsynthesizable timing control|statements that pass time"),
    ("sim-only", "unsupported system task (`$past`, `$stable`, `$fopen`, ...)", r"unsupported system task|unknown format specifier|arguments for '\$fopen'|arguments for '\$f"),
    ("sim-only", "SystemVerilog assertion (SVA) feature", r"unsupported SVA"),
    ("sim-only", "non-blocking assignment in design initialization", r"non-blocking assignments unsupported in design initialization"),
    ("sim-only", "net state read in design initialization", r"reading net state during design initialization|evaluation does not resolve to a constant in design initialization"),
    ("sim-only", "unsynthesizable feature (string, event, dynamic size)", r"unsynthesizable feature|dynamic size unsupported for synthesis|value of type .* is unsupported for conversion to bits"),
    ("strict", "non-ANSI port declaration in an ANSI module", r"port declaration in module with ANSI style port list|port declaration .* does not match any port|implicit named port"),
    ("strict", "assignment to a net in a procedural block", r"cannot assign to a net within a procedural context"),
    ("strict", "implicit conversion needs a cast (enum / struct)", r"no implicit conversion|expression width of .* enum type width|invalid operands to binary expression"),
    ("strict", "out-of-range select or index", r"Windex-oob|Wrange-oob|Wrange-width-oob|out of range"),
    ("strict", "`$fatal` raised at elaboration -- the design refuses this configuration", r"\$fatal encountered"),
    ("strict", "hierarchical reference inside a constant function call (`$bits(inst.sig)`)", r"hierarchical references are not allowed in calls"),
    ("strict", "assignment pattern leaves array elements uncovered / overrides a parameter that does not exist", r"not all elements of array are covered|Wundefined-param-override|does not exist in"),
    ("strict", "redefinition / duplicate definition", r"Wredefinition|Wduplicate-definition"),
    ("strict", "name used before declaration / undeclared", r"used before its declaration|use of undeclared identifier|identifier .* used before"),
    ("strict", "generate-block reference or generate function in a constant expression", r"unnamed generate block|function declared inside a generate block|hierarchical name is not allowed in a constant expression|reference to non-constant variable"),
    ("strict", "top-level interface port left unconnected", r"unconnected interface port|cannot connect modport|allow-toplevel-iface-ports"),
    ("strict", "type rule (packed dims on int type, port initializer, member access, argument count, ...)", r"packed dimensions|packed members must be|variable port declarations may have an initializer|parameter declaration is missing an initializer|automatic variable|invalid member access|no member named|invalid argument type .* to system function|unknown package|too few arguments|too many arguments|value must be positive|module instantiation is missing port list|port .* does not exist|parallel specify path|could not resolve|assignment pattern for|constant variable must have an initializer|packed union|compilation unit|cannot refer to|is not a valid|does not match|cannot be assigned|requires a|is not allowed"),
    ("strict", "syntax slang rejects (`expected ...`, macro, binary digit)", r"error: expected |unknown macro|doesn.*label|expected (a |an )?[a-z]"),
    ("synth-limit", "flip-flop with multiple / non-canonical asynchronous loads", r"asynchronous load|polarity of condition doesn't match edge"),
    ("synth-limit", "`unsupported language feature`", r"unsupported language feature"),
    ("synth-limit", "mixed blocking / non-blocking assignment to one variable", r"assignment to variable .* after previous (non-)?blocking|is not supported after previous"),
    ("synth-limit", "net declaration initializer / `$readmemh` (sv-elab)", r"no miter: slang net-init|no miter: slang \$readmemh"),
    ("synth-limit", "read_slang did not finish within the sweep's time budget", r"did not finish within|^TIMEOUT$"),
    ("bug", "internal frontend error / failed assert / abort / bad_alloc", r"Internal frontend error|Assert `|Abort in |bad_alloc"),
    ("bug", "`Feature unimplemented`", r"Feature unimplemented"),
    ("bug", "malformed RTLIL identifier emitted", r"control character or space"),
    ("bug", "netlist diverges from the RTL under Verilator (read_uhdm's does not)", r"^SLANG_COSIM_DIVERGES"),
]
KIND_ORDER = ["sim-only", "strict", "synth-limit", "bug", "unclassified"]
KIND_BLURB = {
    "sim-only": "Simulation-only constructs. `read_verilog` and `read_uhdm` accept them (the regression's co-sim never sees them); slang rejects them unless told `--ignore-timing` / `--ignore-assertions` / `--ignore-initial`.",
    "strict": "LRM rules slang enforces and the other two frontends relax. The source is what a strict compiler rejects; the fix is in the design or in the test.",
    "synth-limit": "Constructs sv-elab, read_slang's synthesis layer, does not lower yet.",
    "bug": "read_slang crashed, or produced a netlist that does not behave like the RTL while read_uhdm's does: a defect to report upstream (sv-elab, vendored in third_party/yosys/frontends/slang).",
    "unclassified": "No rule matched -- add one to CLASSES in test/slang_report.py.",
}

def classify(name, diag):
    for kind, label, rx in CLASSES:
        if re.search(rx, name if rx.startswith("^run/") else diag):
            return kind, label
    return "unclassified", diag[:70]

def clean_diag(d):
    d = re.sub(r"/[^ ]*/third_party/yosys/", "third_party/yosys/", d)
    d = re.sub(r"(\.\./)+repos/", "", d)
    d = re.sub(r"/home/[^ ]*/(ext|uhdm2rtlil)/", "", d)
    return d.replace("|", "\\|").strip()[:200]

# ---------------------------------------------------------------- families
CORE_ROOTS = {
    "ibex": ["test/ibex"], "rp32": ["test/rp32"],
    "cva6": ["test/cva6_equiv/rtl"], "cva6-chip": ["test/cva6_equiv/rtl", "test/cva6_chip"],
    "caliptra": ["test/caliptra_chip"], "opentitan": ["test/opentitan_equiv"],
}
PAVONA = ["pavona", "tlul", "acc", "kmac", "hmac", "edn", "csrng", "aes", "entropy_src",
          "keymgr", "periph", "periph2", "periph3", "periph4", "periph5", "egret", "dragonfly"]
for f in PAVONA:
    CORE_ROOTS[f] = ["test/pavona_equiv", "test/pavona_%s_equiv" % f, "test/pavona_chips"]

def ext_manifests():
    out = {}
    for f in glob.glob(os.path.join(HERE, "ext_ip", "*.json")):
        fam = os.path.basename(f)[:-5]
        try:
            m = json.load(open(f))
        except Exception:
            continue
        out[fam] = [(r.get("url", "").rstrip("/").removesuffix(".git"), str(r.get("commit", "")), r.get("dir", ""))
                    for r in m.get("repos", [])]
    return out
EXT = ext_manifests()

_find_cache = {}
def find_module_file(mod, roots):
    """(path, line) of `module <mod>` under roots, or None."""
    key = (mod, tuple(roots))
    if key in _find_cache:
        return _find_cache[key]
    res = None
    for root in roots:
        if not os.path.isdir(root):
            continue
        try:
            out = subprocess.run(["grep", "-rnE", "--include=*.sv", "--include=*.v", "--include=*.svh",
                                  "--exclude-dir=slpp_all", "--exclude-dir=work", "--exclude-dir=sim_equiv",
                                  r"^\s*module\s+" + re.escape(mod) + r"\b", root],
                                 capture_output=True, text=True, timeout=120).stdout
        except Exception:
            out = ""
        hits = [l for l in out.splitlines() if l.strip()]
        if hits:
            path, line = hits[0].split(":", 2)[:2]
            res = (path, int(line))
            break
    _find_cache[key] = res
    return res

def sweep_link(fam, mod):
    """Markdown link to the module's source for a sweep row."""
    if fam in EXT:
        for url, commit, d in EXT[fam]:
            hit = find_module_file(mod, [os.path.join(EXT_ROOT, d)]) if d else None
            if hit:
                rel = os.path.relpath(hit[0], os.path.join(EXT_ROOT, d))
                return f"[`{mod}`]({url}/blob/{commit}/{rel}#L{hit[1]})"
        return f"[`{mod}`]({REPO}test/ext_ip/{fam}.json)"
    roots = [os.path.join(ROOT, r) for r in CORE_ROOTS.get(fam, [])]
    hit = find_module_file(mod, roots) if roots else None
    if hit:
        rel = os.path.relpath(hit[0], ROOT)
        return f"[`{mod}`]({REPO}{rel}#L{hit[1]})"
    wf = {"xiangshan-core-full": ".github/workflows/sweep-xiangshan.yml"}.get(fam, ".github/workflows/")
    return f"[`{mod}`]({REPO}{wf})"

def recipe_for(setname, name, fam=None):
    if setname == "internal":
        return "R1", f"`./slang_coverage_sweep.sh --one {name}`"
    if setname == "upstream":
        return "R2", f"`./slang_coverage_sweep.sh --one {name}`"
    if fam in EXT:
        return "R3", f"`python3 ext_flow.py {fam} {name}`"
    return "R4", f"`python3 core_sweep.py {fam} --filter '^{name}$'`"

# ---------------------------------------------------------------- sources
def load_tests(tsv):
    rows = []
    for line in open(tsv):
        p = line.rstrip("\n").split("\t")
        if len(p) < 2:
            continue
        d, st = p[0], p[1]
        diag = p[2] if len(p) > 2 else ""
        setname = "upstream" if d.startswith("run/") else "internal"
        rows.append(dict(set=setname, fam=None, name=d, status=st, diag=diag))
    return rows

def parse_md_table(path):
    hdr = None
    for line in open(path):
        if not line.startswith("| "):
            continue
        c = [x.strip() for x in line.strip().strip("|").split("|")]
        if hdr is None:
            hdr = [h.lower() for h in c]
            continue
        if not c or set(c[0]) <= set("-: ") or len(c) != len(hdr):
            continue
        yield dict(zip(hdr, c))

def load_sweeps(root):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "**", "*-sweep-report", "*.md"), recursive=True)):
        fam = os.path.basename(f).replace("-sweep.md", "")
        for r in parse_md_table(f):
            mod = r.get("module", "").strip("`")
            formal = r.get("formal vs slang", "")
            scos = r.get("slang co-sim vs rtl", "")
            ucos = r.get("co-sim vs rtl", "")
            if not mod:
                continue
            m = re.match(r"no reference \(read_slang fails\) \((.*)\)\s*$", formal)
            if m:
                rows.append(dict(set="sweep", fam=fam, name=mod, status="FAIL", diag=m.group(1), ucos=ucos))
                continue
            if re.search(r"no miter: slang", formal):
                rows.append(dict(set="sweep", fam=fam, name=mod, status="FAIL", diag=formal, ucos=ucos))
                continue
            if formal.startswith("elab-fail") or re.search(r"no miter: (empty module|iface port at top|upstream RTL incomplete)", formal):
                rows.append(dict(set="sweep", fam=fam, name=mod, status="INCOMPLETE", diag=formal, ucos=ucos))
                continue
            if scos.startswith("❌"):
                if ucos.startswith("✅"):
                    rows.append(dict(set="sweep", fam=fam, name=mod, status="FAIL",
                                     diag="SLANG_COSIM_DIVERGES " + scos + "; read_uhdm " + ucos, ucos=ucos))
                else:
                    rows.append(dict(set="sweep", fam=fam, name=mod, status="INCOMPLETE",
                                     diag="both netlists diverge from the RTL: slang " + scos + ", read_uhdm " + ucos, ucos=ucos))
                continue
            if scos.startswith("✅") and ucos.startswith("❌"):
                rows.append(dict(set="sweep", fam=fam, name=mod, status="UHDM_WRONG",
                                 diag="read_slang " + scos + "; read_uhdm " + ucos, ucos=ucos))
                continue
            if scos in ("error", "vacuous") or scos.startswith("skip"):
                rows.append(dict(set="sweep", fam=fam, name=mod, status="INCOMPLETE",
                                 diag="slang co-sim " + scos + "; read_uhdm " + (ucos or "—"), ucos=ucos))
    return rows

# ---------------------------------------------------------------- emit
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tests", required=True, help="TSV from slang_coverage_sweep.sh")
    ap.add_argument("--sweeps", default=os.path.join(ROOT, "build", "sweeps", "latest"))
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "slang_unsupported.md"))
    ap.add_argument("--incomplete", default=os.path.join(ROOT, "docs", "incomplete_testcases.md"))
    a = ap.parse_args()

    rows = load_tests(a.tests) + load_sweeps(a.sweeps)
    totals = defaultdict(Counter)
    for r in rows:
        key = r["set"] if r["set"] != "sweep" else "sweep:" + r["fam"]
        totals[key][r["status"]] += 1

    report, incomplete, ours = [], [], []
    for r in rows:
        if r["status"] == "OK":
            continue
        if r["status"] == "UHDM_WRONG":
            ours.append(r); continue
        if r["status"] in ("NOFILES", "NODIR"):
            continue
        if r["status"] == "INCOMPLETE":
            r["kind"], r["label"] = "incomplete", r["diag"]
            incomplete.append(r); continue
        kind, label = classify(r["name"], r["diag"] if r["status"] == "FAIL" else "TIMEOUT")
        r["kind"], r["label"] = kind, label
        (incomplete if kind == "incomplete" else report).append(r)

    for r in report + incomplete + ours:
        if r["set"] == "sweep":
            r["link"] = sweep_link(r["fam"], r["name"])
            r["rid"], r["cmd"] = recipe_for("sweep", r["name"], r["fam"])
            r["setlabel"] = "sweep " + r["fam"]
        else:
            r["link"] = f"[`{r['name']}`]({REPO.replace('/blob/', '/tree/')}test/{r['name']})"
            r["rid"], r["cmd"] = recipe_for(r["set"], r["name"])
            r["setlabel"] = "internal test" if r["set"] == "internal" else "yosys test"

    L = []; A = L.append
    A("# What `read_slang` cannot read or gets wrong, across every test we run\n")
    A("`read_slang` (the vendored [sv-elab](https://github.com/povik/sv-elab) frontend built")
    A("into our Yosys) is the reference the regression proves `read_uhdm` against. This")
    A("report lists every place that reference is missing or wrong: the nightly IP and")
    A("core sweeps, the internal regression tests, and the upstream yosys tests, in one")
    A("format. Each row names a reason, links the test, and names the recipe that")
    A("reproduces it. Rows the harness could not give slang a fair run on are not here;")
    A("they are in [incomplete_testcases.md](incomplete_testcases.md) with a statement of")
    A("which frontends fail on them.\n")
    A("Generated by `test/slang_report.py` from `test/slang_coverage_sweep.sh`'s TSV and the")
    A("downloaded nightly sweep reports; regenerate after a regression + sweep cycle.\n")

    A("## How to reproduce\n")
    A("All recipes run from a built tree (`make -j$(nproc)`), from `test/`.\n")
    A("| recipe | applies to | command | what you get |")
    A("|---|---|---|---|")
    A("| **R1** | an internal test `test/<name>` | `./slang_coverage_sweep.sh --one <name>` | prints the exact `read_slang` command the regression's source list gives (dut.sv or project.f, with its `-I`/`-D`), runs it, shows every diagnostic. A test with a `test_slang_equiv.ys` also has `yosys -m ../../build/uhdm2rtlil.so test_slang_equiv.ys` for the read_uhdm-vs-read_slang miter. |")
    A("| **R2** | an upstream yosys test `test/run/<path>` | `./slang_coverage_sweep.sh --one run/<path>` | same; the `run/` tree is what `run_all_tests.sh` generates from `third_party/yosys/tests` (run the regression once). Sibling tests defining an instantiated module are added as `-v` library files, as the upstream `.ys` scripts read them. |")
    A("| **R3** | an external IP sweep module (family has `test/ext_ip/<family>.json`) | `cd ext_ip && python3 ext_flow.py <family> <module>` | clone the manifest's repositories at their commits into `$EXT_IP_ROOT` (default `~/ext`, directory per `repos[].dir`) first. Prints the module's row: `formal vs slang` holds slang's diagnostic when it cannot read, `slang co-sim vs RTL` the Verilator verdict; the testbench and netlists stay in the family's work directory. |")
    A("| **R4** | a core sweep module (ibex, rp32, cva6, cva6-chip, pavona families, caliptra, opentitan) | `python3 core_sweep.py <core> --filter '^<module>$'` | sources are vendored under `test/`; same row format as R3. |")
    A("")

    A("## Totals\n")
    A("| set | tests / modules | read_slang fails | of which in this report | in incomplete_testcases.md |")
    A("|---|---|---|---|---|")
    def cnt(pred):
        return sum(1 for r in report if pred(r)), sum(1 for r in incomplete if pred(r))
    for key in ["internal", "upstream"] + sorted(k for k in totals if k.startswith("sweep:")):
        t = totals[key]
        n = sum(v for k2, v in t.items() if k2 in ("OK", "FAIL", "TIMEOUT", "INCOMPLETE"))
        if key.startswith("sweep:"):
            fam = key[6:]
            rep, inc = cnt(lambda r: r["set"] == "sweep" and r["fam"] == fam)
            n_fail = rep + inc
            A(f"| sweep {fam} | {n} rows read | {n_fail} | {rep} | {inc} |")
        else:
            rep, inc = cnt(lambda r: r["set"] == key)
            A(f"| {'internal tests' if key == 'internal' else 'yosys tests'} | {n} | {t['FAIL'] + t['TIMEOUT']} | {rep} | {inc} |")
    A("")
    A("The yosys line counts every generated `run/` directory, 29 of which the regression does not score (the deliberately invalid `tests/errors` and tests that produce no RTLIL under any frontend); the regression's own count is 547.\n")
    A("The sweep lines count rows of the nightly tables (modules slang could not read, or whose slang netlist failed co-sim); modules slang reads and matches are not listed per family here -- see the README's sweep table.\n")

    A("## Failure classes\n")
    A("| kind | class | internal | yosys | sweeps |")
    A("|---|---|---|---|---|")
    by = defaultdict(list)
    for r in report:
        by[(r["kind"], r["label"])].append(r)
    for kind in KIND_ORDER:
        for (k, label), lst in sorted(by.items(), key=lambda kv: -len(kv[1])):
            if k != kind: continue
            ni = sum(1 for r in lst if r["set"] == "internal")
            nu = sum(1 for r in lst if r["set"] == "upstream")
            ns = len(lst) - ni - nu
            A(f"| {kind} | {label} | {ni} | {nu} | {ns} |")
    A("")
    for kind in KIND_ORDER:
        items = [(k, lst) for k, lst in by.items() if k[0] == kind]
        if not items: continue
        A(f"## {kind}\n")
        A(KIND_BLURB[kind] + "\n")
        for (k, label), lst in sorted(items, key=lambda kv: -len(kv[1])):
            A(f"### {label} -- {len(lst)}\n")
            A("| set | test | diagnostic | recipe |")
            A("|---|---|---|---|")
            for r in sorted(lst, key=lambda r: (r["setlabel"], r["name"])):
                d = clean_diag(r["diag"]).replace("SLANG_COSIM_DIVERGES ", "")
                A(f"| {r['setlabel']} | {r['link']} | {d} | {r['rid']} {r['cmd']} |")
            A("")
    A("## The other direction: `read_slang` right, `read_uhdm` wrong\n")
    A("A document that can only record another tool's mistakes is not a measurement.")
    A("These sweep rows co-simulate clean with the `read_slang` netlist and diverge with")
    A("ours; they are OUR defects, tracked in the sweeps, listed here in the same format.\n")
    A(f"**{len(ours)}** rows.\n")
    A("| set | test | verdicts | recipe |")
    A("|---|---|---|---|")
    for r in sorted(ours, key=lambda r: (r["setlabel"], r["name"])):
        A(f"| {r['setlabel']} | {r['link']} | {clean_diag(r['diag'])} | {r['rid']} {r['cmd']} |")
    A("")
    open(a.out, "w").write("\n".join(L) + "\n")

    # ------------------------------------------------ incomplete_testcases.md
    def fails_for(r):
        d = r["diag"]
        if r["set"] == "upstream" and r["name"].startswith("run/errors/"):
            return "all frontends -- the test is invalid on purpose (yosys `tests/errors`)"
        if "unknown module" in d or "unknown class or package" in d:
            m = re.search(r"unknown (?:module|class or package) '([^']+)'", d)
            what = m.group(1) if m else "a module"
            if what.startswith("$"):
                return (f"`{what}` is a yosys internal cell: read_verilog knows it with `-icells`, "
                        "read_slang has no equivalent -- only read_slang fails, and the test is about "
                        "the cell library, not the language")
            return (f"`{what}` is defined in no file the test reads. read_verilog keeps it as an "
                    "empty blackbox; the regression gives read_uhdm `-allow-undefined-modules` for these; "
                    "read_slang has no such option (sv-elab dropped `--ignore-unknown-modules`), so only "
                    "read_slang refuses -- but no frontend elaborates the missing module")
        if "No such file" in d or "failed to open file" in d:
            return "all frontends -- the file is not in the tree"
        if d.startswith("elab-fail"):
            return "all frontends -- neither read_uhdm nor read_slang elaborates it at the sweep's configuration"
        if "upstream RTL incomplete" in d:
            return "all frontends -- the upstream RTL is incomplete"
        if "iface port at top" in d:
            return "no frontend -- both read it; the co-sim harness cannot drive interface ports on a top module"
        if "empty module" in d:
            return "no frontend -- the module has no logic to compare"
        if d.startswith("both netlists diverge"):
            return "no frontend -- both netlists diverge identically: a testbench artefact (an un-reset register reads X in the RTL, 0 in both netlists)"
        if d.startswith("slang co-sim error"):
            return ("undetermined -- Verilator could not build or run the read_slang netlist's testbench "
                    "(the read_uhdm netlist's verdict is beside it); a netlist Verilator cannot compile is "
                    "worth a look, but the sweep has no diagnostic for it yet")
        if d.startswith("slang co-sim skip"):
            return "undetermined -- the co-sim did not run for either netlist (no observable outputs, or Verilator cannot build the RTL)"
        if d.startswith("slang co-sim vacuous"):
            return "undetermined -- the co-sim ran but no output ever moved (vacuous)"
        return "undetermined"
    I = []; B = I.append
    B("# Test cases no frontend can be judged on\n")
    B("Rows removed from [slang_unsupported.md](slang_unsupported.md) because the")
    B("harness could not give `read_slang` a fair run: a module no file of the test")
    B("defines, a test that is invalid on purpose, a design no frontend elaborates, a")
    B("co-simulation both netlists fail identically. Each row states which frontends")
    B("fail on it. Same recipes as the main report (R1 internal test, R2 yosys test, R3")
    B("external IP module, R4 core module).\n")
    B("What the harness already tries before a row lands here: for a yosys test, every")
    B("sibling test in the same directory that defines an instantiated module is added")
    B("as a `-v` library file (that is how the upstream `.ys` scripts read them), so an")
    B("\"unknown module\" row below is one no file of the yosys tests defines -- a vendor")
    B("primitive (`RAMB36E1`), a yosys internal cell, or a module the test deliberately")
    B("leaves out. For a sweep module, the family manifest's include dirs, defines and")
    B("configuration binds are applied; `elab-fail` means neither frontend elaborates the")
    B("module with them.\n")
    B(f"**{len(incomplete)}** rows.\n")
    B("| set | test | why it is incomplete | fails for | recipe |")
    B("|---|---|---|---|---|")
    for r in sorted(incomplete, key=lambda r: (r["setlabel"], r["name"])):
        B(f"| {r['setlabel']} | {r['link']} | {clean_diag(r['diag'])} | {fails_for(r)} | {r['rid']} {r['cmd']} |")
    open(a.incomplete, "w").write("\n".join(I) + "\n")
    print(f"report rows {len(report)}, incomplete rows {len(incomplete)}, uhdm-wrong rows {len(ours)}; unclassified "
          f"{sum(1 for r in report if r['kind'] == 'unclassified')}")

if __name__ == "__main__":
    main()
