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
    ("chandle",
     r"^\s*chandle\b",
     "A `chandle` is an opaque pointer to foreign (DPI) data: there is nothing to "
     "elaborate."),
    # NOTE: $stop and $finish are deliberately NOT here.  They appear as
    # incidental failure reporting inside tests whose real subject IS
    # synthesizable -- type_op_compare uses them to report a failed `type()`
    # comparison -- so they are handled separately below, and only when the task
    # is the whole module.
    ("simulation control task",
     r"\$exit\b|\$fatal\b|\$info\b|\$warning\b"
     r"|\$monitor|\$strobe|\$coverage_|\$get_coverage|\$set_coverage",
     "A simulation control or reporting task ends, pauses or instruments the RUN; "
     "there is no netlist counterpart."),
    ("random distribution",
     r"\$dist_\w+|\$random\b|\$urandom_range",
     "A random distribution is a simulation service and is not deterministic, so a "
     "netlist cannot carry its answer."),
    ("SVA expect",
     r"^\s*expect\s*\(|\bexpect\s*\(\s*@",
     "`expect` blocks the executing process until a sequence matches: it is a "
     "testbench construct with no netlist form."),
    ("intra-assignment timing control",
     r"<?=\s*(#\d|#\(|repeat\s*\(|@\s*\()",
     "An intra-assignment delay, repeat or event control schedules WHEN the write "
     "lands, which synthesis discards entirely."),
    ("min:typ:max delay",
     r"#\s*\(\s*\d+\s*:\s*\d+\s*:\s*\d+\s*\)",
     "A min:typ:max delay triple is a timing annotation with no netlist form."),
    ("global clocking",
     r"^\s*global\s+clocking\b",
     "A `global clocking` block names a simulation sampling clock; it declares no "
     "hardware."),
    ("event variable",
     r"^\s*event\s+\w+\s*;",
     "An `event` is a synchronisation object triggered and waited on at simulation "
     "time."),
    ("bounded queue",
     r"\[\s*\$\s*:",
     "A bounded queue is still a queue: its size varies at simulation time."),
    ("program block",
     r"^\s*program\b",
     "A `program` block is a testbench construct, not hardware."),
    ("clocking block",
     r"^\s*(default\s+)?clocking\b",
     "A `clocking` block schedules testbench sampling; it is not hardware."),
    ("dynamic array / queue",
     # An ASSOCIATIVE array's index is a TYPE, not a range: `int arr [ int ]`.
     # Spell the integral and string index types out, so a packed range
     # (`arr [7:0]`) and a sized unpacked array (`arr [4]`) are untouched.
     r"\[\s*\$\s*\]|\bnew\s*\[|\[\s*\*\s*\]"
     r"|\[\s*(?:string|int|integer|bit|logic|byte|shortint|longint|chandle)\s*\]",
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


STOP_ONLY = re.compile(r"\$(stop|finish)\s*(\(|;)")


def classify(body: str):
    # An EMPTY file (or one holding only comments) is testing that an empty input
    # is ACCEPTED.  Adding a module to make it observable would destroy exactly
    # the construct under test, so it is classified rather than converted.
    if not [l for l in body.splitlines()
            if l.strip() and not l.strip().startswith(("//", "/*", "*", "*/"))]:
        return ("empty input",
                "The file is empty (or holds only comments).  The construct under test "
                "IS the absence of content, so adding a module to make it observable "
                "would destroy it.",
                "    <no declarations at all>")
    # A module whose ONLY statement is $stop or $finish is a test OF that task;
    # one that merely reports a failure with it is not.
    if STOP_ONLY.search(body):
        stmts = [l.strip() for l in body.splitlines()
                 if l.strip() and not l.strip().startswith(("//", "/*", "*", "*/"))
                 and not re.match(r"^(module|endmodule|initial|begin|end)\b", l.strip())]
        if len(stmts) <= 1:
            return ("simulation control task",
                    "A simulation control task ends or pauses the RUN; there is no "
                    "netlist counterpart, and here it is the whole module.",
                    "\n".join(f"    {l}" for l in stmts))

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
