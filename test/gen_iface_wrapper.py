#!/usr/bin/env python3
"""Generate a flat-port wrapper around a module that has INTERFACE ports.

A SystemVerilog interface port is flattened by every RTLIL frontend into
escaped port names carrying a dot -- `\\m_axi_r_if.rready`.  Verilator cannot
take such a name as a port, so a port-by-port co-simulation testbench cannot be
built and the module is skipped (`NO_RUN (escaped port names: ...)`).  It is
NOT a frontend defect: read_uhdm and read_slang produce the identical
flattening, and the formal miter over the two netlists is unaffected.

The fix is to give the tools a module whose top level has no interface ports:

    module <M>_flat (ordinary ports, one per interface member);
      <iface> #(params) <inst> (...);          // interface lives INSIDE
      <M> dut (.<iface_port>(<inst>.<modport>), .<plain>(<plain>), ...);
      assign <inst>.<member> = <flat>;         // wrapper input  -> member
      assign <flat> = <inst>.<member>;         // member -> wrapper output
    endmodule

Everything needed is discoverable, so this works for any module:

  * the interface ports, from the module's own declaration
    (`axi_if.w_sub s_axi_w_if,`)
  * the interface's parameters, from its declaration
    (`interface axi_if #(parameter integer AW = 32, ...)`)
  * each parameter's VALUE, from the netlist: a member declared
    `logic [AW-1:0] araddr;` pins `AW` to the width of `<port>.araddr`, which
    the importer has already elaborated
  * the interface's own ports (`(input logic clk, input logic rst_n)`), matched
    by name against the DUT's ports

  usage: gen_iface_wrapper.py <netlist.il> <top> <out.sv> <rtl.sv>...
         [--rtl-top <name>]

`<top>` names the module in the NETLIST, which a per-module sweep frequently
renames (`soc_ifc_top1_uhdm`); `--rtl-top` names it in the SOURCES
(`soc_ifc_top`) when the two differ.
"""
import re, sys
from pathlib import Path

# Same role heuristics netlist_cosim.py uses, so the wrapper ties an
# interface's clk/rst_n to the port the testbench will actually drive.
CLK_RE = re.compile(r"^(clk|clock|tb_clk|rawclk|gw_clk|l1clk|clk_cg)$|(^|_)(clk|clock)_i$"
                    r"|_(clk|clock)$|^clk_[a-z0-9]+_i$|(^|_)tck$")
RST_RE = re.compile(r"(^|_)(rst|reset|por|pwrgood|trst)(_|$)|_rst\w*$")
LOW_RE = re.compile(r"(_n|_ni|_b|_l|_n_i|_b_i)$|(^|_)por_n|pwrgood|_l_i$")

WIRE = re.compile(r"^\s+wire\s+(?:width\s+(\d+)\s+)?(?:offset\s+(-?\d+)\s+)?"
                  r"(input|output|inout)\s+\d+\s+\\(\S+)\s*$")
# `axi_if.w_sub  s_axi_w_if,`  (an interface port, with modport)
IFACE_PORT = re.compile(r"^\s*([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*,?\s*(?://.*)?$")



# ---------------------------------------------------------------- decl mode
# When a module's interface ports are DEGENERATE standalone -- PULP's AXI_BUS
# has `parameter AXI_ADDR_WIDTH = 0`, so every member comes out 1 bit and the
# netlist carries no usable geometry -- the wrapper cannot take widths from the
# netlist the way the caliptra flow does.  Nothing needs evaluating, though:
# the member declarations can be COPIED VERBATIM out of the interface, and the
# wrapper given the interface's own parameter names, so the widths follow from
# elaborating the wrapper itself.

# A member may be declared with a bare type (`logic [X-1:0] aw_addr;`) OR with
# a TYPEDEF the interface declares itself (`addr_t aw_addr;` -- what PULP's
# AXI_BUS actually does).  Accept any leading identifier that is not a keyword,
# and copy the typedefs into the wrapper alongside the members.
_NOT_A_TYPE = {"typedef", "modport", "localparam", "parameter", "endinterface",
               "import", "export", "function", "task", "assign", "always",
               "initial", "generate", "endgenerate", "if", "else", "for"}
