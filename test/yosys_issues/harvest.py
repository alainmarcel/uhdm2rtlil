#!/usr/bin/env python3
"""Harvest the SystemVerilog code of YosysHQ/yosys issues into test dirs.

    python3 harvest.py fetch        # tracker -> harvest/bodies.json (needs gh)
    python3 harvest.py write        # bodies.json -> issue_<n>_<slug>[_<v>]/dut.sv
    python3 harvest.py all          # both

Which issues: every open or closed issue carrying the `SystemVerilog` label,
plus every issue matching a SystemVerilog keyword search (`read_verilog -sv`,
always_ff, interface, struct packed, package, ...).  Which code: the fenced
blocks of the body and comments that mention a module / package / interface
and use a SystemVerilog keyword, in these candidate FILE SETS per issue:

  * all body blocks together (an issue that shows a design in two blocks),
    unless two blocks define the same module -- then one variant per block
    (`_v<i>`): an issue that shows the failing and the working spelling;
  * the code inside a `read_verilog -sv <<EOT ... EOT` heredoc (`_h<i>`);
  * the block with a trailing port-list comma removed (`_tc`), a yosys
    extension that is not SystemVerilog.

Every candidate is run through Surelog and only the ones it parses become a
test directory; a `dut.sv` is the chosen blocks concatenated under a header
naming the issue.  Snippets that need a file the issue does not carry
(`$readmemh("image.hex")`, an `include`), instantiate modules it does not
define, or are pasted logs are dropped by that filter.  The hand-written
tests of the regression (test/yosys_issue_<n>_*) are NOT produced here --
they are the proven form of an issue, with their own test_structural.ys.

The sweep over this corpus is .github/workflows/sweep-sv-yosys-issues.yml
(`core_sweep.py sv-yosys-issues`).  Re-run `all` to pick up new issues; a
directory that already exists is rewritten only when its code changed.
"""
import argparse, collections, hashlib, json, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
WORK = HERE / "harvest"
SURELOG = REPO / "build" / "third_party" / "Surelog" / "bin" / "surelog"

SEARCHES = ["read_verilog -sv", "systemverilog", "system verilog", "always_comb",
            "always_ff", "always_latch", "interface modport", "struct packed",
            "package import", "typedef enum", "logic [", "unique case",
            "priority case", "parameter type", "assignment pattern", "static cast",
            "unpacked array", "string literal", "$bits", "foreach",
            "localparam type", "bind", "generate label"]
FENCE = re.compile(r'```[ \t]*([A-Za-z0-9_+-]*)[^\n]*\n(.*?)```', re.S)
SVKW = re.compile(r'\b(logic|always_comb|always_ff|always_latch|interface|modport|package|'
                  r'endpackage|import|typedef|struct|union|enum|int|bit|byte|shortint|longint|'
                  r'string|unique|priority|foreach|return|automatic|localparam type|'
                  r'parameter type|bind|assert property|let)\b|\'\{|\+\+|\+=|-=|\'\(|\$bits|\$clog2|::')
MOD = re.compile(r'\b(module|package|interface|program|checker)\b')
DEFN = re.compile(r'^\s*(?:module|interface|package|program)\s+([A-Za-z_][A-Za-z0-9_$]*)', re.M)
HEREDOC = re.compile(r'<<\s*(\w+)\s*\n(.*?)\n\1\s*$', re.S | re.M)
TRAILING_COMMA = re.compile(r',(\s*\n\s*)\)')


def gh(args):
    r = subprocess.run(["gh"] + args, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"gh {' '.join(args[:2])} failed: {r.stderr[:300]}")
    return r.stdout


def fetch():
    WORK.mkdir(exist_ok=True)
    nums = set()
    for st in ("open", "closed"):
        for it in json.loads(gh(["issue", "list", "-R", "YosysHQ/yosys", "--label", "SystemVerilog",
                                 "--state", st, "--limit", "1000", "--json", "number"])):
            nums.add(it["number"])
    for q in SEARCHES:
        r = subprocess.run(["gh", "search", "issues", "--repo", "YosysHQ/yosys", q,
                            "--limit", "1000", "--json", "number"], capture_output=True, text=True)
        if r.returncode == 0:
            for it in json.loads(r.stdout):
                nums.add(it["number"])
    out = {}
    bodies = WORK / "bodies.json"
    if bodies.exists():
        out = json.load(open(bodies))
    todo = sorted(n for n in nums if str(n) not in out)
    print(f"{len(nums)} issues, {len(todo)} to fetch")
    B = 60
    for i in range(0, len(todo), B):
        chunk = todo[i:i + B]
        q = 'query{repository(owner:"YosysHQ",name:"yosys"){' + ''.join(
            f'i{n}:issue(number:{n}){{number title state createdAt body '
            f'labels(first:20){{nodes{{name}}}} comments(first:30){{nodes{{body}}}}}}'
            for n in chunk) + '}}'
        data = json.loads(gh(["api", "graphql", "-f", f"query={q}"]))["data"]["repository"]
        for v in data.values():
            if v:
                out[str(v["number"])] = v
        json.dump(out, open(bodies, "w"))
        print(f"  {min(i + B, len(todo))}/{len(todo)}", flush=True)
    return out


