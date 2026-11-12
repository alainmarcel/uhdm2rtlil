#!/usr/bin/env python3
"""Harvest the SystemVerilog code of povik/sv-elab issues into test dirs.

    python3 harvest.py fetch        # tracker -> harvest/bodies.json (needs gh)
    python3 harvest.py write        # bodies.json -> issue_<n>_<slug>[_<v>]/dut.sv
    python3 harvest.py all          # both
    python3 harvest.py ledger       # README.md: every issue -> its test or why none

sv-elab is the SystemVerilog elaborator vendored into yosys as `read_slang`,
the reference frontend of every sweep here.  Its tracker is all
SystemVerilog, so EVERY issue is harvested, open and closed, and a code block
needs no SystemVerilog keyword to count.  Each issue is a construct some
design needed from a SystemVerilog frontend; this corpus asks whether
read_uhdm handles it too.

sv-elab also keeps the regression test of a fixed issue as
tests/various/issue<n>.ys (the design inline, in a `read_slang <<EOF`
heredoc).  `fetch` adds each such file to its issue as one more code block,
so an issue whose report carried no code still gets a row.

The block selection, variants and Surelog filter are those of
test/yosys_issues/harvest.py, which this file reuses.  The sweep over this
corpus is .github/workflows/sweep-sv-elab-issues.yml
(`core_sweep.py sv-elab-issues`).
"""
import base64, json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "yosys_issues"))
import harvest as base  # noqa: E402

base.configure("povik", "sv-elab", HERE, all_issues=True,
               self_path="test/sv_elab_issues/harvest.py")

_fetch = base.fetch
# sv-elab tests that belong to an issue without carrying its number.
NAMED_TESTS = {"regress.sv": "191"}   # "release builds fail test `regress.sv`"


def split_regressions(text):
    """{N: code} for a file of regression modules named r<N>, r<N>_sub, ...

    A unit ends at a column-0 `endmodule` / `endinterface` / `endclass` /
    `endpackage` (an indented one closes a class NESTED in a module) or at a
    typedef's closing `} r<N>_name;`; it belongs to the first r<N> it
    declares or uses.  `ifdef guards are dropped (the file is read with
    none of them defined)."""
    units, cur = [], []
    for ln in text.splitlines():
        if re.match(r"\s*`(ifn?def|endif|else)\b", ln):
            continue
        cur.append(ln)
        if re.match(r"end(module|interface|class|package)\b", ln) or \
           re.match(r"\s*}\s*r\d+\w*\s*;", ln):
            units.append("\n".join(cur))
            cur = []
    groups = {}
    for u in units:
        m = re.search(r"\br(\d+)", re.sub(r"//[^\n]*", "", u))
        groups.setdefault(m.group(1) if m else "0", []).append(u)
    return {k: "\n".join(v).strip() + "\n" for k, v in groups.items()}


def fetch():
    """The tracker, plus sv-elab's own per-issue regression tests."""
    out = _fetch()
    files = json.loads(base.gh(["api", "repos/povik/sv-elab/contents/tests/various"]))
    for f in files:
        m = re.fullmatch(r"issue(\d+)\.(ys|v|sv)", f["name"])
        n = m.group(1) if m else NAMED_TESTS.get(f["name"])
        if not n or n not in out:
            continue
        blob = json.loads(base.gh(["api", f["url"].split("api.github.com/")[1]]))
        text = base64.b64decode(blob["content"]).decode("utf-8", "replace")
        it = out[n]
        tag = f"sv-elab tests/various/{f['name']}"
        nodes = [c for c in it["comments"]["nodes"] if not c["body"].startswith("<!-- " )]
        # regress.sv is ~35 unrelated regressions (r1..r35) in one file, and
        # one construct Surelog rejects would hide all of them: one block
        # per regression, so each parses -- and becomes a row -- alone.
        parts = split_regressions(text) if f["name"] == "regress.sv" else {"": text}
        for k, part in parts.items():
            sub = f" r{k}" if k else ""
            mark = f"// {tag}{sub}\n" if k else ""
            nodes.append({"body": f"<!-- {tag}{sub} -->\n```\n{mark}{part}\n```\n"})
        it["comments"]["nodes"] = nodes
        print(f"  + {tag}")
    json.dump(out, open(base.WORK / "bodies.json", "w"))
    return out


base.fetch = fetch
# A regress.sv block carries its regression's name: the row is `_r<N>`.
base.BLOCK_TAG = lambda code: (lambda m: m and f"r{m.group(1)}")(
    re.match(r"// sv-elab tests/various/regress\.sv r(\d+)\n", code))


def ledger():
    """README.md: every issue, open and closed, and where it went -- a test
    directory, or the reason it has none -- so the corpus accounts for the
    WHOLE tracker, not just the issues that became rows."""
    issues = json.load(open(base.WORK / "bodies.json"))
    rows = {}
    for d in sorted(HERE.glob("issue_*")):
        if (d / "dut.sv").exists():
            rows.setdefault(d.name.split("_")[1], []).append(d.name)
    lines, count = [], {}
    for n in sorted(issues, key=int):
        it = issues[n]
        if n in rows:
            why = ", ".join(f"[`{x}`]({x}/dut.sv)" for x in rows[n])
            k = "test"
        else:
            texts = [it["body"] or ""] + [c["body"] or "" for c in it["comments"]["nodes"]]
            if not any(base.FENCE.search(t) for t in texts):
                why, k = "no code in the issue (build, packaging, feature or diagnostics request)", "nocode"
            elif not base.blocks_of(it):
                why, k = "code blocks are logs, scripts or commands -- no design", "nodesign"
            else:
                why, k = ("design code that does not stand alone (an unknown module, "
                          "a deliberate error, or a log fragment)"), "partial"
        count[k] = count.get(k, 0) + 1
        title = it["title"].replace("|", "\\|")
        lines.append(f"| [#{n}](https://github.com/povik/sv-elab/issues/{n}) | "
                     f"{it['state'].lower()} | {title} | {why} |")
    head = [
        "# povik/sv-elab issue corpus",
        "",
        "Generated by `python3 harvest.py ledger`; do not edit by hand.",
        "Every issue of [povik/sv-elab](https://github.com/povik/sv-elab/issues) "
        "(the elaborator behind yosys's `read_slang`), open and closed, and the "
        "test directory it became -- or why it has none.  The sweep is "
        "`python3 test/core_sweep.py sv-elab-issues` "
        "(.github/workflows/sweep-sv-elab-issues.yml).",
        "",
        f"* {len(issues)} issues",
        f"* {count.get('test', 0)} with a test directory "
        f"({sum(len(v) for v in rows.values())} directories)",
        f"* {count.get('nocode', 0)} with no code at all",
        f"* {count.get('nodesign', 0)} whose code is a log, script or command only",
        f"* {count.get('partial', 0)} whose design code does not stand alone",
        "",
        "| issue | state | title | test / reason |",
        "|---|---|---|---|",
    ]
    (HERE / "README.md").write_text("\n".join(head + lines) + "\n")
    print(count)


if __name__ == "__main__":
    if sys.argv[1:] == ["ledger"]:
        ledger()
    else:
        base.main(__doc__)
