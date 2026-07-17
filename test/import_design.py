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


def scan(design: Path):
    """Return (pkg2file, pkg_deps, mod2file, mod_imports) for the design."""
    pkg2file: dict[str, Path] = {}
    mod2file: dict[str, Path] = {}
    deps: dict[str, set[str]] = {}        # pkg/mod name -> imported pkg names
    for f in sorted(design.rglob("*.sv")):
        text = f.read_text(errors="replace")
        imports = set(IMPORT_RE.findall(text))
        for pkg in PKG_RE.findall(text):
            pkg2file[pkg] = f
            deps[pkg] = imports - {pkg}
        for mod in MOD_RE.findall(text):
            mod2file[mod] = f
            deps.setdefault(mod, set())
            deps[mod] |= imports
    return pkg2file, mod2file, deps


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

    pkg2file, mod2file, deps = scan(design)
    print(f"scanned {design}: {len(pkg2file)} packages, {len(mod2file)} modules")

    generated, skipped = [], []
    for mod, mfile in sorted(mod2file.items()):
        if args.only and mod not in args.only:
            continue
        rel = str(mfile)
        if any(fnmatch.fnmatch(rel, g) for g in args.skip_glob):
            skipped.append((mod, "skip-glob"))
            continue
        pkg_files, missing = resolve_packages(mod, pkg2file, deps)
        if missing:
            skipped.append((mod, f"external pkgs: {','.join(sorted(missing))}"))
            continue
        # Don't double-prefix when the module already starts with the prefix
        # (Ibex modules are all `ibex_*`, so `ibex_alu` stays `ibex_alu`, not
        # `ibex_ibex_alu`; rp32's `r5p_alu` still becomes `rp32_r5p_alu`).
        test_name = mod if mod.startswith(args.prefix + "_") else f"{args.prefix}_{mod}"
        test_dir = test_root / test_name
        # project.f paths are relative to the test dir.
        srcs = pkg_files + [mfile]
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
        sl_flags = [f"-D{d}" for d in args.define] + \
                   [f"-I../{i}" for i in args.incdir]
        if sl_flags:
            lines.append(f"# surelog: {' '.join(sl_flags)}")
        if args.verilator:
            lines.append(f"# verilator: {args.verilator}")
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