# The type may be package-qualified (`axi_pkg::len_t aw_len;`), which the
# wrapper can name verbatim as long as it reads the same package.
MEMBER = re.compile(r"^\s*((?:[A-Za-z_]\w*::)?[A-Za-z_]\w*)\s*(\[[^;]*?\])?\s*([A-Za-z_]\w*)\s*;")
TYPEDEF = re.compile(r"^\s*(typedef\s[^;]+;)\s*$", re.M)
IFPARAM = re.compile(r"parameter\s+(?:type\s+)?(?:[\w:]+\s+)*?(\w+)\s*=\s*([^,)]+)")
LOCALP = re.compile(r"^\s*(localparam\s[^;]+;)\s*$", re.M)


def iface_body(txt, iface):
    """(header, body) text of `interface <iface> ... endinterface`."""
    for src in txt.values():
        m = re.search(r"^\s*interface\s+" + re.escape(iface) + r"\b", src, re.M)
        if not m:
            continue
        end = re.search(r"^\s*endinterface\b", src[m.end():], re.M)
        stop = m.end() + (end.start() if end else len(src) - m.end())
        semi = src.find(";", m.end())
        return src[m.end():semi], src[semi + 1:stop]
    return None, None


def iface_members(body):
    """[(type, range_text_or_None, name)] in declaration order."""
    out = []
    for line in body.splitlines():
        line = re.sub(r"//.*", "", line)
        mm = MEMBER.match(line)
        if mm and mm.group(1) not in _NOT_A_TYPE:
            out.append((mm.group(1), mm.group(2), mm.group(3)))
    return out


def iface_modports(body):
    """{modport: {member: 'input'|'output'}} -- a direction keyword applies to
    every name after it until the next one."""
    res = {}
    for mm in re.finditer(r"modport\s+(\w+)\s*\((.*?)\)\s*;", body, re.S):
        name, inner = mm.group(1), re.sub(r"//.*", "", mm.group(2))
        cur, d = None, {}
        for tok in re.split(r"[,\s]+", inner):
            if tok in ("input", "output", "inout"):
                cur = tok
            elif tok and cur:
                d[tok] = cur
        res[name] = d
    return res


def netlist_ports(il_path, top):
    """[(width, dir, name)] for `top`, in declaration order."""
    out, inmod = [], False
    for line in open(il_path, errors="replace"):
        if line.startswith("module "):
            inmod = line.strip() == "module \\" + top
            continue
        if not inmod:
            continue
        if line.startswith("end"):
            break
        m = WIRE.match(line.rstrip("\n"))
        if m:
            out.append((int(m.group(1) or 1), m.group(3), m.group(4)))
    return out


def read_all(srcs):
    txt = {}
    for s in srcs:
        p = Path(s)
        if p.is_file():
            txt[str(p)] = p.read_text(errors="replace")
    return txt


def module_header(txt, name):
    """The text between `module <name>` and the end of its port list."""
    for body in txt.values():
        m = re.search(r"^\s*module\s+" + re.escape(name) + r"\b", body, re.M)
        if not m:
            continue
        # Walk to the matching ')' that closes the PORT list.  A module may
        # carry `import pkg::*;` lines and a `#( ... )` PARAMETER list first --
        # taking the first paren group would return the parameters instead
        # (caliptra's soc_ifc_top has both).
        i = m.end()
        while i < len(body):
            c = body[i]
            if c == "#":                      # parameter list: skip it whole
                j, depth, started = i, 0, False
                while j < len(body):
                    if body[j] == "(":
                        depth += 1; started = True
                    elif body[j] == ")":
                        depth -= 1
                        if started and depth == 0:
                            break
                    j += 1
                i = j + 1
                continue
            if c == "(":                      # the port list
                j, depth = i, 0
                while j < len(body):
                    if body[j] == "(":
                        depth += 1
                    elif body[j] == ")":
                        depth -= 1
                        if depth == 0:
                            return body[i + 1:j]
                    j += 1
                return None
            if body.startswith("import", i):  # `import pkg::*;` between the
                i = body.find(";", i)         # module name and its ports --
                if i < 0:                     # its ';' does NOT end the header
                    return None
                i += 1
                continue
            if c == ";":                      # no port list at all
                return None
            i += 1
    return None


