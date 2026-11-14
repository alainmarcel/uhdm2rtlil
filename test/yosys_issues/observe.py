#!/usr/bin/env python3
"""Make an issue-corpus test CONTROLLABLE and OBSERVABLE.

    python3 observe.py <test_dir>...      # rewrite each dut.sv in place

A bug report is usually a portless `module top;`: its logic reads variables
nothing drives and writes variables nothing reads.  Such a design has no
input to drive and no output to compare, so the sweep's miter against
read_slang passes VACUOUSLY and its Verilator co-sim is skipped -- a green
row that checked nothing (77 of the first slang-issues sweep's 104 "proven"
rows).

This gives the top module ports, without touching its logic:

  * every module-level signal the source ASSIGNS (read_uhdm's uhdm_src_lhs)
    is observed through an output `__o_<sig>`  (`assign __o_d = d;`);
  * every module-level signal that is READ but never assigned and has no
    initialiser is controlled through an input `__i_<sig>`
    (`assign a = __i_a;`, cast to its typedef when it has one).

The ports are added non-ANSI style -- names in the header, declarations and
assigns appended before `endmodule` -- so the original text is unchanged
above them.  Only a top with NO ports is rewritten; one that already has
ports is the reporter's own interface.  read_uhdm only classifies the
signals (assigned / read-undriven / width / typedef): the rewritten source
is then read by every frontend alike, so this does not bias the check
toward read_uhdm.  A rewritten dut.sv carries the OBSERVE_MARK line, and
running this again is a no-op.
"""
import json, re, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
YOSYS = REPO / "out" / "current" / "bin" / "yosys"
PLUGIN = REPO / "build" / "uhdm2rtlil.so"
SURELOG = REPO / "build" / "third_party" / "Surelog" / "bin" / "surelog"
OBSERVE_MARK = "// controllable/observable ports added by test/yosys_issues/observe.py"
# A module-level, user-declared signal: no generate scope, no array element,
# no internal or escaped-hierarchical name.
PLAIN = re.compile(r"^\\[A-Za-z_][A-Za-z0-9_$]*$")
# A member of an interface instance or a named generate block (`foo.a`,
# `gen.x`): reachable from the module by the same dotted hierarchical name.
# An indexed scope (`g[0].x`) is left alone.
DOTTED = re.compile(r"^\\[A-Za-z_][A-Za-z0-9_$]*(\.[A-Za-z_][A-Za-z0-9_$]*)+$")


def _port_name(n):
    return n.replace(".", "_")


def _netlist(d):
    """(top, netnames) from read_uhdm, or (None, None)."""
    with tempfile.TemporaryDirectory() as td:
        js = Path(td) / "n.json"
        r = subprocess.run([str(YOSYS), "-q", "-m", str(PLUGIN), "-p",
                            "read_uhdm slpp_all/surelog.uhdm; hierarchy -auto-top; "
                            f"proc; write_json {js}"],
                           cwd=d, capture_output=True, text=True, timeout=600)
        if r.returncode or not js.exists():
            return None, None
        mods = json.load(open(js))["modules"]
    for name, m in mods.items():
        t = m.get("attributes", {}).get("top")
        if t is not None and int(str(t), 2 if set(str(t)) <= {"0", "1"} else 10) == 1:
            return name, m
    return None, None


def _driven_bits(m):
    """Bits driven by a cell output or appearing on a connect's LHS."""
    drv = set()
    for c in m.get("cells", {}).values():
        for p, dirn in c.get("port_directions", {}).items():
            if dirn == "output":
                drv.update(b for b in c["connections"].get(p, []) if isinstance(b, int))
    return drv


def _read_bits(m):
    rd = set()
    for c in m.get("cells", {}).values():
        for p, dirn in c.get("port_directions", {}).items():
            if dirn == "input":
                rd.update(b for b in c["connections"].get(p, []) if isinstance(b, int))
    return rd


