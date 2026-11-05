#!/usr/bin/env python3
"""Show one probed signal side by side across the RTL, read_uhdm and read_slang traces.

`probe_diff.py` names WHICH internal signal diverges first; this answers the
next question -- what does it actually do on each side, around that time.  It
drives `vcd-inspect` (tools/vcd_mcp.cpp, built by the top-level CMake into
build/vcd-inspect), which indexes each trace once and answers windowed queries
with binary searches instead of re-parsing a full-hierarchy VCD per question.

  python3 probe_signal.py <workdir> <pattern> [--from T] [--to T] [--limit N]
  python3 probe_signal.py <workdir> --list <pattern>      # what matches
  python3 probe_signal.py <workdir> --serve               # keep traces in RAM

PATTERN is a substring, or "re:..." for a regex -- vcd-inspect's own syntax.
With --serve running, later queries reuse the parsed traces over a socket.
"""
import argparse, os, shutil, subprocess, sys
from pathlib import Path

TAGS = ("rtl", "uhdm", "slang")


def find_inspect():
    here = Path(__file__).resolve().parent.parent
    for c in (here / "build" / "vcd-inspect", here / "tools" / "vcd-inspect"):
        if c.is_file() and os.access(c, os.X_OK):
            return str(c)
    w = shutil.which("vcd-inspect")
    if w:
        return w
    sys.exit("probe_signal: vcd-inspect not found -- build it with "
             "`cmake --build build --target vcd-inspect` (or `make -C tools`)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("work")
    ap.add_argument("pattern", nargs="?")
    ap.add_argument("--list", dest="list_pat")
    ap.add_argument("--from", dest="t_from", type=int)
    ap.add_argument("--to", dest="t_to", type=int)
    ap.add_argument("--limit", type=int, default=20)
    ap.add_argument("--serve", action="store_true",
                    help="start a resident vcd-inspect per trace and exit")
    a = ap.parse_args()
    exe = find_inspect()
    vcds = {t: os.path.join(a.work, f"probe_{t}.vcd") for t in TAGS}
    have = {t: p for t, p in vcds.items() if os.path.exists(p)}
    if not have:
        sys.exit(f"probe_signal: no probe_*.vcd in {a.work} "
                 f"-- run netlist_cosim.py --probe first")

    if a.serve:
        for t, p in have.items():
            subprocess.Popen([exe, p, "--serve"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"  serving {t}: {p}")
        return 0

    pat = a.list_pat or a.pattern
    if not pat:
        sys.exit("probe_signal: give a PATTERN (or --list PATTERN)")
    for t, p in have.items():
        cmd = [exe, p]
        cmd += ["--list", pat] if a.list_pat else ["--signal", pat]
        if a.t_from is not None:
            cmd += ["--from", str(a.t_from)]
        if a.t_to is not None:
            cmd += ["--to", str(a.t_to)]
        cmd += ["--limit", str(a.limit)]
        print(f"=== {t} ({os.path.basename(p)})")
        r = subprocess.run(cmd, capture_output=True, text=True)
        out = (r.stdout or "") + (r.stderr or "")
        # Drop the "no server on ...; loading in-process" notice: it is advice,
        # not a result, and it doubles the length of every answer.
        lines = [l.strip() for l in out.strip().splitlines()
                 if l.strip() and "no server on" not in l]
        print("".join("   " + l + "\n" for l in lines) or "   <no match>")
    missing = [t for t in TAGS if t not in have]
    if missing:
        print(f"\n(no trace for: {', '.join(missing)} -- read_slang netlists still hit "
              f"Verilator's trace-name bug, so that column is often absent)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
