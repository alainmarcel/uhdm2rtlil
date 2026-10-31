#!/usr/bin/env python3
"""Record an sv-tests case as having NO synthesis semantics.

Some of the corpus tests constructs that do not reach a netlist at all: classes,
`randsequence`, constrained randomization, `fork`/`join`, file I/O, `program`
blocks, dynamic arrays and queues.  There is nothing to make observable in a
synthesizable DUT, so these are CLASSIFIED rather than converted: the directory
keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).

Every claim here is checkable: the NOTE quotes the line from upstream that put
the test in its class, so a mis-classification can be spotted by reading the
NOTE alone, and a construct that later becomes supported can be re-triaged by
grepping for its reason.
"""
import argparse
import pathlib
import re

# Ordered: the first match wins, so put the unambiguous constructs first.
CLASSES = [
    ("randsequence",
     r"\brandsequence\s*\(",
     "`randsequence` is a simulation-time production generator: it has no netlist form."),
    ("constrained randomization",
     r"\brandomize\s*\(|\bstd\s*::\s*randomize\b|\bconstraint\b\s+\w+\s*\{|\$urandom",
     "Constrained randomization is a simulation-time service: a solver call has no netlist form."),
    ("class",
     r"^\s*(virtual\s+)?class\b|\bextends\b|\bnew\s*;|\bnew\s*\(",
     "Classes are dynamically allocated objects: there is nothing for synthesis to elaborate."),
    ("fork/join",
     r"\bfork\b|\bjoin_any\b|\bjoin_none\b|\bsemaphore\b|\bmailbox\b",
     "Dynamic process control has no netlist form."),
    ("file I/O",
     r"\$fopen|\$fclose|\$fwrite|\$fdisplay|\$fscanf|\$fgets|\$feof|\$sformatf|\$sscanf",
     "File and string-formatting system tasks are simulation services."),
    ("program block",
     r"^\s*program\b",
     "A `program` block is a testbench construct, not hardware."),
    ("clocking block",
     r"^\s*(default\s+)?clocking\b",
     "A `clocking` block schedules testbench sampling; it is not hardware."),
    ("dynamic array / queue",
     r"\[\s*\$\s*\]|\bnew\s*\[|\[\s*string\s*\]|\[\s*\*\s*\]",
     "Queues, dynamic arrays and associative arrays are unbounded at elaboration time."),
    ("delay control",
     r"^\s*#\d|\s#\d+\s*\w+\s*(<?=)|\bforever\b|\bwait\b",
     "The behaviour under test is a DELAY, which synthesis discards."),
]

HEADER = """NOT SYNTHESIZABLE -- classified, not converted.

Class: {cls}
{why}

Upstream evidence:
{evidence}

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
"""


def body_of(text: str) -> str:
    return re.sub(r"\A.*?^\*/\n", "", text, flags=re.S | re.M)


def classify(body: str):
    for cls, pat, why in CLASSES:
        m = re.search(pat, body, re.M)
        if m:
            lines = body.splitlines()
            idx = body[: m.start()].count("\n")
            quoted = "\n".join(
                f"    {lines[i]}" for i in range(max(0, idx - 1), min(len(lines), idx + 2))
            )
            return cls, why, quoted
    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    marked, skipped = 0, []
    for d in args.dirs:
        p = pathlib.Path(d)
        if (p / "dut.sv").exists() or (p / "NOTE.md").exists():
            continue
        got = classify(body_of((p / "orig.sv").read_text(errors="replace")))
        if not got:
            skipped.append(p.name)
            continue
        cls, why, evidence = got
        if not args.dry_run:
            (p / "NOTE.md").write_text(
                HEADER.format(cls=cls, why=why, evidence=evidence))
        marked += 1
        print(f"{cls:28s} {p.name}")
    print(f"\nmarked {marked}; no unambiguous class for {len(skipped)}")
    for s in skipped:
        print(f"  needs conversion or hand triage: {s}")


if __name__ == "__main__":
    main()
