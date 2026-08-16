#!/usr/bin/env python3
"""Merge per-shard CVA6 equivalence results into the final report.

Each shard writes the result file produced by `run_cva6_equiv.sh --results`;
this merges them, prints the summary, and exits non-zero only on a genuine
correctness regression (same policy as the runner: a counterexample where none
was expected, or a module we prove today failing to elaborate).

Usage: combine_report.py <results-file|dir> [...]
"""
import sys, os, collections

def load(paths):
    rows = {}
    for p in paths:
        files = []
        if os.path.isdir(p):
            for root, _, fs in os.walk(p):
                files += [os.path.join(root, f) for f in fs]
        else:
            files = [p]
        for f in files:
            try:
                for line in open(f):
                    fld = line.split()
                    if len(fld) < 3:
                        continue
                    kind, mod, got = fld[0], fld[1], fld[2]
                    want = fld[3] if len(fld) > 3 else got
                    rows[mod] = (kind, got, want)
            except (IsADirectoryError, UnicodeDecodeError):
                pass
    return rows

def main():
    if len(sys.argv) < 2:
        print(__doc__); return 2
    rows = load(sys.argv[1:])
    if not rows:
        print("no shard results found"); return 1

    by_kind = collections.Counter(k for k, _, _ in rows.values())
    by_status = collections.Counter(g for _, g, _ in rows.values())

    print("=" * 62)
    print("CVA6 per-module equivalence — combined report")
    print("=" * 62)
    print(f"  modules reported : {len(rows)}")
    print("")
    print("  measured status:")
    for s in ("proven", "cex", "timeout", "elabfail", "skip"):
        if by_status.get(s):
            print(f"    {s:<10} {by_status[s]:>4}")
    print("")
    print(f"  as expected      : {by_kind.get('OK', 0)}")
    print(f"  regressions      : {by_kind.get('BAD', 0)}")
    print(f"  newly proven     : {by_kind.get('PROMOTE', 0)}")
    print(f"  inconclusive     : {by_kind.get('SOFT', 0)}  (SAT budget, not a bug)")
    print(f"  skipped          : {by_kind.get('SKIP', 0)}")

    prom = [m for m, (k, _, _) in sorted(rows.items()) if k == "PROMOTE"]
    if prom:
        print("\n  Newly proven — tighten cva6_modules.txt:")
        for m in prom:
            print(f"    ⬆  {m} (manifest says {rows[m][2]})")

    soft = [m for m, (k, _, _) in sorted(rows.items()) if k == "SOFT"]
    if soft:
        print("\n  Inconclusive (ran out of SAT budget; no counterexample):")
        print("    " + " ".join(soft))

    bad = [m for m, (k, _, _) in sorted(rows.items()) if k == "BAD"]
    if bad:
        print("\n  ❌ REGRESSIONS:")
        for m in bad:
            _, got, want = rows[m]
            print(f"    {m}: got={got} want={want}")
        print("\n❌ CVA6 module equivalence FAILED")
        return 1

    print("\n✅ CVA6 module equivalence: no regressions")
    return 0

if __name__ == "__main__":
    sys.exit(main())
