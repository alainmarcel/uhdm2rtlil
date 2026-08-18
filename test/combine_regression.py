#!/usr/bin/env python3
"""Merge sharded regression results into one full report.

A complete regression (internal + upstream-Yosys + CVA6 equivalence) does not
fit one CI runner's time budget, so CI runs `run_all_tests.sh --all --shard i/N
--results-file <f>` on N runners and merges the dumps here.  The report carries
every category the single-process run reports — passes, UHDM-only successes,
formal (Induct- and Miter-Formal) differences, crashes, Verilator sim-equiv
warnings/analysed/artefact/unclassified, and the CVA6 per-module verdicts — so
nothing is lost by sharding.

Usage: combine_regression.py <results-file|dir> [...]
       combine_regression.py --expected-shards N <...>
"""
import sys, os, collections

COUNTS = [
    "TOTAL_TESTS", "PASSED_TESTS", "FAILED_TESTS", "SKIPPED_TESTS",
    "CRASHED_TESTS", "UHDM_ONLY_TESTS", "YOSYS_TOTAL", "YOSYS_PASSED",
    "YOSYS_FAILED", "YOSYS_SKIPPED", "YOSYS_UHDM_ONLY", "EQUIV_FAILED_TESTS",
    "MITER_FAILED_TESTS", "SIM_EQUIV_WARN_TESTS", "SIM_EQUIV_KNOWN_WARN_TESTS",
    "SIM_EQUIV_ANALYZED_TESTS", "SIM_EQUIV_ARTEFACT_TESTS",
    "SIM_EQUIV_UNCLASS_TESTS", "SLANG_MITER_RUN", "SLANG_MITER_FAILED_TESTS", "SLANG_MITER_KNOWN_FAIL",
]

def collect(paths):
    counts = collections.Counter()
    lists = collections.defaultdict(list)
    cva6 = {}
    files = []
    for p in paths:
        if os.path.isdir(p):
            for root, _, fs in os.walk(p):
                files += [os.path.join(root, f) for f in fs]
        else:
            files.append(p)
    used = 0
    for f in files:
        try:
            body = open(f, errors="replace").read()
        except (IsADirectoryError, OSError):
            continue
        if "count TOTAL_TESTS" not in body:
            continue
        used += 1
        for line in body.splitlines():
            fld = line.split(None, 3)
            if not fld:
                continue
            if fld[0] == "count" and len(fld) >= 3:
                try:
                    counts[fld[1]] += int(fld[2])
                except ValueError:
                    pass
            elif fld[0] == "list" and len(fld) >= 3:
                lists[fld[1]].append(fld[2])
            elif fld[0] == "cva6" and len(fld) >= 4:
                rest = fld[3].split()
                got = rest[0] if rest else "?"
                want = rest[1] if len(rest) > 1 else got
                cva6[fld[2]] = (fld[1], got, want)
    return counts, lists, cva6, used

def section(title):
    print("")
    print(title)

def names(lists, key, limit=None):
    v = sorted(set(lists.get(key, [])))
    if limit and len(v) > limit:
        return v[:limit] + [f"... and {len(v) - limit} more"]
    return v

