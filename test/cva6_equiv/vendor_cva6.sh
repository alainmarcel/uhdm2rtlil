#!/usr/bin/env bash
# Re-vendor the CVA6 RTL under rtl/ from an upstream checkout.
#
# The equivalence flow must keep working as CVA6 evolves, so the vendored tree
# is a refreshable copy rather than a one-off dump:
#
#     ./vendor_cva6.sh ~/cva6 [flist]
#
# <checkout>  a CVA6 working tree (openhwgroup/cva6, submodules initialised).
# [flist]     a file list naming every source + `+incdir+` the design needs.
#             Defaults to <checkout>/cva6_build/cva6_combined.flist, which is
#             what CVA6's own build emits; any equivalent list works.
#
# Copies exactly the sources the flist names, plus every header under its
# include directories, rewrites the paths to the __CVA6_RTL__ placeholder that
# run_cva6_equiv.sh substitutes, and records the upstream revision in
# CVA6_VERSION.  Re-run it to move to a newer CVA6, then re-run the suite and
# update cva6_modules.txt for anything whose status changed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:?usage: vendor_cva6.sh <cva6-checkout> [flist]}"
SRC="$(cd "$SRC" && pwd)"
FLIST="${2:-$SRC/cva6_build/cva6_combined.flist}"
[ -f "$FLIST" ] || { echo "flist not found: $FLIST"; exit 1; }

rm -rf "$HERE/rtl"
python3 - "$SRC" "$FLIST" "$HERE" <<'PY'
import os, shutil, sys
src, flist, here = sys.argv[1], sys.argv[2], sys.argv[3]
dst = os.path.join(here, "rtl")
files, incs = [], []
for l in open(flist):
    l = l.strip()
    if not l: continue
    if l.startswith("+incdir+"): incs.append(l[len("+incdir+"):])
    elif not l.startswith(("+", "-")): files.append(l)

def rel(p):
    p, r = os.path.realpath(p), os.path.realpath(src)
    if not p.startswith(r):
        raise SystemExit(f"outside the checkout, cannot vendor: {p}")
    return p[len(r) + 1:]

n = 0
for f in files:
    d = os.path.join(dst, rel(f))
    os.makedirs(os.path.dirname(d), exist_ok=True)
    shutil.copy2(f, d); n += 1
m = 0
for i in incs:
    for root, _, fs in os.walk(i):
        for fn in fs:
            if fn.endswith((".sv", ".svh", ".vh", ".v")):
                s = os.path.join(root, fn)
                d = os.path.join(dst, rel(s))
                if os.path.exists(d): continue
                os.makedirs(os.path.dirname(d), exist_ok=True)
                shutil.copy2(s, d); m += 1
with open(os.path.join(here, "cva6.flist"), "w") as fh:
    for i in incs: fh.write(f"+incdir+__CVA6_RTL__/{rel(i)}\n")
    for f in files: fh.write(f"__CVA6_RTL__/{rel(f)}\n")
print(f"vendored {n} sources + {m} headers")
PY

{
  echo "# CVA6 RTL vendored under rtl/ — refresh with ./vendor_cva6.sh <checkout>"
  echo "upstream: $(git -C "$SRC" remote get-url origin 2>/dev/null || echo unknown)"
  echo "revision: $(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "describe: $(git -C "$SRC" describe --tags --always 2>/dev/null || echo unknown)"
  echo "date:     $(git -C "$SRC" log -1 --format=%cd --date=short 2>/dev/null || echo unknown)"
  echo "vendored: $(date -u +%Y-%m-%d)"
} > "$HERE/CVA6_VERSION"
cat "$HERE/CVA6_VERSION"
