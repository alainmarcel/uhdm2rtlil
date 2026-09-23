#!/usr/bin/env python3
"""gen_param_wrapper.py --module M --manifest <family>.json --out wrap.sv <src.sv>...

Wrap a module whose DEFAULT parameters do not elaborate.

A sweep reads every module standalone, and PULP-style RTL is not written for
that: it declares its struct ports through TYPE PARAMETERS

    parameter type axi_req_t = logic,
    output axi_req_t mst_req_o,
    ... mst_req_o.aw_valid ...

so with the default binding the module accesses a member of a 1-BIT LOGIC.
read_slang rejects it ("invalid member access for type 'axi_req_t' (aka
'logic')") and read_uhdm folds the actual to a constant, which means there is
no reference to judge our netlist against -- 94 of the axi family's 108 modules
were excluded for exactly this reason, and the four that remained were the only
ones the sweep ever checked.

The values live in the family manifest's "bind" section, which supplies a
prelude (concrete typedefs, usually through the repo's own typedef macros) and
name patterns mapping a parameter to a binding.  This emits

    <prelude, as a package>
    module <M>_bound ( ...flat ports... );
      localparam <bound width parameters>
      <struct signals>; assign <-> flat ports
      <M> #(.<type params>(<bindings>), .<width params>(<values>)) dut (...);
    endmodule

Port widths are never computed here: a struct port becomes
`logic [$bits(pkg::T)-1:0]`, and a plain port declaration is copied verbatim --
the width parameters it names are localparams of the wrapper with the same
bound values, so the text resolves on its own.
"""
import argparse, json, re, sys
from pathlib import Path

CMT = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)


def strip_comments(t):
    return CMT.sub(lambda m: "\n" * m.group(0).count("\n"), t)


def split_top(s, sep=","):
    """Split on `sep` at nesting depth 0."""
    out, depth, cur = [], 0, []
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == sep and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        out.append("".join(cur))
    return [x.strip() for x in out if x.strip()]


def balanced(t, i):
    """Given t[i] == '(', return the index just past its matching ')'."""
    depth = 0
    while i < len(t):
        if t[i] == "(":
            depth += 1
        elif t[i] == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced parentheses")


def module_header(txt, name):
    """(param_text, port_text) of `module <name> #(...) (...);`"""
    m = re.search(r"\bmodule\s+" + re.escape(name) + r"\b", txt)
    if not m:
        sys.exit(f"# gen_param_wrapper: module {name} not found")
    i = m.end()
    params = ""
    j = txt.find("#", i)
    k = txt.find("(", i)
    if j != -1 and (k == -1 or j < k):
        s = txt.index("(", j)
        e = balanced(txt, s)
        params = txt[s + 1:e - 1]
        i = e
    s = txt.index("(", i)
    e = balanced(txt, s)
    return params, txt[s + 1:e - 1]


PARAM_RE = re.compile(
    r"^\s*(?:parameter|localparam)?\s*(type)?\s*(.*?)\s*(?:=\s*(.*))?$", re.S)


def parse_params(ptext):
    """[(kind, name, default)] with kind in {'type','value'}; localparams skipped."""
    out, kind_sticky = [], None
    for ent in split_top(ptext):
        e = " ".join(ent.split())
        if e.startswith("localparam"):
            kind_sticky = None
            continue
        explicit = e.startswith("parameter")
        if explicit:
            e = e[len("parameter"):].strip()
        istype = e.startswith("type ")
        if istype:
            e = e[len("type"):].strip()
        elif explicit:
            kind_sticky = None
        name, _, dflt = e.partition("=")
        # `int unsigned Foo` -> the NAME is the last identifier
        ids = re.findall(r"[A-Za-z_][A-Za-z_0-9$]*", name)
        if not ids:
            continue
        nm = ids[-1]
        if istype:
            kind_sticky = "type"
        out.append(("type" if istype or (not explicit and kind_sticky == "type")
                    else "value", nm, dflt.strip()))
    return out


DIR_RE = re.compile(r"^(input|output|inout)\b")
NETKW = {"wire", "logic", "reg", "var", "bit", "signed", "unsigned", "tri"}


def parse_ports(ptext):
    """[(dirn, type_name, dims, rest, name)].

    `input slv_req_t [N-1:0] slv_reqs_i` -> ('input', 'slv_req_t',
    '[N-1:0]', '', 'slv_reqs_i').  The type is the FIRST identifier after the
    direction/net keywords -- taking the last token instead makes an
    array-of-struct port look like a plain one and the wrapper then names a
    type that only exists inside the DUT.
    """
    out, last_dir = [], "input"
    for ent in split_top(ptext):
        e = " ".join(ent.split())
        if not e:
            continue
        m = DIR_RE.match(e)
        if m:
            last_dir = m.group(1)
            e = e[m.end():].strip()
        ids = re.findall(r"[A-Za-z_][A-Za-z_0-9$]*", e)
        if not ids:
            continue
        name = ids[-1]
        body = e[:e.rfind(name)].strip()
        toks = body.split()
        tname = ""
        for tk in toks:
            if tk in NETKW or tk.startswith("["):
                continue
            tname = tk
            break
        dims = ""
        dm = re.search(r"\[.*\]", body)
        if dm:
            dims = dm.group(0)
        out.append((last_dir, tname, dims, body, name))
    return out