def iface_ports_of(txt, top):
    """{port: (iface_type, modport)} declared by module `top`."""
    hdr = module_header(txt, top)
    if hdr is None:
        return {}
    found = {}
    for line in hdr.splitlines():
        line = re.sub(r"//.*", "", line)
        m = IFACE_PORT.match(line)
        if m and not re.match(r"^(input|output|inout|logic|wire|reg|bit|parameter|localparam|import)$", m.group(1)):
            found[m.group(3)] = (m.group(1), m.group(2))
    return found


def iface_decl(txt, iface):
    """(param_names, port_names, {param: member}) for `interface <iface>`."""
    for body in txt.values():
        m = re.search(r"^\s*interface\s+" + re.escape(iface) + r"\b", body, re.M)
        if not m:
            continue
        # header line(s) up to the ';' that ends the interface declaration
        end = body.find(";", m.end())
        hdr = body[m.end():end]
        params = re.findall(r"parameter\s+(?:\w+\s+)*?(\w+)\s*=", hdr)
        iports = re.findall(r"(?:input|output|inout)\s+(?:logic|wire|reg|bit)?\s*(\w+)\s*(?:,|$|\))", hdr)
        # body of the interface, for `logic [PARAM-1:0] member;`
        bend = re.search(r"^\s*endinterface\b", body[m.end():], re.M)
        ibody = body[end:m.end() + (bend.start() if bend else len(body))]
        # ALL members whose width is `[P-1:0]`, not just the first: a modport
        # only carries some of them, so the read half of axi_if pins DW from
        # `rdata` while the write half must use `wdata`.
        pmem = {}
        for p in params:
            pmem[p] = re.findall(
                r"\[\s*" + re.escape(p) + r"\s*-\s*1\s*:\s*0\s*\]\s*(\w+)\s*;", ibody)
        return params, iports, pmem
    return [], [], {}


