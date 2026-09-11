#!/usr/bin/env python3
"""Generate per-module tests for an imported multi-file SystemVerilog design.

Reusable across imported examples (rp32, ...).  Given a shared RTL subdir
(e.g. test/rp32/) it:

  1. scans every *.sv for `module`/`package` declarations and `import pkg::*`
     statements (packages and modules alike),
  2. builds the package dependency graph and, for each synthesizable module,
     resolves the transitive set of package files in topological order
     (packages a module/package depends on come first),
  3. writes one test dir `<test_root>/<prefix>_<module>/` containing a
     `project.f` that lists the ordered package files + the module file (paths
     relative to the test dir, into the shared subdir) plus a `# top:` directive
     and any per-design defines / verilator flags.

Modules whose imports cannot be resolved to a file in the design (external
packages such as a TCB submodule) are SKIPPED and reported, so the generated
set only contains modules that can be elaborated from the design itself.

Usage:
  import_design.py --design test/rp32 --prefix rp32 [--define NAME ...]
                   [--skip-glob '*__xilinx_xpm*' ...] [--verilator '-Wno-...']
"""
from __future__ import annotations
import argparse
import fnmatch
import re
import sys
from pathlib import Path

PKG_RE = re.compile(r"^\s*package\s+([A-Za-z_]\w*)", re.M)
MOD_RE = re.compile(r"^\s*module\s+([A-Za-z_]\w*)", re.M)
IMPORT_RE = re.compile(r"\bimport\s+([A-Za-z_]\w*)\s*::")
# A `pkg::name` scope reference (e.g. `prim_util_pkg::vbits(...)`) is also a
# package dependency even without an explicit `import pkg::*`.
SCOPE_RE = re.compile(r"\b([A-Za-z_]\w*)\s*::")
LINE_COMMENT_RE = re.compile(r"//[^\n]*")
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)


def strip_comments(text: str) -> str:
    return BLOCK_COMMENT_RE.sub("", LINE_COMMENT_RE.sub("", text))


def resolve_modules(top: str, mod2file: dict, mod_text: dict):
    """Transitive set of submodule NAMES `top` instantiates (incl. `top`).

    A module N (from the design's known modules) is treated as instantiated by M
    when its name appears as a whole word in M's comment-stripped source — for
    these designs module names are distinctive (`ibex_*` / `prim_*`) and appear
    only as instantiations, never as types, so this is reliable and, if it ever
    over-includes, an unused extra module file is harmless for elaboration."""
    names = set(mod2file)
    closure: set[str] = set()

    def visit(m: str):
        if m in closure or m not in mod2file:
            return
        closure.add(m)
        t = mod_text[mod2file[m]]
        for n in names:
            if n != m and re.search(r"\b" + re.escape(n) + r"\b", t):
                visit(n)

    visit(top)
    return closure


def scan(design: Path):
    """Return (pkg2file, mod2file, deps, mod_text) for the design.

    `mod_text` maps each source file to its comment-stripped text, used for the
    module-instantiation closure."""
    pkg2file: dict[str, Path] = {}
    mod2file: dict[str, Path] = {}
    deps: dict[str, set[str]] = {}        # pkg/mod name -> dependent pkg names
    scope_refs: dict[str, set[str]] = {}  # pkg/mod name -> `X::`-referenced names
    mod_text: dict[Path, str] = {}
    for f in sorted(design.rglob("*.sv")):
        text = f.read_text(errors="replace")
        stripped = strip_comments(text)
        # Package deps come from BOTH `import pkg::*` and `pkg::name` scope refs
        # (a wildcard import is not required to use a package function/type).
        refs = set(IMPORT_RE.findall(text)) | set(SCOPE_RE.findall(stripped))
        for pkg in PKG_RE.findall(text):
            pkg2file[pkg] = f
            scope_refs[pkg] = refs - {pkg}
        mods = MOD_RE.findall(text)
        if mods:
            mod_text[f] = stripped
        for mod in mods:
            mod2file[mod] = f
            scope_refs.setdefault(mod, set())
            scope_refs[mod] |= refs
    # Keep only the references that resolve to a package in the design; a `X::`
    # to a class/enum/typedef scope is not a package dependency.
    for name, refs in scope_refs.items():
        deps[name] = {r for r in refs if r in pkg2file and r != name}
    return pkg2file, mod2file, deps, mod_text


