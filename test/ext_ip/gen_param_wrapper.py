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


def split_param_name(text):
    """(type text, name, unpacked dims) of one parameter declaration.

    The NAME is the last identifier that is not inside brackets: everything
    before it is the declared TYPE (`logic [RespWidth-1:0]`, `int unsigned`,
    `axi_pkg::resp_t`) and everything after it is an unpacked dimension
    (`IdMap [axi_pkg::iomsb(IdMapNumEntries):0][0:1]`).  Both halves matter to
    the wrapper's package: taking the last identifier outright picked one out of
    the DIMENSIONS (`IdMapNumEntries`, then declared twice -- "redefinition"),
    and hard-coding `int unsigned` as the type turned `parameter logic
    [RespWidth-1:0] RespData` into a syntax error (axi_err_slv, axi_lite_regs,
    axi_xbar, axi_xp).
    """
    mask, depth = [], 0
    for ch in text:
        if ch == "[":
            depth += 1
        mask.append(" " if (depth or ch == "]") else ch)
        if ch == "]":
            depth -= 1
    ids = list(re.finditer(r"[A-Za-z_][A-Za-z_0-9$]*", "".join(mask)))
    if not ids:
        return None
    last = ids[-1]
    return text[:last.start()].strip(), last.group(0), text[last.end():].strip()


def parse_params(ptext):
    """[(kind, name, default, dims, type)] with kind in {'type','value'}; localparams skipped."""
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
        split = split_param_name(name)
        if not split:
            continue
        ptype, nm, pdims = split
        if istype:
            kind_sticky = "type"
        out.append(("type" if istype or (not explicit and kind_sticky == "type")
                    else "value", nm, dflt.strip(), pdims, ptype))
    return out


DIR_RE = re.compile(r"^(input|output|inout)\b")
NETKW = {"wire", "logic", "reg", "var", "bit", "signed", "unsigned", "tri"}


