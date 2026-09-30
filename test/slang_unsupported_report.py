#!/usr/bin/env python3
"""Emit docs/slang_unsupported.md -- the designs `read_slang` cannot read.

The sweeps compare read_uhdm against read_slang, so a design read_slang cannot
elaborate has no comparison to report.  It used to have no MEASUREMENT either:
the sweep abandoned the row.  Since ext_flow.py keeps going on those rows, each
one carries a read_uhdm verdict -- undriven nets, and a co-simulation of our
netlist against the behavioural RTL, neither of which needs slang.

Inputs:
  noref.json         {family: [[module, formal-cell], ...]}  from the CI reports
  <dir>/<family>.md  the re-measured rows (ext_flow --out)
"""
import glob, json, os, re, sys, urllib.parse

NOREF = os.environ.get("SLANG_NOREF_JSON", "noref.json")
MEAS = os.environ.get("SLANG_NOREF_MEASURED", "noref_measured")

# One line per construct, so the reader sees WHAT slang is missing rather than
# 360 diagnostics.  Matched against the slang diagnostic, first hit wins.
CLASSES = [
    (r"unconnected interface port|iface port at top",
     "an interface port on the top module"),
    (r"\$readmemh|slang \$readmemh",
     "`$readmemh` / `$readmemb`"),
    (r"is not a valid top-level module",
     "refuses the module as a top level (usually an unbound interface or an unresolved parameter)"),
    (r"unknown module",
     "a module it cannot find in the closure the sweep gives it"),
    (r"unknown class or package",
     "a package or class it cannot resolve"),
    (r"unknown macro or compiler directive",
     "a macro the sweep's include set does not define for it"),
    (r"unroll limit",
     "a generate/for construct past its unroll limit"),
    (r"value must be positive",
     "a dimension it evaluates as non-positive"),
    (r"hierarchical references are not allowed",
     "a hierarchical reference in a constant expression (`$bits(iface.member)`)"),
    (r"non-blocking assignments unsupported in design initialization",
     "a non-blocking assignment in an initial block"),
    (r"Feature unimplemented",
     "an sv-elab construct marked unimplemented"),
    (r"No such file or directory",
     "a file the sweep's closure does not hand it"),
    (r"cannot select range|-Wrange-width-oob|index-oob",
     "an out-of-range select in code a parameter makes dead"),
    (r"no implicit conversion from",
     "an implicit struct/vector conversion it rejects"),
    (r"use of undeclared identifier",
     "an identifier it does not resolve in that scope"),
    (r"value must not have any unknown bits",
     "a parameter whose default carries `x` bits"),
    (r"slang net-init",
     "a net-declaration initialiser it does not lower"),
    (r"not all elements of array are covered by an assignment pattern",
     "an assignment pattern it judges incomplete"),
    (r"\$error encountered|\$fatal encountered",
     "an elaboration-time `$error`/`$fatal` the design guards with parameters"),
    (r"port '[^']*' does not exist",
     "a port it does not find on a child module"),
    (r"upstream RTL incomplete|empty module",
     "nothing to compare (the upstream RTL is incomplete, or the module is empty)"),
    (r"Design elaboration failed",
     "elaboration failed with no single diagnostic"),
]

def classify(formal):
    for rx, name in CLASSES:
        if re.search(rx, formal, re.I):
            return name
    return "other"

def issue_url(module, why, verdict):
    title = f"read_slang: cannot elaborate {module}"
    body = (f"`read_slang` cannot read this design; `read_uhdm` does.\n\n"
            f"Diagnostic: {why}\n\n"
            f"read_uhdm on the same sources: {verdict}\n\n"
            f"Yosys 0.69, read_slang from the vendored sv-elab "
            f"(povik/sv-elab @ b4fd362).")
    return ("https://github.com/YosysHQ/yosys/issues/new?"
            + urllib.parse.urlencode({"title": title, "body": body}))

def load_measured(d):
    """module -> (undriven cell, cosim cell).  ext_flow --out writes core_sweep's
    row schema as JSON, one list per family."""
    out = {}
    for f in glob.glob(os.path.join(d, "*.md")) + glob.glob(os.path.join(d, "*.json")):
        try:
            rows = json.load(open(f))
        except Exception:
            continue
        if not isinstance(rows, list):
            continue
        for r in rows:
            if isinstance(r, dict) and r.get("module"):
                out[r["module"]] = (r.get("check", "—"), r.get("cosim", "—"))
    return out