def _module_span(text, top):
    """(header_start, header_end, endmodule_start) of `module top`."""
    m = re.search(r"\bmodule\s+(?:automatic\s+|static\s+)?" + re.escape(top) + r"\b", text)
    if not m:
        return None
    i = m.end()
    # skip `import pkg::*;` lists and a #(...) parameter port list
    depth = 0
    j = i
    while j < len(text):
        ch = text[j]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == ";" and depth == 0:
            break
        j += 1
    head = text[i:j]
    end = re.compile(r"\bendmodule\b").search(text, j)
    if not end:
        return None
    return m.start(), j, end.start(), head


def observe(d):
    d = Path(d)
    p = d / "dut.sv"
    text = p.read_text()
    if OBSERVE_MARK in text:
        return "already"
    top, m = _netlist(d)
    if not top:
        return "no top"
    # An INTERFACE port at the top (flattened to `\\<port>.<member>`):
    # no tool can drive it port by port, and read_slang refuses an unconnected
    # top-level interface port.  Append the flat wrapper test/gen_iface_wrapper.py
    # builds (`<top>_flat`, the interface instantiated inside); it instantiates
    # the top, so `hierarchy -auto-top` picks the wrapper.
    if any("." in n for n in m.get("ports", {})):
        return _wrap_iface(d, p, text, top)
    dirs = {v.get("direction") for v in m.get("ports", {}).values()}
    want_in = "input" not in dirs and "inout" not in dirs
    want_out = "output" not in dirs and "inout" not in dirs
    if not want_in and not want_out:
        return "has ports"
    span = _module_span(text, top)
    if not span:
        return "no module text"
    start, hdr_end, endm, head = span
    port_names = set(m.get("ports", {}))
    drv = _driven_bits(m)
    rd = _read_bits(m)
    ins, outs = [], []
    for n, w in sorted(m["netnames"].items()):
        nm = "\\" + n
        if not (PLAIN.match(nm) or DOTTED.match(nm)) or n.startswith("__") or n in port_names:
            continue
        # a dotted name that is an interface PORT's member is the port itself
        if "." in n and n.split(".")[0] in {q.split(".")[0] for q in port_names}:
            continue
        a = w.get("attributes", {})
        bits = [b for b in w["bits"] if isinstance(b, int)]
        width = len(w["bits"])
        # assigned: marked by read_uhdm (plain names), or -- for a member
        # name it does not mark -- driven by a cell or tied to a constant
        const_bits = any(not isinstance(b, int) for b in w["bits"])
        assigned = "uhdm_src_lhs" in a or ("." in n and (const_bits or (set(bits) & drv)))
        if assigned:
            if want_out:
                outs.append((n, width))
        elif want_in and bits and not (set(bits) & drv) and (set(bits) & rd) and "init" not in a:
            ins.append((n, width, a.get("wiretype")))
    if not ins and not outs:
        return "nothing to expose"

    def rng(w):
        return f" [{w - 1}:0]" if w > 1 else ""
    # The header's port list: none, empty, non-ANSI names, or ANSI.
    hdr = text[start:hdr_end]
    stripped = re.sub(r"#\s*\((?:[^()]|\([^()]*\))*\)", "", head)
    has_list = re.search(r"\(\s*[^)\s]", stripped) is not None
    ansi = has_list and re.search(r"\b(input|output|inout|ref)\b", stripped) is not None
    body = [f"\n  {OBSERVE_MARK}"]
    decls = []
    for n, wdt, ty in ins:
        pn = f"__i_{_port_name(n)}"
        decls.append(("input", wdt, pn))
        ty = (ty or "").strip("\\").strip('"').lstrip("\\")
        rhs = f"{ty}'({pn})" if ty and re.match(r"^[A-Za-z_]\w*$", ty) else pn
        body.append(f"  assign {n} = {rhs};")
    for n, wdt in outs:
        pn = f"__o_{_port_name(n)}"
        decls.append(("output", wdt, pn))
        body.append(f"  assign {pn} = {n};")
    if ansi:
        extra = ", ".join(f"{dirn} logic{rng(w)} {nm}" for dirn, w, nm in decls)
        k = hdr.rstrip().rfind(")")
        hdr = hdr[:k].rstrip() + ",\n  " + extra + hdr[k:]
    else:
        names = ", ".join(nm for _, _, nm in decls)
        if has_list:
            k = hdr.rstrip().rfind(")")
            hdr = hdr[:k].rstrip() + ", " + names + hdr[k:]
        elif re.search(r"\(\s*\)\s*$", hdr):
            hdr = re.sub(r"\(\s*\)\s*$", "(" + names + ")", hdr)
        else:
            hdr = hdr.rstrip() + " (" + names + ")"
        body[1:1] = [f"  {dirn} logic{rng(w)} {nm};" for dirn, w, nm in decls]
    new = text[:start] + hdr + text[hdr_end:endm] + "\n".join(body) + "\n" + text[endm:]
    # Never make a row worse: the rewrite must still parse, and read_slang
    # must still read it if it read the original.
    slang_ok = _slang_ok(d, text)
    p.write_text(new)
    if not _surelog_ok(d) or (slang_ok and not _slang_ok(d, new)):
        p.write_text(text)
        _parse(d)
        return "reverted (rewrite not accepted)"
    return f"{len(ins)} in, {len(outs)} out"


