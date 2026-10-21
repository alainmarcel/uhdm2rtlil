#!/usr/bin/env python3
"""Resolve a fusesoc CAPI=2 core's RTL file closure by walking the .core graph.

    fusesoc_closure.py <hw-dir> <core-name> [technology]

prints `+incdir+` lines followed by the source files, in dependency order --
a file list Surelog, read_slang and Verilator can all take with `-f`.

WHY THIS EXISTS.  OpenTitan ships no generated filelist, only fusesoc `.core`
files, so a chip top cannot be handed to a tool without resolving them.  Running
fusesoc itself is not an option here (the installed launcher is a stale entry
point whose module is gone), and the alternative this repo used -- a
hand-maintained list, `prim_files.txt` -- does not scale past a handful of
primitives: Earlgrey reaches 635 files across 35 IPs.

CAPI=2 cores are plain YAML, so the graph is walkable directly: `name` is
"vendor:library:core:version", `filesets.<fs>.depend` names other cores and
`filesets.<fs>.files` names sources.  Only RTL filesets are followed; dv, lint,
formal and waiver filesets are skipped.

TWO things make the graph resolvable, and both are the whole difficulty:

  * An ABSTRACT core names a role, not an implementation.  `lowrisc:prim:flop`,
    `lowrisc:prim:ram_1p` and `lowrisc:virtual_constants:top_pkg` are bound by
    fusesoc's `--mapping`, so they match no core by name.  Resolve them by LEAF
    NAME, preferring the generic technology library so the closure needs no
    vendor cells (27 of Earlgrey's 34 unresolved cores are this class).

  * A TOP-SPECIFIC package's core leaf only ENDS WITH the role's name:
    `lowrisc:virtual_constants:rnd_cnst_pkg` is implemented by
    `lowrisc:earlgrey_constants:testing_rnd_cnst_pkg`.  Match on the suffix, but
    restrict to cores belonging to the top being resolved -- otherwise another
    top's package (darjeeling, englishbreakfast) is pulled in silently and the
    design elaborates against the wrong constants.

MEASURED on this commit (OpenTitan f49474bc), `lowrisc:systems:top_earlgrey`:
635 files, 2 include directories, 0 unresolved cores.  With `-DSYNTHESIS`
(which compiles out the prim SVA macros, as OpenTitan's own flows do and as
run_opentitan_equiv.sh already passes) Surelog reports 0 syntax and 0 fatal
errors, and read_uhdm reads the whole chip top: exit 0, 14 min, 11.9 GB peak.
Without that define, 9 syntax errors all come from one file -- a comment inside
a multi-line SVA macro argument in prim_assert_standard_macros.svh.
"""
import sys, yaml, pathlib, collections

root_dir = pathlib.Path(sys.argv[1])
want = sys.argv[2]
mapping_prefer = sys.argv[3] if len(sys.argv) > 3 else "prim_generic"
# which top this closure is for -- used to pick that top's own packages
top_tag = want.split(":")[-1]

cores = {}        # "vendor:lib:name" -> (path, data)
for f in root_dir.rglob("*.core"):
    try:
        d = yaml.safe_load(f.read_text())
    except Exception:
        continue
    if not isinstance(d, dict) or "name" not in d:
        continue
    parts = str(d["name"]).split(":")
    key = ":".join(parts[:3])
    cores.setdefault(key, (f, d))

def rtl_filesets(d):
    """The filesets a default/RTL build uses, by name convention."""
    fss = d.get("filesets") or {}
    # Prefer what the default target declares; fall back to every files_rtl*.
    tgts = d.get("targets") or {}
    names = []
    for tname in ("default", "sim", "lint"):
        t = tgts.get(tname)
        if isinstance(t, dict) and t.get("filesets"):
            names = [n for n in t["filesets"]]
            break
    if not names:
        names = [n for n in fss if n.startswith("files_rtl") or n in ("files_dv",)]
    out = []
    for n in names:
        n = n.split("?")[-1].strip() if "?" in str(n) else n
        if n in fss and ("rtl" in n or n == "files_ip" or n.startswith("files_")):
            if "waiver" in n or "dv" in n or "lint" in n or "formal" in n:
                continue
            out.append(n)
    return [fss[n] for n in out if isinstance(fss.get(n), dict)]

seen, missing, files, incdirs = set(), set(), [], set()

def resolve(dep):
    """An ABSTRACT core (`lowrisc:prim:flop`, `lowrisc:virtual_constants:top_pkg`)
    names a role, not an implementation: fusesoc picks one via --mapping.  Pick
    by LEAF NAME, preferring the generic technology library so the closure needs
    no vendor cells, then the top's own autogen'd package."""
    dep = ":".join(str(dep).split(":")[:3])
    if dep in cores: return dep
    leaf = dep.split(":")[-1]
    cands = [k for k in cores if k.split(":")[-1] == leaf]
    if not cands:
        # the prim wrapper is named prim_<leaf> in its own core
        cands = [k for k in cores if k.split(":")[-1] == "prim_" + leaf]
    if not cands:
        # A TOP-SPECIFIC package: the abstract `virtual_constants:rnd_cnst_pkg`
        # is implemented by `earlgrey_constants:testing_rnd_cnst_pkg`, so the
        # core's leaf only ENDS WITH the role's name.  Restrict to this top's
        # own cores so another top's package is never pulled in.
        cands = [k for k in cores if k.split(":")[-1].endswith(leaf)
                 and (top_tag in k or top_tag in str(cores[k][0]))]
    if not cands: return dep
    def rank(k):
        return (0 if mapping_prefer in k else
                1 if "generic" in k else
                2 if "top_earlgrey" in k else 3)
    return sorted(cands, key=rank)[0]

def visit(key):
    key = key.split(":")
    key = ":".join(key[:3])
    if key in seen: return
    seen.add(key)
    ent = cores.get(key)
    if not ent:
        missing.add(key); return
    path, d = ent
    base = path.parent
    for fs in rtl_filesets(d):
        for dep in (fs.get("depend") or []):
            dep = str(dep)
            dep = resolve(dep)
            visit(dep)
        for fl in (fs.get("files") or []):
            name = list(fl)[0] if isinstance(fl, dict) else str(fl)
            p = (base / name).resolve()
            if p.suffix in (".sv", ".v"):
                if p.exists(): files.append(p)
            elif p.suffix in (".svh", ".vh", ".h"):
                if p.exists(): incdirs.add(p.parent)

visit(want)
# packages and headers first; keep order otherwise
print(f"# closure of {want}: {len(files)} files, {len(incdirs)} incdirs, "
      f"{len(missing)} unresolved cores", file=sys.stderr)
for m in sorted(missing):
    print(f"#   UNRESOLVED {m}", file=sys.stderr)
for i in sorted(incdirs):
    print(f"+incdir+{i}")
seenf = set()
for f in files:
    if f not in seenf:
        seenf.add(f); print(f)
