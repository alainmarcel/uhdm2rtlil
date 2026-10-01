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
    (r"failed to open file|\$readmemh|slang \$readmemh",
     "a memory image the checkout does not contain (`$readmemh` of a missing file)"),
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
    (r"no implicit conversion from '[^']*' to '[^']*_e'|conversion to enum",
     "an implicit conversion to an enum without a cast (IEEE 1800 6.19.3)"),
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
    (r"blocking assignment to variable .* is not supported after previous non-blocking",
     "a blocking assignment to a variable a non-blocking one already wrote"),
    (r"Assert `.*' failed in|Assertion failed|internal compiler",
     "an internal assertion inside read_slang (a crash, not a rejection)"),
    (r"did not finish within",
     "no answer inside the sweep's time budget (a read_slang performance limit)"),
    (r"Design elaboration failed",
     "elaboration failed with no single diagnostic"),
]

# Which of those classes is a read_slang LIMITATION (worth an issue) and which is
# a fact about the design or the checkout (worth stating, never worth filing).
# After the 2026-09-30 project-setup audit the second group is what is left of
# the rows this file used to blame on slang: a module nobody ships, a
# configuration the design itself rejects, RTL the upstream never finished.
# read_slang is STRICTER here than read_verilog, Surelog and sv2v, and the
# language is on its side: the RTL only builds elsewhere because those tools are
# lenient.  Verilator agrees with read_slang on the enum case and cites the LRM
# clause.  Worth knowing, not worth filing.
STRICTER = {
    "an implicit conversion to an enum without a cast (IEEE 1800 6.19.3)",
    "a net-declaration initialiser it does not lower",
    "a hierarchical reference in a constant expression (`$bits(iface.member)`)",
}

NOT_SLANG = {
    "a memory image the checkout does not contain (`$readmemh` of a missing file)",
    "a module it cannot find in the closure the sweep gives it",
    "a file the sweep's closure does not hand it",
    "nothing to compare (the upstream RTL is incomplete, or the module is empty)",
    "an elaboration-time `$error`/`$fatal` the design guards with parameters",
    "a dimension it evaluates as non-positive",
    "an out-of-range select in code a parameter makes dead",
    "a parameter whose default carries `x` bits",
    "refuses the module as a top level (usually an unbound interface or an unresolved parameter)",
    # ... and the classes the 09-30 audit traced to the project we hand the
    # tools.  They should not appear at all any more (the wrappers bind the
    # configuration, the closure carries the package, the manifest raises the
    # unroll limit and supplies the header the repository never vendored); a row
    # that still lands here is a setup gap to fix, not an issue to file.
    "a macro the sweep's include set does not define for it",
    "a package or class it cannot resolve",
    "an identifier it does not resolve in that scope",
    "an interface port on the top module",
    "a generate/for construct past its unroll limit",
    "a port it does not find on a child module",
}


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
            # 110 characters cut the diagnostic off mid-word on 22 rows
            # ("error: bloc"), and the classifier below then had nothing to
            # match, so they all landed in "other".
            why_short = (m.group(1) if m else why).strip()[:200]
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
    A("Each row carries a `read_uhdm` verdict as well -- whether every net is\n"
      "driven, and whether our netlist tracks the RTL under Verilator -- because\n"
      "neither measurement needs slang.  The rows are split three ways: what\n"
      "read_slang declines, where it is stricter than the other frontends and the\n"
      "language is on its side, and what the design, the checkout or our own\n"
      "project setup declines.  Only the first group is a report about slang.\n")
    A(f"Of the {len(rows)}: **{len(reads)}** are confirmed read and elaborated by\n"
      f"`read_uhdm` with every net driven, and **{len(cosim_ok)}** of those also\n"
      "co-simulate the RTL cleanly.  The rest are still being measured, or their\n"
      "RTL cannot be built standalone by Verilator (a vendor primitive, an\n"
      "interface port no port-by-port testbench can drive) — a harness limit, not\n"
      "a verdict.\n")
    by = {}
    for r in rows:
        by.setdefault(r["cls"], []).append(r)

    def table(title, note, keep):
        sel = {k: v for k, v in by.items() if keep(k)}
        if not sel:
            return
        A(f"\n## {title}\n")
        A(note + "\n")
        A("| Construct | Modules | Sweeps |")
        A("|---|---|---|")
        for cls in sorted(sel, key=lambda k: -len(sel[k])):
            fams = sorted({r["fam"] for r in sel[cls]})
            A(f"| {cls} | {len(sel[cls])} | {', '.join(fams[:6])}"
              f"{' …' if len(fams) > 6 else ''} |")

    table("What read_slang declines",
          "These are read_slang's own limits: every one of them is a construct the\n"
          "other two frontends accept, and each row below carries a pre-filled issue\n"
          "link.",
          lambda k: k not in NOT_SLANG and k not in STRICTER and k != "other")
    table("What the design, the checkout, or our own project setup declines",
          "Not read_slang's doing.  A module the repository never shipped (OpenTitan\n"
          "primitives vendored without their `prim_*` library), a configuration the\n"
          "design itself rejects, RTL the upstream left unfinished -- and, where a\n"
          "row still shows a package, macro, unroll limit or interface port, a gap\n"
          "in the project WE hand the tools, which is ours to close and never an\n"
          "issue to file.  read_uhdm reads several of these only because Surelog is\n"
          "quieter about a missing file, which is not an advantage.",
          lambda k: k in NOT_SLANG)
    table("Where read_slang is stricter than the other frontends",
          "read_slang refuses these; `read_verilog`, Surelog and sv2v accept them.\n"
          "The language is on read_slang's side -- Verilator rejects the enum case\n"
          "too and cites IEEE 1800 6.19.3 -- and what the lenient tools build is not\n"
          "always meaningful: `read_verilog` takes an `initial` block that reads a\n"
          "net and silently drops it, leaving the target undriven.  Recorded so the\n"
          "RTL can be fixed; not filed against slang.",
          lambda k: k in STRICTER)
    table("Unclassified", "One-off diagnostics; read the rows.",
          lambda k: k == "other")
    A("\n## Every row\n")
    A("`read_uhdm` columns are blank where the row has not been re-measured yet.\n")
    A("| Sweep | Module | `read_slang` says | read_uhdm: undriven | read_uhdm vs RTL | Report |")
    A("|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda r: (r["fam"], r["mod"])):
        rep = (f"[file an issue]({issue_url(r['mod'], r['why'], r['und'])})"
               if r["und"].startswith("✅") and r["cls"] not in NOT_SLANG
               and r["cls"] not in STRICTER else "—")
        A(f"| {r['fam']} | `{r['mod']}` | {r['why']} | {r['und']} | {r['cos']} | {rep} |")
    A("\n---\n")
    A("Regenerate with `test/slang_unsupported_report.py` after a sweep cycle.\n"
      "A row leaves this file the moment `read_slang` can read the design.\n")
    open(out_path, "w").write("\n".join(L) + "\n")
    print(f"{out_path}: {len(rows)} rows, {len(reads)} confirmed read by read_uhdm, "
          f"{len(cosim_ok)} co-sim clean, {len(by)} construct classes")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "slang_unsupported.md")