def first_match(rules, name):
    for pat, val in rules:
        if re.search(pat, name):
            return val
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--pkg", default="bindpkg")
    ap.add_argument("srcs", nargs="+")
    a = ap.parse_args()

    bind = json.loads(Path(a.manifest).read_text()).get("bind")
    if not bind:
        sys.exit(f"# gen_param_wrapper: {a.manifest} has no \"bind\" section")
    types = [tuple(r) for r in bind.get("types", [])]
    values = [tuple(r) for r in bind.get("values", [])]
    default_value = bind.get("default_value", 4)

    txt = strip_comments("\n".join(
        Path(s).read_text(errors="replace") for s in a.srcs))
    ptext, porttext = module_header(txt, a.module)
    params = parse_params(ptext)
    ports = parse_ports(porttext)

    # A DEPENDENT type parameter is derived from another parameter
    # (`parameter type mem_addr_t = logic[MemAddrWidth-1:0]`) and the sources
    # say so in as many words -- "Dependent parameter do **not** overwrite!".
    # Only a bare `= logic` placeholder is ours to bind; overriding a derived
    # one decouples it from the width it is supposed to track.
    ZERO = re.compile(r"^(\d+'d)?0+$|^'0$")
    type_binds, value_binds, unbound, dep_types = {}, {}, [], {}
    for kind, nm, dflt in params:
        if kind == "type":
            if dflt and dflt.strip() != "logic":
                # Dependent: do not override it, but a port declared with it
                # still needs a type the wrapper can see, so remember the
                # expression and re-declare it in the package, where the
                # widths it names are localparams with the bound values.
                dep_types[nm] = dflt.strip()
                continue
            b = first_match(types, nm)
            if b is None:
                unbound.append(f"type {nm}")
            else:
                type_binds[nm] = f"{a.pkg}::{b}"
        else:
            b = first_match(values, nm)
            if b is None and ZERO.match(dflt.strip() or "x"):
                # A zero default in this style of RTL is a "you must override
                # me" marker, not a value.  Left alone it builds a degenerate
                # design -- axi_lite_from_mem's MaxRequests=0 gives a
                # zero-depth response FIFO, the two readers disagree about
                # what a full-on-empty FIFO does, and the row reports a
                # `differs` that says nothing about the frontend.
                b = default_value
            if b is not None:
                value_binds[nm] = str(b)
    if unbound:
        sys.exit(f"# gen_param_wrapper: no binding for {', '.join(unbound)} "
                 f"of {a.module}")
    if not type_binds:
        sys.exit(f"# gen_param_wrapper: {a.module} has no type parameters to bind")

    wrap = f"{a.module}_bound"
    L = [f"// GENERATED by test/ext_ip/gen_param_wrapper.py",
         f"// Flat-port wrapper binding {a.module}'s type parameters to concrete",
         f"// types, so the module elaborates as written instead of against the",
         f"// `= logic` defaults that no tool accepts.", ""]
    L += bind.get("prelude_raw", [])
    pkg_body = ["  " + x for x in bind.get("prelude", [])]

    # A struct port gets its own typedef in the PACKAGE, so a packed-array
    # port (`slv_req_t [N-1:0] slv_reqs_i`) flattens through one $bits() just
    # like a scalar one, and the dimension may name a bound parameter because
    # the package carries those as localparams too.
    pkg_extra = [f"  localparam int unsigned {k} = {v};"
                 for k, v in value_binds.items()]
    decls, wires, assigns, conns, ptypes = [], [], [], [], []

    def qualify(s):
        """Refer to bound parameters through the package (a module localparam
        is not visible in its own ANSI port list)."""
        for k in value_binds:
            s = re.sub(r"\b" + re.escape(k) + r"\b", f"{a.pkg}::{k}", s)
        return s

    for dirn, tname, dims, body, name in ports:
        if tname in type_binds or tname in dep_types:
            b = type_binds.get(tname) or dep_types[tname]
            tn = f"{name}_t"
            ptypes.append(f"  typedef {b} {tn} {dims};" if dims
                          else f"  typedef {b} {tn};")
            q = f"{a.pkg}::{tn}"
            decls.append(f"  {dirn} logic [$bits({q})-1:0] {name}_flat")
            wires.append(f"  {q} {name};")
            assigns.append(f"  assign {name} = {name}_flat;" if dirn == "input"
                           else f"  assign {name}_flat = {name};")
        else:
            decls.append(f"  {dirn} {qualify(body)} {name}".rstrip())
        conns.append(f".{name}({name})")

    pbind = [f".{k}({v})" for k, v in type_binds.items()] + \
            [f".{k}({a.pkg}::{k})" for k, v in value_binds.items()]

    L += [f"package {a.pkg};"] + pkg_body + pkg_extra + ptypes + ["endpackage", ""]
    L.append(f"module {wrap} (")
    L.append(",\n".join(decls))
    L.append(");")
    L += wires + assigns
    L.append(f"  {a.module} #(")
    L.append("    " + ",\n    ".join(pbind))
    L.append("  ) dut (")
    L.append("    " + ",\n    ".join(conns))
    L.append("  );")
    L.append("endmodule")
    Path(a.out).write_text("\n".join(L) + "\n")
    print(f"# wrote {a.out}: {wrap}, {len(type_binds)} type binding(s), "
          f"{len(value_binds)} value override(s), {len(decls)} ports")


if __name__ == "__main__":
    main()