def emit_from_decl(txt, rtl_top, ifaces, out, iface_params, dut_params):
    """Wrapper built from the INTERFACE DECLARATION rather than the netlist."""
    decls, insts, conns, dut, plines = [], [], [], [], []
    seen_param = set()
    locals_ = []
    for base, (iface, modport) in sorted(ifaces.items()):
        hdr, body = iface_body(txt, iface)
        if hdr is None:
            sys.exit(f"# gen_iface_wrapper: no declaration for interface {iface}")
        # the interface's own parameters become the WRAPPER's parameters, so the
        # member declarations below can be copied verbatim
        for pm in IFPARAM.finditer(hdr):
            nm, dflt = pm.group(1), pm.group(2).strip()
            if nm in seen_param:
                continue
            seen_param.add(nm)
            val = iface_params.get(nm, dflt)
            plines.append(f"  parameter int unsigned {nm} = {val}")
        # Localparams and typedefs must reach the PORT LIST, which the ports
        # below are declared with -- so they go into the ANSI parameter list as
        # `localparam` / `localparam type` entries, not into the body (a
        # typedef declared after the port list is "used before its
        # declaration").
        for lp in LOCALP.findall(body):
            e = lp.rstrip(";").strip()
            if e not in locals_:
                locals_.append(e)
        for td in TYPEDEF.findall(body):
            # `typedef logic [AXI_ID_WIDTH-1:0] id_t;` -> `localparam type id_t = logic [AXI_ID_WIDTH-1:0]`
            mm = re.match(r"typedef\s+(.*?)\s+(\w+)\s*;\s*$", td.strip(), re.S)
            if not mm:
                continue
            e = f"localparam type {mm.group(2)} = {mm.group(1).strip()}"
            if e not in locals_:
                locals_.append(e)
        mports = iface_modports(body)
        dirs = mports.get(modport, {})
        pv = ", ".join(f".{n}({n})" for n in seen_param)
        insts.append(f"  {iface} #({pv}) {base}_i ();" if pv else f"  {iface} {base}_i ();")
        dut.append(f"    .{base}({base}_i.{modport})")
        for ty, rng, mem in iface_members(body):
            d = dirs.get(mem)
            if not d:                      # not in this modport
                continue
            flat = f"{base}__{mem}"
            decls.append(f"  {d} {ty} {rng + ' ' if rng else ''}{flat}")
            if d == "input":
                conns.append(f"  assign {base}_i.{mem} = {flat};")
            else:
                conns.append(f"  assign {flat} = {base}_i.{mem};")
    # the DUT's own width parameters, matched by ROLE: this codebase spells them
    # ADDR_WIDTH / AXI_ADDR_WIDTH / ... interchangeably
    dparams = []
    for dn, dv in sorted(dut_params.items()):
        dparams.append(f".{dn}({dv})")
    # plain (non-interface) ports of the DUT
    hdr = module_header(txt, rtl_top)
    if hdr:
        for line in hdr.splitlines():
            line = re.sub(r"//.*", "", line).strip().rstrip(",")
            mm = re.match(r"^(input|output|inout)\s+(?:logic|wire|reg|bit)?\s*(\[[^\]]*\]\s*)?(\w+)$", line)
            if mm:
                d, rng, nm = mm.group(1), mm.group(2) or "", mm.group(3)
                decls.append(f"  {d} logic {rng}{nm}")
                dut.append(f"    .{nm}({nm})")
    with open(out, "w") as fh:
        fh.write(f"// GENERATED by test/gen_iface_wrapper.py (--from-decl).\n"
                 f"// Flat-port wrapper around {rtl_top}.  Its interface ports are\n"
                 f"// DEGENERATE standalone (the interface's width parameters default to 0),\n"
                 f"// so the ports below are the interface's own member declarations copied\n"
                 f"// verbatim and the wrapper carries the interface's parameter names --\n"
                 f"// no width has to be evaluated here.\n"
                 f"module {rtl_top}_flat #(\n")
        fh.write(",\n".join(plines + ["  " + l for l in locals_]) + "\n) (\n")
        fh.write(",\n".join(decls) + "\n);\n\n")
        fh.write("\n".join(insts) + "\n\n")
        pv = (" #(" + ", ".join(dparams) + ")") if dparams else ""
        fh.write(f"  {rtl_top}{pv} dut (\n" + ",\n".join(dut) + "\n  );\n\n")
        fh.write("\n".join(conns) + "\nendmodule\n")
    print(f"# wrote {out}: {len(decls)} ports, {len(insts)} interface instance(s) "
          f"from the interface declaration")


