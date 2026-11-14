#!/usr/bin/env python3
"""Harvest the SYNTHESIZABLE SystemVerilog code of MikePopoloski/slang issues.

    python3 harvest.py fetch        # tracker -> harvest/bodies.json (needs gh)
    python3 harvest.py write        # bodies.json -> issue_<n>_<slug>[_<v>]/dut.sv
    python3 harvest.py all          # both
    python3 harvest.py ledger       # README.md: every issue -> its test or why none

slang is the SystemVerilog compiler under sv-elab / yosys's `read_slang`, the
reference frontend of every sweep here.  Its tracker covers the WHOLE
language -- classes, UVM, constraints, coverage, testbench timing -- so a
code block becomes a row only if it is a design a synthesis frontend should
read: no testbench-only construct (CANDIDATE_OK below) and some logic (an
`assign`, an `always*` block, or a port).  Each row asks whether read_uhdm
handles a construct someone reported against slang.

The block selection, variants and Surelog filter are those of
test/yosys_issues/harvest.py, which this file reuses.  The sweep over this
corpus is .github/workflows/sweep-slang-issues.yml
(`core_sweep.py slang-issues`).
"""
import re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "yosys_issues"))
import harvest as base  # noqa: E402

base.configure("MikePopoloski", "slang", HERE, all_issues=True,
               self_path="test/slang_issues/harvest.py")

# Constructs with no synthesis meaning: object-oriented testbench code,
# randomization, coverage, inter-process communication, dynamic processes.
TESTBENCH = re.compile(
    r"\b(class|endclass|program|covergroup|coverpoint|constraint|randomize|"
    r"rand|randc|mailbox|semaphore|fork|join_any|join_none|virtual\s+interface|"
    r"chandle|event|wait_order|process::|\$urandom|\$random|uvm_\w+)\b")
# Some logic to synthesize: a continuous or procedural assignment, or a port.
LOGIC = re.compile(r"\b(assign|always|always_comb|always_ff|always_latch|"
                   r"input|output|inout)\b")


def synthesizable(code):
    code = re.sub(r"//[^\n]*|/\*.*?\*/", "", code, flags=re.S)
    return not TESTBENCH.search(code) and bool(LOGIC.search(code))


base.CANDIDATE_OK = synthesizable
base.CANDIDATE_WHY = ("not synthesizable (testbench-only constructs -- classes, "
                      "randomization, coverage, fork -- or no logic at all)")


def ledger():
    base.ledger("MikePopoloski/slang issue corpus (synthesizable designs)",
                "(the SystemVerilog compiler under sv-elab / yosys's `read_slang`)",
                "`python3 test/core_sweep.py slang-issues` "
                "(.github/workflows/sweep-slang-issues.yml)")


if __name__ == "__main__":
    if sys.argv[1:] == ["ledger"]:
        ledger()
    else:
        base.main(__doc__)