def parse_ports(ptext):
    """[(dirn, type_name, dims, rest, name, unpacked_dims)].

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
        # Whatever follows the NAME is an UNPACKED dimension (`input logic
        # [W-1:0] audio_sample_word [1:0]`).  Dropped, the wrapper declared a
        # packed port and could not bind to its own DUT -- read_slang: "value of
        # type 'logic[15:0]' cannot be assigned to type 'logic[15:0]$[1:0]'"
        # (hdmi packet_picker).  Keep it, on the far side of the name.
        udims = e[e.rfind(name) + len(name):].strip()
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
        out.append((last_dir, tname, dims, body, name, udims))
    return out


def local_values(ptext):
    """[(decl text, name)] for non-type `localparam` entries of a parameter list.

    `localparam int unsigned MstPortsIdxWidth = ... $clog2(Cfg.NoMstPorts)` is
    declared in axi_xbar's own parameter list and used by a PORT, so the
    wrapper that copies the port must carry the localparam too, or it names
    something that exists only inside the DUT.
    """
    out = []
    for ent in split_top(ptext):
        e = " ".join(ent.split())
        if not e.startswith("localparam") or re.match(r"^localparam\s+type\b", e):
            continue
        body = e[len("localparam"):].strip()
        name, _, dflt = body.partition("=")
        sp = split_param_name(name)
        if sp and dflt.strip():
            ptype, nm, pdims = sp
            decl = f"  localparam {ptype or 'int unsigned'} {nm}" + (f" {pdims}" if pdims else "")
            out.append((f"{decl} = {dflt.strip()};", nm))
    return out


def local_types(ptext):
    """{name: type expression} for `localparam type X = logic [W-1:0]` entries.

    These are the DEPENDENT types this style of RTL declares in its own
    parameter list and then uses for ports (`output addr_t [NumBanks-1:0]
    mem_addr_o`).  parse_params skips localparams -- correctly, they must not be
    overridden -- but the wrapper copies the port declarations, so it has to
    declare them too or it names a type that exists only inside the DUT
    (read_slang: "use of undeclared identifier 'addr_t'", axi_to_mem and
    axi_to_detailed_mem).  They are re-declared in the package, where the bound
    parameter values are localparams, so the widths resolve there.
    """
    out = {}
    for ent in split_top(ptext):
        e = " ".join(ent.split())
        m = re.match(r"^localparam\s+type\s+(\w+)\s*=\s*(.+)$", e)
        if m:
            out[m.group(1)] = m.group(2).strip()
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
    # A module with no type parameters at all can still be unelaboratable at
    # its defaults -- axi_mux's `parameter NoSlvPorts = 0` selects bit [4:4] of
    # a 4-bit id, hdmi's packet_picker declares `[VIDEO_ID_CODE-1:0]` -- and
    # binding the VALUES alone is then the whole fix.  Only the retry path asks
    # for this, so a module that elaborates as written is never rewritten.
    ap.add_argument("--values-only", action="store_true")
    ap.add_argument("srcs", nargs="+")
    a = ap.parse_args()

    bind = json.loads(Path(a.manifest).read_text()).get("bind")
    if not bind:
        sys.exit(f"# gen_param_wrapper: {a.manifest} has no \"bind\" section")
    types = [tuple(r) for r in bind.get("types", [])]
    values = [tuple(r) for r in bind.get("values", [])]
    # "structs": [[name regex, literal], ...] -- a whole configuration struct
    # spelled out, for the `parameter <struct_t> Cfg = '0` idiom.
    structs = [tuple(r) for r in bind.get("structs", [])]
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
    type_binds, value_binds, unbound, dep_types, kept_types = {}, {}, [], {}, {}
    for kind, nm, dflt, _pdims, ptype in params:
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
                # values-only: keep it at its own default, but the package has
                # to DECLARE it -- the ports copied from the DUT name it
                # ("use of undeclared identifier 'data_t'").
                kept_types[nm] = (dflt.strip() or "logic")
            else:
                type_binds[nm] = f"{a.pkg}::{b}"
        else:
            b = first_match(structs, nm)
            if b is None:
                b = first_match(values, nm)
            # The scalar fallback is for an integral parameter only.  Applied to
            # a STRUCT configuration (`parameter axi_pkg::xbar_cfg_t Cfg = '0`,
            # axi_xbar) it assigned 4 to the whole struct and every field came
            # out degenerate anyway -- a configuration that builds and means
            # nothing, which is worse than an honest skip.  A struct needs a
            # literal, which the manifest supplies in "bind"."structs".
            integral = (not ptype) or bool(re.match(
                r"^(int|integer|bit|logic|reg|byte|shortint|longint|time)\b"
                r"[^.:]*$", ptype.strip()))
            if b is None and integral and ZERO.match(dflt.strip() or "x"):
                # A zero default in this style of RTL is a "you must override
                # me" marker, not a value.  Left alone it builds a degenerate
                # design -- axi_lite_from_mem's MaxRequests=0 gives a
                # zero-depth response FIFO, the two readers disagree about
                # what a full-on-empty FIFO does, and the row reports a
                # `differs` that says nothing about the frontend.
                b = default_value
            if b is not None:
                value_binds[nm] = str(b)
    if unbound and not a.values_only:
        sys.exit(f"# gen_param_wrapper: no binding for {', '.join(unbound)} "
                 f"of {a.module}")
    # In values-only mode an unbound `parameter type` keeps its own default:
    # the retry exists to fix a VALUE the design rejects (common_cells'
    # `SyncStages = 2` against its own "requires at least 3" elaboration
    # assertion), and a payload type left at `logic` is a legal configuration.
    # Refusing the whole wrapper for it threw away the fix.
    if not type_binds and not (a.values_only and value_binds):
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
    # EVERY value parameter, in declaration order, not only the bound ones: the
    # wrapper copies the DUT's port declarations, and those name parameters the
    # manifest has no rule for (`input logic [AxiIdBits-1:0] lookup_axi_id_i`
    # with `parameter AxiIdBits = 2` -- axi_demux_id_counters).  A parameter
    # left out is simply not visible in the wrapper's port list ("use of
    # undeclared identifier 'AxiIdBits'").  An unbound one keeps its own
    # default, which is the same expression the DUT evaluates, so the two
    # cannot disagree; declaration order lets a default name an earlier one
    # (`MaxTrans = 2**CounterWidth - 1`).
    pkg_extra, pkg_values = [], []
    for kind, nm, dflt, pdims, ptype in params:
        if kind == "type":
            continue
        v = value_binds.get(nm, dflt.strip())
        if v:
            # Its OWN declared type and dimensions: `logic [RespWidth-1:0]
            # RespData`, `int unsigned IdMap [N:0][0:1]`.  Hard-coding
            # `int unsigned` made a syntax error of every parameter whose type
            # carries a width (axi_err_slv, axi_lite_regs, axi_xbar, axi_xp).
            ty = ptype or "int unsigned"
            decl = f"  localparam {ty} {nm}" + (f" {pdims}" if pdims else "")
            pkg_extra.append(f"{decl} = {v};")
            pkg_values.append(nm)
    # ... then the module's own dependent types, which name those values.
    if a.values_only:
        pkg_extra += [f"  typedef {v} {k};" for k, v in kept_types.items()]
    for decl, nm in local_values(ptext):
        pkg_extra.append(decl)
        pkg_values.append(nm)
    ltypes = local_types(ptext)
    # The family prelude may already declare a type of the same name (axi's
    # `typedef logic [31:0] addr_t`, which the bound AddrWidth equals), and a
    # second declaration is a hard error ("redefinition of 'addr_t'").
    declared = set(re.findall(r"typedef\s+.*?\b(\w+)\s*;", "\n".join(bind.get("prelude", []))))
    ltypes = {k: v for k, v in ltypes.items() if k not in declared}
    # A TYPEDEF, not `localparam type`: Surelog SEGFAULTS on a `localparam type`
    # inside a package ("Design Elaboration..." then a core dump, axi_to_mem),
    # and a typedef is the package-level spelling of the same thing anyway.
    pkg_extra += [f"  typedef {v} {k};" for k, v in ltypes.items()]
    decls, wires, assigns, conns, ptypes = [], [], [], [], []

    def qualify(s):
        """Refer to bound parameters and dependent types through the package (a
        module localparam is not visible in its own ANSI port list)."""
        # `declared` too: a type the PRELUDE declares lives in the package, so a
        # port copied from the DUT must name it through the package as well.
        for k in pkg_values + list(ltypes) + list(kept_types) + sorted(declared):
            s = re.sub(r"\b" + re.escape(k) + r"\b", f"{a.pkg}::{k}", s)
        return s

    for dirn, tname, dims, body, name, udims in ports:
        if (tname in type_binds or tname in dep_types) and not udims:
            b = type_binds.get(tname) or dep_types[tname]
            tn = f"{name}_t"
            # `dims` is captured from the text BEFORE the port name, so it is
            # always a PACKED dimension.  `typedef T name [1:0]` would declare
            # an UNPACKED array instead, and the wrapper then failed to bind to
            # its own DUT: read_slang rejected the design with "no implicit
            # conversion from 'axi_aw_chan_t$[1:0]' to 'slv_aw_chan_t[1:0]'"
            # (the `$` is slang's marker for unpacked), and Surelog accepted the
            # mismatch silently.  Keep the dimension packed.
            ptypes.append(f"  typedef {b} {dims} {tn};" if dims
                          else f"  typedef {b} {tn};")
            q = f"{a.pkg}::{tn}"
            decls.append(f"  {dirn} logic [$bits({q})-1:0] {name}_flat")
            wires.append(f"  {q} {name};")
            assigns.append(f"  assign {name} = {name}_flat;" if dirn == "input"
                           else f"  assign {name}_flat = {name};")
        else:
            decls.append(f"  {dirn} {qualify(body)} {name} {qualify(udims)}".rstrip())
        conns.append(f".{name}({name})")

    pbind = [f".{k}({v})" for k, v in type_binds.items()] + \
            [f".{k}({a.pkg}::{k})" for k in kept_types] + \
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
