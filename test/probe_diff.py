#!/usr/bin/env python3
"""Name the first INTERNAL signal where the read_uhdm netlist leaves the RTL.

The co-sim only ever reports the OUTPUT that shows a divergence, which on a
large module is many layers downstream of the cause -- cvw's wallypipelinedcore
says `HWSTRB`, snitch's spatz_vfu says `vrf_wbe_o`, and neither says why.  Run
`netlist_cosim.py --probe` to get a VCD of the DUT subtree from each side, then
this: it aligns the three traces by SIGNAL NAME and reports the signals that
diverge EARLIEST, which is where to look.

Name matching.  The netlist is flattened with `-norename`, so an internal wire
is one flat escaped identifier `sub.inner.sig` inside the top module, while the
RTL VCD carries real hierarchy `tb.dut.sub.inner.sig`.  Both reduce to the same
dotted path relative to the dumped DUT scope, which is what we key on.  A
signal present on only one side is reported separately rather than silently
dropped -- a wire the netlist does not have at all is itself a finding.

The `slang` side is the adjudicator: a signal where uhdm differs from the RTL
and slang AGREES with the RTL is ours to fix; one where both differ is a
harness or modelling artefact and is listed apart.

  python3 probe_diff.py <workdir> [--top-only] [--max 40]
"""
import argparse, os, re, sys
from collections import defaultdict


def parse_vcd(path):
    """-> {dotted_name: [(time, value), ...]} for the dumped subtree.

    Values are kept as strings exactly as the VCD spells them (binary without
    the leading `b`), so a width change or an x/z shows up as a difference
    instead of being normalised away.
    """
    ids = {}                 # vcd id -> list of dotted names (an id can alias)
    series = defaultdict(list)
    scope = []
    root = None
    t = 0
    with open(path, errors="replace") as fh:
        in_defs = True
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if in_defs:
                if line.startswith("$scope"):
                    parts = line.split()
                    if len(parts) >= 3:
                        scope.append(parts[2])
                        if root is None:
                            root = len(scope)      # the dumped subtree's depth
                    continue
                if line.startswith("$upscope"):
                    if scope:
                        scope.pop()
                    continue
                if line.startswith("$var"):
                    # $var wire 8 ! name [7:0] $end
                    parts = line.split()
                    if len(parts) >= 5:
                        code, nm = parts[3], parts[4]
                        path_parts = scope[(root - 1):] if root else scope
                        full = ".".join(list(path_parts[1:]) + [nm]) if path_parts else nm
                        ids.setdefault(code, []).append(full.lstrip("."))
                    continue
                if line.startswith("$enddefinitions"):
                    in_defs = False
                    continue
                continue
            if line[0] == "#":
                try:
                    t = int(line[1:])
                except ValueError:
                    pass
                continue
            if line[0] in "bB":
                bits, _, code = line[1:].partition(" ")
                code = code.strip()
                for nm in ids.get(code, ()):
                    series[nm].append((t, bits))
            elif line[0] in "rR":
                continue                       # reals are not compared
            elif line[0] == "$":
                continue
            else:
                val, code = line[0], line[1:].strip()
                for nm in ids.get(code, ()):
                    series[nm].append((t, val))
    return series


def at(seq, time):
    """Value of `seq` at `time` (last change at or before it)."""
    lo, hi, best = 0, len(seq) - 1, None
    while lo <= hi:
        mid = (lo + hi) // 2
        if seq[mid][0] <= time:
            best = seq[mid][1]
            lo = mid + 1
        else:
            hi = mid - 1
    return best


def norm(v):
    """Compare numerically where both sides are clean binary, else textually.

    The two sides can print the same value at different widths (the netlist
    drops leading zeroes a packed RTL struct keeps), and that is not a
    divergence.  An x or z is kept as text so it never compares equal to 0.
    """
    if v is None:
        return None
    if set(v) <= set("01"):
        return v.lstrip("0") or "0"
    return v