def main():
    argv = sys.argv[1:]
    rtl_top = None
    if "--rtl-top" in argv:
        i = argv.index("--rtl-top")
        rtl_top = argv[i + 1]
        del argv[i:i + 2]
    from_decl = "--from-decl" in argv
    if from_decl:
        argv.remove("--from-decl")
    iface_params, dut_params = {}, {}
    while "--iface-param" in argv:
        i = argv.index("--iface-param")
        k, _, v = argv[i + 1].partition("=")
        iface_params[k] = v
        del argv[i:i + 2]
    while "--dut-param" in argv:
        i = argv.index("--dut-param")
        k, _, v = argv[i + 1].partition("=")
        dut_params[k] = v
        del argv[i:i + 2]
    il, top, out = argv[0], argv[1], argv[2]
    rtl_top = rtl_top or top
    txt = read_all(argv[3:])
    if from_decl:
        ifaces = iface_ports_of(txt, rtl_top)
        if not ifaces:
            sys.exit(f"# gen_iface_wrapper: {rtl_top} declares no interface ports")
        emit_from_decl(txt, rtl_top, ifaces, out, iface_params, dut_params)
        return
    ports = netlist_ports(il, top)
    if not ports:
        sys.exit(f"# gen_iface_wrapper: no ports for {top} in {il}")
    ifaces = iface_ports_of(txt, rtl_top)
    dotted = sorted({n.split(".", 1)[0] for _, _, n in ports if "." in n})
    if not dotted:
        sys.exit(f"# gen_iface_wrapper: {top} has no flattened interface ports")
    missing = [d for d in dotted if d not in ifaces]
    if missing:
        sys.exit(f"# gen_iface_wrapper: no interface declaration found for "
                 f"{missing} in the given sources")

    by_name = {n: w for w, _, n in ports}
    # One interface INSTANCE per distinct (type, port-group); two modports of
    # the same physical interface (axi_if's w_/r_ halves) stay separate
    # instances here, which is correct for a per-module wrapper: the DUT sees
    # one modport each and nothing cross-couples them.
    decls, insts, conns, dut = [], [], [], []
    for base in dotted:
        iface, modport = ifaces[base]
        params, iports, pmem = iface_decl(txt, iface)
        pv = []
        for p in params:
            for mem in pmem.get(p, []):
                w = by_name.get(f"{base}.{mem}")
                if w:
                    pv.append(f".{p}({w})")
                    break
        pfx = f"#({', '.join(pv)}) " if pv else ""
        # The interface's own ports (clk / rst_n) are matched to the DUT's by
        # name; failing that, by ROLE, since a DUT rarely calls its reset
        # `rst_n` (caliptra's soc_ifc_top calls it `cptra_rst_b`).  An
        # interface port left dangling would leave the whole interface
        # unclocked or held in reset, so this fallback is load-bearing.
        dut_in1 = [n for w, d, n in ports if d == "input" and w == 1 and "." not in n]
        conn = []
        for ip in iports:
            if ip in by_name:
                conn.append(f".{ip}({ip})")
                continue
            cand = [n for n in dut_in1 if (RST_RE.search(n) if RST_RE.search(ip)
                                           else CLK_RE.search(n))]
            if RST_RE.search(ip):
                # A real reset beats a power-good strap: both match RST_RE, and
                # `cptra_pwrgood` sorts first in caliptra's port list, which
                # would leave the interface permanently in reset.
                strict = re.compile(r"(^|_)(rst|reset)(_|$)|_rst\w*$")
                cand = [n for n in cand if strict.search(n)] or cand
                # match active level: `rst_n`/`_b`/`_l` is active LOW
                lo = bool(LOW_RE.search(ip))
                pref = [n for n in cand if bool(LOW_RE.search(n)) == lo]
                cand = pref or cand
            if cand:
                conn.append(f".{ip}({cand[0]})")
        args = ", ".join(conn)
        insts.append(f"  {iface} {pfx}{base}_i ({args});")
        dut.append(f"    .{base}({base}_i.{modport})")

    for width, direction, name in ports:
        base, _, field = name.partition(".")
        rng = "" if width == 1 else f"[{width - 1}:0] "
        if not field:
            decls.append(f"  {direction} logic {rng}{name}")
            dut.append(f"    .{name}({name})")
            continue
        flat = f"{base}__{field}"
        decls.append(f"  {direction} logic {rng}{flat}")
        if direction == "input":
            conns.append(f"  assign {base}_i.{field} = {flat};")
        else:
            conns.append(f"  assign {flat} = {base}_i.{field};")

    with open(out, "w") as fh:
        fh.write(f"// GENERATED by test/gen_iface_wrapper.py -- do not edit.\n"
                 f"// Flat-port wrapper around {rtl_top}: each interface port becomes a set of\n"
                 f"// ordinary ports, so a co-sim testbench can drive it (Verilator cannot\n"
                 f"// take an escaped port name containing a dot).\n"
                 f"module {rtl_top}_flat (\n")
        fh.write(",\n".join(decls) + "\n);\n\n")
        fh.write("\n".join(insts) + "\n\n")
        fh.write(f"  {rtl_top} dut (\n" + ",\n".join(dut) + "\n  );\n\n")
        fh.write("\n".join(conns) + "\nendmodule\n")
    print(f"# wrote {out}: {len(decls)} ports, {len(insts)} interface instance(s) "
          f"for {', '.join(dotted)}")


main()