def resolve_packages(name: str, pkg2file: dict, deps: dict):
    """Topologically ordered list of package files `name` (transitively) needs.

    Returns (ordered_pkg_files, missing) where `missing` is the set of imported
    package names with no file in the design (external deps)."""
    ordered: list[str] = []          # package names, deps-first
    seen: set[str] = set()
    missing: set[str] = set()

    def visit(pkg: str):
        if pkg in seen:
            return
        seen.add(pkg)
        if pkg not in pkg2file:
            missing.add(pkg)
            return
        for dep in sorted(deps.get(pkg, ())):
            visit(dep)
        ordered.append(pkg)

    for imp in sorted(deps.get(name, ())):
        visit(imp)
    files = [pkg2file[p] for p in ordered if p in pkg2file]
    return files, missing


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--design", required=True, help="shared RTL dir, e.g. test/rp32")
    ap.add_argument("--prefix", required=True, help="test-name prefix, e.g. rp32")
    ap.add_argument("--test-root", default="test", help="where to write <prefix>_<mod>/ dirs")
    ap.add_argument("--define", action="append", default=[], help="surelog +define passed to every test")
    ap.add_argument("--module-define", action="append", default=[],
                    metavar="MOD:DEF",
                    help="extra -D DEF only for module MOD (e.g. "
                    "ibex_top_tracing:RVFI); repeatable")
    ap.add_argument("--incdir", action="append", default=[], help="+incdir path (relative to test/) added to every test")
    ap.add_argument("--verilator", default="", help="per-test '# verilator:' flags")
    ap.add_argument("--mode", default="", help="project.f '# mode:' (e.g. uhdm-only)")
    ap.add_argument("--skip-glob", action="append", default=[], help="glob of files to skip as module sources")
    ap.add_argument("--only", action="append", default=[], help="only generate these module names")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    design = Path(args.design)
    test_root = Path(args.test_root)
    if not design.is_dir():
        sys.exit(f"design dir not found: {design}")

    pkg2file, mod2file, deps, mod_text = scan(design)
    print(f"scanned {design}: {len(pkg2file)} packages, {len(mod2file)} modules")

    # Per-module extra defines (MOD:DEF), e.g. ibex_top_tracing needs `RVFI`.
    module_defines: dict[str, list[str]] = {}
    for md in args.module_define:
        mod_name, _, dfn = md.partition(":")
        module_defines.setdefault(mod_name, []).append(dfn)

    generated, skipped = [], []
    for mod, mfile in sorted(mod2file.items()):
        if args.only and mod not in args.only:
            continue
        rel = str(mfile)
        if any(fnmatch.fnmatch(rel, g) for g in args.skip_glob):
            skipped.append((mod, "skip-glob"))
            continue
        # Transitive submodule closure so a PARENT module (ibex_core, ibex_top,
        # ...) lists the RTL of everything it instantiates and can elaborate
        # standalone — otherwise every child is a blackbox and no miter/co-sim
        # can run.  A leaf module's closure is just itself (unchanged output).
        closure = resolve_modules(mod, mod2file, mod_text)
        # Packages needed by ANY module in the closure, deps-first (union across
        # the whole closure, de-duped, topologically ordered).
        pkg_files, missing = [], set()
        seen_pf: set[str] = set()
        for cm in sorted(closure):
            cpf, cmiss = resolve_packages(cm, pkg2file, deps)
            missing |= cmiss
            for pf in cpf:
                if str(pf) not in seen_pf:
                    seen_pf.add(str(pf))
                    pkg_files.append(pf)
        if missing:
            skipped.append((mod, f"external pkgs: {','.join(sorted(missing))}"))
            continue
        # Module files of the whole closure (order among modules is irrelevant
        # for elaboration; the top's own file is included via the closure).
        # NOTE: --skip-glob is intentionally NOT applied here — it only excludes
        # a file from being a test TOP (the loop above), while the prim* library
        # it skips as a top must still be pulled in as a submodule DEPENDENCY.
        mod_files, seen_mf = [], set()
        for cm in sorted(closure):
            cf = mod2file[cm]
            if str(cf) not in seen_mf:
                seen_mf.add(str(cf))
                mod_files.append(cf)
        # Don't double-prefix when the module already starts with the prefix
        # (Ibex modules are all `ibex_*`, so `ibex_alu` stays `ibex_alu`, not
        # `ibex_ibex_alu`; rp32's `r5p_alu` still becomes `rp32_r5p_alu`).
        test_name = mod if mod.startswith(args.prefix + "_") else f"{args.prefix}_{mod}"
        test_dir = test_root / test_name
        # project.f paths are relative to the test dir: packages first (ordered),
        # then the module + all its instantiated submodules.
        srcs = pkg_files + mod_files
        lines = [
            f"# {args.prefix} {mod} — generated by import_design.py from {design}.",
            f"# Ordered package deps + the module; shared RTL in ../{design.name}/.",
            f"# top: {mod}",
        ]
        if args.mode:
            lines.append(f"# mode: {args.mode}")
        # Combine all -D defines and +incdir paths into ONE `# surelog:` line —
        # project_files.sh keeps only the LAST such directive, so several lines
        # would clobber each other.  incdir paths are relative to the test dir
        # (../<path>), matching the source-file convention below.
        # Use Surelog's -I<dir> for include dirs (its `+incdir+` handling mis-parses
        # a relative `../`-path here, treating it as a source file).
        inc_flags = [f"-I../{i}" for i in args.incdir]
        mdefs = args.define + module_defines.get(mod, [])
        sl_flags = [f"-D{d}" for d in mdefs] + inc_flags
        if sl_flags:
            lines.append(f"# surelog: {' '.join(sl_flags)}")
        # The same defines must reach Verilator (`+define+`) so the co-sim RTL
        # elaborates identically (ibex_top_tracing fatals without `RVFI`).
        vflags = [f"+define+{d}" for d in mdefs]
        if args.verilator:
            vflags.append(args.verilator)
        if vflags:
            lines.append(f"# verilator: {' '.join(vflags)}")
        # read_slang needs the same include dirs and defines (its miter is what
        # turns a parent module's "no miter" into a real comparison);
        # --ignore-assertions drops the SVA the structural comparison ignores.
        if inc_flags or mdefs:
            slang_flags = ["--ignore-assertions"] + \
                [f"-D{d}" for d in mdefs] + inc_flags
            lines.append(f"# slang: {' '.join(slang_flags)}")
        lines.append("")
        for s in srcs:
            lines.append(f"../{Path(*s.parts[1:])}")  # strip leading 'test/'
        content = "\n".join(lines) + "\n"
        if args.dry_run:
            print(f"--- {test_dir}/project.f ---\n{content}")
        else:
            test_dir.mkdir(parents=True, exist_ok=True)
            (test_dir / "project.f").write_text(content)
        generated.append(mod)

    print(f"\ngenerated {len(generated)} tests: {', '.join(generated)}")
    if skipped:
        print(f"\nskipped {len(skipped)}:")
        for mod, why in skipped:
            print(f"  {mod}: {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