def first_divergence(a, b):
    """Earliest time where series a and b differ, or None."""
    times = sorted({t for t, _ in a} | {t for t, _ in b})
    for t in times:
        if norm(at(a, t)) != norm(at(b, t)):
            return t
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("work")
    ap.add_argument("--max", type=int, default=40)
    # -1, not 0: the test below is `t <= settle`, and a divergence AT t=0 is
    # real and common (a reset or initial value that never reaches the netlist).
    # Defaulting to 0 silently hid exactly that case.
    ap.add_argument("--settle", type=int, default=-1,
                    help="ignore divergences at or before this VCD time (reset skew)")
    args = ap.parse_args()
    w = args.work
    paths = {tag: os.path.join(w, f"probe_{tag}.vcd") for tag in ("rtl", "uhdm", "slang")}
    have = {tag: p for tag, p in paths.items() if os.path.exists(p)}
    if "rtl" not in have or "uhdm" not in have:
        print("probe_diff: need at least probe_rtl.vcd and probe_uhdm.vcd in %s" % w)
        print("            run netlist_cosim.py with --probe first")
        return 2
    tr = {}
    for tag, p in have.items():
        tr[tag] = parse_vcd(p)
        print("%-6s %6d signals  (%s, %.1f MB)"
              % (tag, len(tr[tag]), os.path.basename(p), os.path.getsize(p) / 1e6))

    rtl, uhdm = tr["rtl"], tr["uhdm"]
    slang = tr.get("slang")
    common = sorted(set(rtl) & set(uhdm))
    print("\n%d signals matched by name; %d only in RTL, %d only in the uhdm netlist"
          % (len(common), len(set(rtl) - set(uhdm)), len(set(uhdm) - set(rtl))))

    # One cause fans out: an alias of the same wire at two scopes, and every
    # signal downstream of it, all diverge at the same time with the same
    # values.  Group by (rtl series, uhdm series) and report ONE representative
    # per group with a count, so the list names causes rather than symptoms.
    groups = {}
    ours, shared = [], []
    for nm in common:
        t = first_divergence(rtl[nm], uhdm[nm])
        if t is None or t <= args.settle:
            continue
        sl = None
        if slang and nm in slang:
            sl = first_divergence(rtl[nm], slang[nm])
        key = (tuple(rtl[nm]), tuple(uhdm[nm]),
               "slang-clean" if (sl is None or sl > t) else "slang-too")
        prev = groups.get(key)
        # Keep the SHALLOWEST name as the representative: it is the one a
        # reader recognises, and the deeper ones are the same wire re-exported.
        if prev is None or (nm.count("."), len(nm)) < (prev[1].count("."), len(prev[1])):
            groups[key] = (t, nm, norm(at(rtl[nm], t)), norm(at(uhdm[nm], t)), key[2],
                           1 if prev is None else prev[5] + 1)
        else:
            groups[key] = prev[:5] + (prev[5] + 1,)

    for rec in groups.values():
        (ours if rec[4] == "slang-clean" else shared).append(rec)

    def show(title, rows):
        print("\n=== %s: %d signal(s) ===" % (title, len(rows)))
        for t, nm, rv, uv, _, n in rows[:args.max]:
            tag = "" if n == 1 else "  (+%d alike)" % (n - 1)
            print("  t=%-8s %-58s rtl=%-16s uhdm=%-16s%s"
                  % (t, nm[:58], str(rv)[:16], str(uv)[:16], tag))
        if len(rows) > args.max:
            print("  ... %d more group(s)" % (len(rows) - args.max))

    # Ours first, and shallowest-name first within the same time: the signal
    # closest to its own definition is the one to read.
    show("read_uhdm diverges, read_slang tracks the RTL -- OURS", 
         sorted(ours, key=lambda r: (r[0], r[1].count("."), r[1])))
    show("BOTH netlists diverge -- harness/modelling, not a reader defect",
         sorted(shared, key=lambda r: (r[0], r[1].count("."), r[1])))
    if ours:
        print("\n  drill into one of these with:")
        print("    python3 probe_signal.py %s '<name fragment>' --from <T> --to <T>" % w)
        t0 = min(r[0] for r in ours)
        print("\nearliest OURS divergence at t=%s; %d signal(s) there:"
              % (t0, sum(1 for r in ours if r[0] == t0)))
        for r in sorted((r for r in ours if r[0] == t0),
                        key=lambda r: (r[1].count("."), r[1]))[:12]:
            print("    %-70s rtl=%-14s uhdm=%s" % (r[1][:70], str(r[2])[:14], str(r[3])[:14]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
