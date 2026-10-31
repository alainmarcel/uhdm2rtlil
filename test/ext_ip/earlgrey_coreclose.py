#!/usr/bin/env python3
"""Resolve a fusesoc CAPI=2 core's RTL file closure by walking the .core graph.

OpenTitan ships no generated filelist and the local fusesoc is a stale entry
point (its module is gone), so the closure is derived here: .core files are
plain YAML naming `filesets.<fs>.depend` (other cores) and `filesets.<fs>.files`.
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

# A file from ANOTHER top is never part of this top's closure.  Every top
# ships its own `top_pkg` / `top_racl_pkg` under the SAME core leaf name, and
# they genuinely disagree -- earlgrey's TL_AUW is 23, darjeeling's is 28 -- so
# letting one leak in binds `top_pkg::` to the wrong constants.  Surelog
# tolerates the duplicate definition silently; read_slang refuses the closure
# outright ("duplicate definition of 'top_pkg'"), which is how this surfaced.
# Filter on the PATH rather than trusting the role resolution.
other_tops = {d.name for d in (root_dir).glob("top_*") if d.is_dir()} - {top_tag}
def from_other_top(p):
    return any(f"/hw/{o}/" in str(p) or f"/{o}/" == f"/{p.parts[-2]}/" for o in other_tops) \
           or any(o in str(p).split("/hw/")[-1].split("/")[0:1] for o in other_tops)
dropped = [f for f in files if from_other_top(f)]
files = [f for f in files if not from_other_top(f)]
incdirs = {i for i in incdirs if not from_other_top(i)}
for d0 in dropped:
    print(f"#   DROPPED (another top) {d0}", file=sys.stderr)

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
