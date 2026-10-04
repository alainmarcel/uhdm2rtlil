#!/usr/bin/env python3
"""Bind a module's CONFIGURATION parameter so it can be a top level.

CORE-V Wally writes every module as

    module alu import cvw::*; #(parameter cvw_t P) (input logic [P.XLEN-1:0] A, ...);

a struct parameter with NO DEFAULT.  read_slang refuses such a module as a top
level, correctly -- there is no value for `P` -- and reports "'alu' is not a
valid top-level module"; Surelog invents one and reads it anyway.  So 136 cvw
modules were recorded as "read_slang cannot read this design" when the truth is
that we never gave it the configuration.

The repository builds `P` itself:

    localparam cvw_t P = '{ XLEN : XLEN, IEEE754 : IEEE754, ... };   parameter-defs.vh

every field taking its value from an identically-named localparam that the
chosen config's `config.vh` declares.  So a wrapper that includes both, copies
the DUT's port list with the `P.` prefix stripped, and instantiates the module
with `#(P)`, resolves every width against the real configuration.

usage: gen_config_wrapper.py --module M --manifest fam.json --out M_cfg.sv <srcs...>
exit 3 = the module declares no such parameter (nothing to do).
"""
import os
import argparse, json, re, sys
from pathlib import Path


def module_header(txt, name):
    """(param_name, ports_text) for `module <name> ... #(parameter T P) (ports);`"""
    m = re.search(r"^[ \t]*module\s+" + re.escape(name) + r"\b", txt, re.M)
    if not m:
        return None
    i = m.end()
    # A value parameter of a named type with no default, FIRST in the list:
    # `#(parameter cvw_t P)` and also `#(parameter cvw_t P, parameter Depth = 10)`
    # -- 20 cvw rows (btb, busfsm, ahbapbbridge ...) declare a second parameter
    # after the configuration and were declined by a pattern that required the
    # list to end right after the name.  The others keep their defaults; `#(P)`
    # binds positionally, which is what the design intends.
    pm = re.compile(r"#\s*\(\s*parameter\s+(\w+)\s+(\w+)\s*[,)]").search(txt, i, i + 4000)
    if not pm:
        return None
    if pm.group(1) in ("type", "int", "logic", "bit", "integer", "real"):
        return None            # a plain value parameter, or PULP's type param
    # Walk to the end of the `#( ... )` parameter list, then the port list is the
    # next parenthesised group.
    popen = txt.find("(", pm.start())
    depth, k = 0, popen
    while k < len(txt):
        if txt[k] == "(":
            depth += 1
        elif txt[k] == ")":
            depth -= 1
            if depth == 0:
                break
        k += 1
    j = txt.find("(", k + 1)
    if j < 0:
        return None
    depth, k = 0, j
    while k < len(txt):
        if txt[k] == "(":
            depth += 1
        elif txt[k] == ")":
            depth -= 1
            if depth == 0:
                break
        k += 1
    # The port list ends at its own matching ')'.
    depth, kp = 0, j
    while kp < len(txt):
        if txt[kp] == "(":
            depth += 1
        elif txt[kp] == ")":
            depth -= 1
            if depth == 0:
                break
        kp += 1
    # The parameters AFTER the configuration one: a copied port may be declared
    # with them (`input logic [PERIPHS-1:0] HSEL`, cvw's ahbapbbridge), and a
    # wrapper that does not declare them does not parse at all.
    rest = txt[pm.end():k]            # k is the param list's own ')'
    # pm matched through the separator, so `rest` starts after it; cut anything
    # from the first ')' in case the scan above overshot a nested group.
    if ")" in rest:
        rest = rest[:rest.index(")")]
    return pm.group(2), txt[j + 1:kp], rest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("srcs", nargs="*")
    a = ap.parse_args()
    man = json.loads(Path(a.manifest).read_text())
    cfg = man.get("config_bind")
    if not cfg:
        sys.exit(3)
    hdr = None
    for f in a.srcs:
        try:
            txt = Path(f).read_text(errors="replace")
        except OSError:
            continue
        hdr = module_header(txt, a.module)
        if hdr:
            break
    if not hdr:
        sys.exit(3)
    pname, ports, rest_params = hdr
    # Declare the DUT's OTHER parameters as localparams, with their own
    # defaults, so a port declared with one of them resolves in the wrapper.
    # A parameter with NO default would have to be invented here -- cvw's
    # busfsm has `parameter logic READ_ONLY` -- and inventing a configuration is
    # exactly what this harness is trying to stop doing, so decline instead and
    # let the row stay honestly unmeasured.
    # What the configuration includes already declare, so the wrapper does not
    # declare it twice.
    cfg_defined = set()
    ext_root = os.environ.get("EXT_IP_ROOT", os.path.expanduser("~/ext"))
    for inc in cfg.get("includes", []):
        for root, _d, fs in os.walk(ext_root):
            if inc in fs:
                try:
                    cfg_defined |= set(re.findall(
                        r"localparam\s+(?:[^=;]*?\s)?(\w+)\s*=",
                        open(os.path.join(root, inc), errors="replace").read()))
                except OSError:
                    pass
                break
    extra, bound_extra = [], []
    # A comma list continues the previous `parameter` keyword:
    # `parameter TLB_ENTRIES = 8, KEY_BITS = 20, SEGMENT_BITS = 10` declares
    # three value parameters (cvw tlbcam).  Only the first entry carries the
    # keyword, so the others were skipped -- and could never be bound.
    in_value_params = False
    for ent in rest_params.split(","):
        ent = re.sub(r"//[^\n]*", "", ent).strip().rstrip(")").strip()
        if not ent:
            continue
        if ent.startswith("parameter"):
            body = ent[len("parameter"):].strip()
            in_value_params = not body.startswith("type")
        elif in_value_params and re.match(r"^[A-Za-z_]\w*\s*=", ent):
            body = ent
        else:
            in_value_params = False
            continue
        name, eq, dflt = body.partition("=")
        ids = re.findall(r"[A-Za-z_]\w*", name)
        if not ids:
            continue
        # The manifest's bind.values may name this parameter -- the same rule
        # the plain value-bind wrapper applies.  A rule OVERRIDES a default:
        # tlbcam's `KEY_BITS = 20` is a placeholder the real tlb never uses
        # (it passes P.VPN_BITS + P.ASID_BITS), and with it the rv64gc key
        # slices run off the end of the key.
        rule = next((val for pat, val in (man.get("bind") or {}).get("values", [])
                     if re.search(pat, ids[-1])), None)
        if rule is not None:
            extra.append(f"  localparam {ids[-1]} = {rule};")
            bound_extra.append(ids[-1])
            continue
        if not eq or not dflt.strip():
            # No default (packetizer's `parameter integer MAX_CSRS`) and no
            # rule: inventing a configuration is exactly what this harness is
            # trying to stop doing, so decline and let the row stay unmeasured.
            sys.exit(3)
        # The configuration include may declare the same name -- cvw's config.vh
        # has INSTR_CLASS_PRED, which icpred also takes as a parameter -- and a
        # second declaration is a hard error ("Duplicate declaration of signal").
        if ids[-1] in cfg_defined:
            continue
        extra.append(f"  localparam {ids[-1]} = {dflt.strip()};")
    # `P.XLEN` -> `XLEN`: parameter-defs.vh fills each field from an
    # identically-named localparam of the config, so the names already agree.
    ports = re.sub(r"\b" + re.escape(pname) + r"\s*\.\s*", "", ports)
    # Strip comments so a `//` cannot swallow the closing paren we add.
    ports = re.sub(r"//[^\n]*", "", ports)
    ports = "\n".join(l.rstrip() for l in ports.splitlines() if l.strip())
    # The port NAMES, for a non-ANSI header (see below).
    def split_top_commas(t):
        out, depth, cur = [], 0, []
        for ch in t:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            if ch == "," and depth == 0:
                out.append("".join(cur)); cur = []
            else:
                cur.append(ch)
        if "".join(cur).strip():
            out.append("".join(cur))
        return [x.strip() for x in out if x.strip()]

    def port_name(item):
        """The NAME of one port item: the last identifier not inside brackets.

        `var logic [7:0] PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0]` (cvw's mmu) has
        its unpacked dimension AFTER the name, and a left-to-right token walk
        consumed the name as a type -- Verilator then said "Input/output/inout
        does not appear in port list".  `tlul_pkg::tl_h2d_t tl_i` must not yield
        the package, and `input logic a, b, c` must yield all three.
        """
        mask, depth = [], 0
        for ch in item:
            if ch == "[":
                depth += 1
            mask.append(" " if (depth or ch == "]") else ch)
            if ch == "]":
                depth -= 1
        ids = re.findall(r"[A-Za-z_]\w*", "".join(mask))
        return ids[-1] if ids else ""

    names = []
    for item in split_top_commas(ports):
        e = re.sub(r"//[^\n]*", "", item).strip()
        if not e:
            continue
        e = re.sub(r"^(input|output|inout)\b", "", e).strip()
        n = port_name(e)
        if n:
            names.append(n)
    imports = "".join(f"import {p};\n" for p in cfg.get("import", []))
    incs = "".join(f'  `include "{h}"\n' for h in cfg.get("includes", []))
    decls = "\n".join("  " + l.strip().rstrip(",") + ";" for l in ports.splitlines() if l.strip())
    Path(a.out).write_text(
        f"// GENERATED by test/ext_ip/gen_config_wrapper.py -- binds {a.module}'s\n"
        f"// configuration parameter `{pname}` so the module can be a top level.\n"
        f"// Widths written `{pname}.FIELD` in the DUT resolve against the config's\n"
        f"// identically-named localparams, which is how parameter-defs.vh builds\n"
        f"// the struct in the first place.\n"
        f"//\n"
        f"// The ports are declared NON-ANSI on purpose.  With an ANSI port list the\n"
        f"// configuration include has to sit ahead of the module, where its\n"
        f"// localparams land in the COMPILATION UNIT -- and Surelog then records the\n"
        f"// instance's `#({pname})` binding with no right-hand side at all, so the\n"
        f"// child is imported with `{pname}` unbound: every `{pname}.FIELD` inside it\n"
        f"// degenerates to one bit and most of the design disappears (read_uhdm gave\n"
        f"// cvw's csrc 25 cells and no memories against read_slang's 677 and two).\n"
        f"// Declaring the ports in the BODY lets the include sit inside the module,\n"
        f"// where `{pname}` is an ordinary module localparam and the instance\n"
        f"// specialises on it.\n"
        f"module {a.module}_cfg ({', '.join(names)});\n"
        f"{imports and ''.join('  ' + l + chr(10) for l in imports.splitlines())}"
        f"{incs}"
        + ("\n".join(extra) + "\n" if extra else "")
        + f"{decls}\n"
        f"  {a.module} #(.{pname}({pname}){''.join(f', .{n}({n})' for n in bound_extra)}) dut (.*);\n"
        f"endmodule\n")
    print(f"{a.module}: bound {pname} from {', '.join(cfg.get('includes', []))}")


if __name__ == "__main__":
    main()