def main():
    argv = sys.argv[1:]
    expected = None
    if argv and argv[0] == "--expected-shards":
        expected = int(argv[1]); argv = argv[2:]
    if not argv:
        print(__doc__); return 2

    counts, lists, cva6, used = collect(argv)
    if not used:
        print("no shard result files found"); return 1

    total   = counts["TOTAL_TESTS"]
    passed  = counts["PASSED_TESTS"]
    uhdm    = counts["UHDM_ONLY_TESTS"]
    induct  = counts["EQUIV_FAILED_TESTS"]
    miter   = counts["MITER_FAILED_TESTS"]
    failed  = counts["FAILED_TESTS"]
    crashed = counts["CRASHED_TESTS"]
    functional = passed + uhdm

    print("=" * 66)
    print("=== COMBINED REGRESSION REPORT (sharded) ===")
    print("=" * 66)
    print(f"  shard result files merged : {used}" +
          (f" / {expected}" if expected else ""))

    section("📊 OVERALL STATISTICS:")
    print(f"  Total tests run: {total}")
    print(f"  ✅ Passing tests: {passed}")
    print(f"  🚀 UHDM-only success: {uhdm}")
    print(f"  ❌ Equivalence failures: {induct + miter}")
    if induct + miter:
        print(f"      ├─ Induct-Formal (equiv_induct caught): {induct}")
        print(f"      └─ Miter-Formal (UHDM != Verilog, equiv_induct missed): {miter}")
        for t in names(lists, "MITER_FAILED_TEST_NAMES"):
            print(f"          - {t}")
    if counts["SLANG_MITER_RUN"]:
        ok = (counts["SLANG_MITER_RUN"] - counts["SLANG_MITER_FAILED_TESTS"]
              - counts["SLANG_MITER_KNOWN_FAIL"])
        print(f"  🔷 Slang-Miter (read_uhdm == read_slang): "
              f"{ok}/{counts['SLANG_MITER_RUN']} passed, "
              f"{counts['SLANG_MITER_KNOWN_FAIL']} known-fail, "
              f"{counts['SLANG_MITER_FAILED_TESTS']} unexpected")
        for t_ in names(lists, "SLANG_MITER_FAILED_TEST_NAMES"):
            print(f"      - {t_}")
    print(f"  ❌ True failures: {failed}")
    print(f"  💥 Crashes: {crashed}")
    if total:
        print(f"  🎯 Functional: {functional}/{total} "
              f"({round(100 * functional / total)}%)")

    section("🔬 VERILATOR SIM-EQUIV:")
    print(f"  ⚠️  NEW warnings (not in baseline): {counts['SIM_EQUIV_WARN_TESTS']}")
    for t in names(lists, "SIM_EQUIV_WARN_NAMES"):
        print(f"      - {t}")
    print(f"  ⚠️  KNOWN warnings (baselined backlog): {counts['SIM_EQUIV_KNOWN_WARN_TESTS']}")
    print(f"  🔍 Analyzed non-bug divergences: {counts['SIM_EQUIV_ANALYZED_TESTS']}")
    print(f"  🔬 Sim/synth artefacts (miter: UHDM==Verilog): {counts['SIM_EQUIV_ARTEFACT_TESTS']}")
    print(f"  ❓ Unclassified (miter inconclusive): {counts['SIM_EQUIV_UNCLASS_TESTS']}")
    for t in names(lists, "SIM_EQUIV_UNCLASS_NAMES"):
        print(f"      - {t}")

    # The YOSYS_* counters are legacy: classify_test_outcome buckets upstream
    # tests into the SHARED counters, so they stay 0 and the section read as
    # "no Yosys coverage" even on runs that exercised all ~545.  Derive the
    # split from the `run/` prefix the upstream tests carry instead.
    def _split(key):
        v = names(lists, key)
        return sum(1 for x in v if x.startswith("run/"))
    y_pass, y_uhdm = _split("PASSED_TEST_NAMES"), _split("UHDM_ONLY_TEST_NAMES")
    y_fail, y_crash = _split("FAILED_TEST_NAMES"), _split("CRASHED_TEST_NAMES")
    if y_pass or y_uhdm or y_fail:
        section("🧩 UPSTREAM YOSYS SUITE (tests under run/):")
        print(f"  passing {y_pass}, UHDM-only {y_uhdm}, failing {y_fail}, "
              f"crashes {y_crash}")
        print(f"  internal: passing {passed - y_pass}, UHDM-only {uhdm - y_uhdm}")

    cva6_bad = []
    if cva6:
        kinds = collections.Counter(k for k, _, _ in cva6.values())
        status = collections.Counter(g for _, g, _ in cva6.values())
        section("🧪 CVA6 PER-MODULE EQUIVALENCE:")
        print(f"  modules: {len(cva6)}  "
              + "  ".join(f"{s}={status[s]}" for s in
                          ("proven", "cex", "timeout", "crash", "error",
                           "elabfail") if status.get(s)))
        print(f"  as expected {kinds.get('OK',0)}, regressions {kinds.get('BAD',0)}, "
              f"newly proven {kinds.get('PROMOTE',0)}, inconclusive {kinds.get('SOFT',0)}")
        for m, (k, got, want) in sorted(cva6.items()):
            if k == "PROMOTE":
                print(f"      ⬆  {m}: now proven (manifest says {want})")
            elif k == "BAD":
                cva6_bad.append(m)
                print(f"      ❌ {m}: got={got} want={want}")

    unexpected = names(lists, "UNEXPECTED_FAILURES")
    if unexpected:
        section("❌ UNEXPECTED FAILURES:")
        for t in unexpected:
            print(f"      - {t}")

    crashes = names(lists, "CRASHED_TEST_NAMES")
    if crashes:
        section("💥 CRASHES (documented ones are expected — see failing_tests.txt):")
        for t in crashes:
            print(f"      - {t}")

    print("")
    print("=" * 66)
    # A crash is only a regression if it is UNEXPECTED.  The single-process
    # runner already decides that (it checks failing_tests.txt and puts
    # anything undocumented in UNEXPECTED_FAILURES), and it passes with a
    # documented crash — memories/wide_all segfaults Yosys v0.67's own `synth`,
    # which is not a UHDM bug.  Counting raw crashes here made this gate
    # stricter than the reference and failed an otherwise clean run.
    bad = bool(unexpected) or miter > 0 or cva6_bad
    if expected and used < expected:
        print(f"⚠️  PARTIAL: only {used} of {expected} shards reported — a shard "
              f"was likely killed; counts above are incomplete.")
    if bad:
        why = []
        if miter:      why.append(f"{miter} Miter-Formal")
        if unexpected: why.append(f"{len(unexpected)} unexpected failures")

        if cva6_bad:   why.append(f"{len(cva6_bad)} CVA6 regressions")
        print("❌ REGRESSION SUITE FAILED — " + ", ".join(why))
        return 1
    print("✅ REGRESSION SUITE PASSED — no unexpected failures, "
          "no Miter-Formal escapes, no CVA6 regressions")
    return 0

if __name__ == "__main__":
    sys.exit(main())
