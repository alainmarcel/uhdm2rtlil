#!/usr/bin/env python3
"""Convert a PREPROCESSING sv-tests case into a real synthesizable test.

Upstream's preprocessing cases are a directive and (at most) an empty `module
top ();` -- nothing about them is observable, so reading one proves nothing.
Each converted test keeps the directive lines VERBATIM and brackets them with
one shared observable body: an adder/subtractor whose three results are proven
with `sat -verify -prove`.  The directive is then the only variable across the
whole group, so a failure localises to it rather than to whichever logic a
bespoke body happened to use.

Use this ONLY where the directive is the whole test.  Where the logic IS the
test (chapters 6, 7, 11, 12, 13 ...) write the body by hand: a shared body
there would test the body, not the construct.
"""
import argparse
import pathlib
import re

BODY = """module top(input logic [7:0] a, input logic [7:0] b, input logic sel,
           output logic [8:0] y);
  // One observable body for the whole directive group: the directive above is
  // the only variable, so a failure localises to it.
  assign y = sel ? (a + b) : (a - b);
endmodule
"""

STRUCTURAL = """# The directive must be accepted and must not perturb compilation: the logic
# below still proves.
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -auto-top
proc
opt -full
check -assert
sat -verify -prove y 9'd300 -set a 8'd200 -set b 8'd100 -set sel 1'b1
sat -verify -prove y 9'd100 -set a 8'd200 -set b 8'd100 -set sel 1'b0
sat -verify -prove y 9'd511 -set a 8'd0   -set b 8'd1   -set sel 1'b0
"""

SLANG_EQUIV = """# read_uhdm vs read_slang -- the second reference alongside read_verilog.
read_uhdm slpp_all/surelog.uhdm
hierarchy -auto-top
prep; async2sync
rename top gold; design -stash g1
read_slang --ignore-assertions dut.sv --top top
hierarchy -top top
prep -top top; async2sync
rename top gate; design -stash g2
design -copy-from g1 -as gold gold
design -copy-from g2 -as gate gate
miter -equiv -flatten -make_assert gold gate m
hierarchy -top m
sat -verify -prove-asserts m
"""

# Directives that OPEN a region the module must sit inside: the closer and
# everything after it has to follow `endmodule`, or the converted test moves the
# module OUT of the region under test and stops exercising it.
CLOSERS = (
    "`endcelldefine",
    "`endprotect",
    "`end_keywords",
    "`nounconnected_drive",
)

HEADER = """// Converted from chipsalliance/sv-tests ({name}, :type: preprocessing).
// Upstream is the directive alone{alsomod}, so nothing about it is observable.
// The directive is kept VERBATIM below and now brackets real logic: if it
// perturbed compilation the proven adder/subtractor would not survive.
// The whole directive group shares this body on purpose -- the directive form is
// the only variable, so a failure localises to it.  Upstream kept as orig.sv.
"""


def directive_lines(orig: str) -> list[str]:
    """Everything after the sv-tests metadata comment, minus an empty module."""
    body = re.sub(r"\A.*?^\*/\n", "", orig, flags=re.S | re.M)
    out, drop = [], False
    for line in body.splitlines():
        # An EMPTY module of ANY name is dropped -- upstream names them `top`, `ts`,
        # `empty` -- so the shared body is the only module and -auto-top is
        # unambiguous.
        if re.match(r"^\s*module\s+\w+\s*(\(\s*\))?\s*;\s*$", line):
            drop = True
            continue
        if drop and re.match(r"^\s*endmodule\s*$", line):
            drop = False
            continue
        if line.strip():
            out.append(line)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    args = ap.parse_args()
    for d in args.dirs:
        p = pathlib.Path(d)
        orig = (p / "orig.sv").read_text(errors="replace")
        lines = directive_lines(orig)
        had_mod = bool(re.search(r"^\s*module\s+\w+\s*(\(\s*\))?\s*;", orig, re.M))
        hdr = HEADER.format(
            name=p.name,
            alsomod=" plus an EMPTY `module top ();`" if had_mod else "",
        )
        cut = next(
            (i for i, ln in enumerate(lines)
             if ln.strip().split()[0] in CLOSERS if ln.strip()),
            len(lines),
        )
        lead, trail = lines[:cut], lines[cut:]
        text = hdr + "\n".join(lead) + "\n" + BODY
        if trail:
            text += "\n".join(trail) + "\n"
        (p / "dut.sv").write_text(text)
        (p / "test_structural.ys").write_text(STRUCTURAL)
        (p / "test_slang_equiv.ys").write_text(SLANG_EQUIV)
        print(f"converted {p.name}: {len(lines)} directive line(s)")


if __name__ == "__main__":
    main()