def _wrap_iface(d, p, text, top):
    with tempfile.TemporaryDirectory() as td:
        il = Path(td) / "n.il"
        out = Path(td) / "w.sv"
        r = subprocess.run([str(YOSYS), "-q", "-m", str(PLUGIN), "-p",
                            f"read_uhdm slpp_all/surelog.uhdm; hierarchy -top {top}; "
                            f"proc; write_rtlil {il}"], cwd=d, capture_output=True,
                           text=True, timeout=600)
        if r.returncode or not il.exists():
            return "iface: no netlist"
        r = subprocess.run([sys.executable, str(HERE.parent / "gen_iface_wrapper.py"),
                            str(il), top, str(out), str(p)], capture_output=True,
                           text=True, timeout=600)
        if r.returncode or not out.exists():
            return "iface: no wrapper"
        wrapper = out.read_text()
    new = text.rstrip() + f"\n\n{OBSERVE_MARK}\n" + wrapper.rstrip() + "\n"
    slang_ok = _slang_ok(d, text)
    p.write_text(new)
    if not _surelog_ok(d) or (slang_ok and not _slang_ok(d, new)):
        p.write_text(text)
        _parse(d)
        return "reverted (iface wrapper not accepted)"
    return "iface wrapper"


def _surelog_ok(d):
    r = subprocess.run([str(SURELOG), "-parse", "-nobuiltin", "-nocache", "-DSYNTHESIS",
                        "-filterprotected", "-d", "uhdm", "dut.sv"], cwd=d,
                       capture_output=True, text=True, timeout=300)
    counts = re.findall(r'^\[ +(FATAL|SYNTAX|ERROR)\] : (\d+)$', r.stdout + r.stderr, re.M)
    return r.returncode == 0 and len(counts) == 3 and not any(int(n) for _, n in counts)


def _slang_ok(d, text):
    with tempfile.TemporaryDirectory() as td:
        f = Path(td) / "dut.sv"
        f.write_text(text)
        r = subprocess.run(["bash", "-c", f"ulimit -Sv 8000000; exec {YOSYS} -q -p "
                            f"'read_slang {f}; hierarchy -auto-top'"],
                           capture_output=True, text=True, timeout=300)
        return r.returncode == 0


def _parse(d):
    """(Re)run Surelog so the netlist reflects dut.sv."""
    subprocess.run([str(SURELOG), "-parse", "-nobuiltin", "-nocache", "-DSYNTHESIS",
                    "-filterprotected", "-d", "uhdm", "dut.sv"], cwd=d,
                   capture_output=True, timeout=300)


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        d = Path(arg)
        if not (d / "dut.sv").exists():
            continue
        _parse(d)
        print(f"{d.name}: {observe(d)}")