def blocks_of(issue):
    """The SystemVerilog-looking fenced blocks of an issue: (source, code)."""
    texts = [("b", issue["body"] or "")] + [("c", c["body"] or "") for c in issue["comments"]["nodes"]]
    out, seen = [], set()
    for src, t in texts:
        for m in FENCE.finditer(t):
            lang, code = m.group(1).lower(), m.group(2).replace("\r", "")
            if not MOD.search(code):
                continue
            if code.lstrip().startswith(("yosys", "$", ">", "ERROR", "Warning")):
                continue
            if not SVKW.search(code) and lang not in ("systemverilog", "sv"):
                continue
            h = hashlib.md5(code.encode()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            out.append((src, code))
    return out


def candidates(issue):
    """Candidate file sets, as (variant tag, [(filename, code)])."""
    bl = blocks_of(issue)
    body = [(f"b{i}.sv", c) for i, (s, c) in enumerate(bl) if s == "b"]
    allb = [(f"{s}{i}.sv", c) for i, (s, c) in enumerate(bl)]
    cands = []

    def dup(files):
        names = collections.Counter(n for _, c in files for n in DEFN.findall(c))
        return any(k > 1 for k in names.values())
    if body and not dup(body):
        cands.append(("", body))
    elif allb and not dup(allb):
        cands.append(("", allb))
    if (body and dup(body)) or (not body and allb and dup(allb)):
        for i, (fn, c) in enumerate(allb):
            cands.append((f"v{i}", [("b0.sv", c)]))
    hi = 0
    for fn, c in allb:
        for m in HEREDOC.finditer(c):
            inner = m.group(2)
            if MOD.search(inner):
                cands.append((f"h{hi}", [("b0.sv", inner + "\n")]))
                hi += 1
    for tag, files in list(cands):
        fixed = [(fn, TRAILING_COMMA.sub(r"\1)", c)) for fn, c in files]
        if any(a != b for (_, a), (_, b) in zip(files, fixed)):
            cands.append((tag + "_tc" if tag else "tc", fixed))
    return cands


def surelog_ok(files):
    with tempfile.TemporaryDirectory() as td:
        for fn, c in files:
            (Path(td) / fn).write_text(c)
        r = subprocess.run([str(SURELOG), "-parse", "-nobuiltin", "-nocache", "-DSYNTHESIS",
                            "-filterprotected", "-d", "uhdm"] + [fn for fn, _ in files],
                           cwd=td, capture_output=True, text=True, timeout=180)
        log = r.stdout + r.stderr
        if r.returncode != 0 or not (Path(td) / "slpp_all" / "surelog.uhdm").exists():
            return False
        counts = re.findall(r'^\[ +(FATAL|SYNTAX|ERROR)\] : (\d+)$', log, re.M)
        if len(counts) != 3 or any(int(n) for _, n in counts):
            return False
        # an incomplete snippet: instantiates modules the issue does not define
        if "Cannot find a module definition" in log:
            return False
        # a package / interface / class only: nothing to sweep
        if not DEFN.findall("\n".join(c for _, c in files)) or \
           not re.search(r'^\s*module\s', "\n".join(c for _, c in files), re.M):
            return False
        return True


def slug(t):
    s = re.sub(r'[^a-z0-9]+', '_', t.lower()).strip('_')
    return '_'.join(s.split('_')[:6])[:48] or "issue"


def write(issues):
    made = 0
    for n in sorted(issues, key=int):
        it = issues[n]
        title, state = it["title"], it["state"].lower()
        seen_sets = set()
        for tag, files in candidates(it):
            key = hashlib.md5("".join(c for _, c in files).encode()).hexdigest()
            if key in seen_sets:
                continue
            seen_sets.add(key)
            if not surelog_ok(files):
                continue
            name = f"issue_{n}_{slug(title)}" + (f"_{tag}" if tag else "")
            hdr = (f"// YosysHQ/yosys#{n} ({state}): {title}\n"
                   f"// https://github.com/YosysHQ/yosys/issues/{n}\n"
                   f"// Code block(s) from the issue" + (f" (variant {tag})" if tag else "") +
                   "; harvested by test/yosys_issues/harvest.py\n\n")
            body = "".join(f"// ---- {fn}\n{c.rstrip()}\n\n" for fn, c in files)
            d = HERE / name
            d.mkdir(exist_ok=True)
            p = d / "dut.sv"
            if not p.exists() or p.read_text() != hdr + body:
                p.write_text(hdr + body)
            made += 1
            print(f"  {name}")
    print(f"{made} test directories")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["fetch", "write", "all"])
    ap.add_argument("--only", help="regex over issue numbers")
    a = ap.parse_args()
    issues = fetch() if a.cmd in ("fetch", "all") else json.load(open(WORK / "bodies.json"))
    if a.only:
        issues = {k: v for k, v in issues.items() if re.search(a.only, k)}
    if a.cmd in ("write", "all"):
        write(issues)


if __name__ == "__main__":
    main()