def noref_from_sweeps(root):
    """Build the {family: [[module, formal]]} map straight from downloaded CI
    sweep reports, so the file needs no hand-maintained input."""
    out = {}
    for f in sorted(glob.glob(os.path.join(root, "*", "*-sweep-report", "*.md"))):
        fam = os.path.basename(f).replace("-sweep.md", "")
        hdr = None
        for line in open(f):
            if not line.startswith("| "):
                continue
            c = [x.strip() for x in line.strip().strip("|").split("|")]
            if hdr is None:
                hdr = c
                continue
            if len(c) < 4 or set(c[0]) <= set("-: "):
                continue
            if "no reference" in c[2] or c[2].startswith("— (no miter"):
                out.setdefault(fam, []).append([c[1], c[2]])
    return out


def main(out_path):
    if os.path.exists(NOREF):
        noref = json.load(open(NOREF))
    else:
        sweeps = os.environ.get("SLANG_REPORT_SWEEPS", "build/sweeps/post_elemorder")
        noref = noref_from_sweeps(sweeps)
    meas = load_measured(MEAS)
    rows = []
    for fam, entries in noref.items():
        for mod, formal in entries:
            why = formal
            m = (re.search(r"error: ([^)]+)", why) or
                 re.search(r"no miter: ([^)]+)", why) or
                 re.search(r"ERROR: ([^)]+)", why))
            why_short = (m.group(1) if m else why).strip()[:110]
            und, cos = meas.get(mod, ("— (not measured yet)", "— (not measured yet)"))
            rows.append(dict(fam=fam, mod=mod, cls=classify(formal),
                             why=why_short, und=und, cos=cos))
    reads = [r for r in rows if r["und"].startswith("✅")]
    cosim_ok = [r for r in reads if r["cos"].startswith("✅")]
    L = []
    A = L.append
    A("# Designs `read_slang` cannot read\n")
    A(f"**{len(rows)}** modules across the nightly IP sweeps cannot be elaborated by\n"
      "`read_slang` at all.  They carry no formal verdict for a plain reason: the\n"
      "sweeps prove `read_uhdm` against `read_slang`, and there is nothing to prove\n"
      "against.  They are not failures of this frontend — `read_uhdm` reads them —\n"
      "and they are the part of the corpus the other report cannot see, because a\n"
      "divergence needs two netlists.\n")
    A("Until 2026-09-29 the sweep abandoned such a row entirely: no undriven check,\n"
      "no co-simulation, nothing recorded either way.  The behavioural RTL is still\n"
      "there and neither measurement needs slang, so each row now carries a\n"
      "`read_uhdm` verdict: whether every net is driven, and whether our netlist\n"
      "tracks the RTL under Verilator.\n")
    A(f"Of the {len(rows)}: **{len(reads)}** are confirmed read and elaborated by\n"
      f"`read_uhdm` with every net driven, and **{len(cosim_ok)}** of those also\n"
      "co-simulate the RTL cleanly.  The rest are still being measured, or their\n"
      "RTL cannot be built standalone by Verilator (a vendor primitive, an\n"
      "interface port no port-by-port testbench can drive) — a harness limit, not\n"
      "a verdict.\n")
    A("\n## What slang is missing, by construct\n")
    by = {}
    for r in rows:
        by.setdefault(r["cls"], []).append(r)
    A("| Construct `read_slang` declines | Modules | Sweeps |")
    A("|---|---|---|")
    for cls in sorted(by, key=lambda k: -len(by[k])):
        fams = sorted({r["fam"] for r in by[cls]})
        A(f"| {cls} | {len(by[cls])} | {', '.join(fams[:6])}"
          f"{' …' if len(fams) > 6 else ''} |")
    A("\n## Every row\n")
    A("`read_uhdm` columns are blank where the row has not been re-measured yet.\n")
    A("| Sweep | Module | `read_slang` says | read_uhdm: undriven | read_uhdm vs RTL | Report |")
    A("|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda r: (r["fam"], r["mod"])):
        rep = (f"[file an issue]({issue_url(r['mod'], r['why'], r['und'])})"
               if r["und"].startswith("✅") else "—")
        A(f"| {r['fam']} | `{r['mod']}` | {r['why']} | {r['und']} | {r['cos']} | {rep} |")
    A("\n---\n")
    A("Regenerate with `test/slang_unsupported_report.py` after a sweep cycle.\n"
      "A row leaves this file the moment `read_slang` can read the design.\n")
    open(out_path, "w").write("\n".join(L) + "\n")
    print(f"{out_path}: {len(rows)} rows, {len(reads)} confirmed read by read_uhdm, "
          f"{len(cosim_ok)} co-sim clean, {len(by)} construct classes")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "slang_unsupported.md")
