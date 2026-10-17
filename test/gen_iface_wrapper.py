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
         [--rtl-top <name>] [--manifest <family>.json]

`--manifest` binds the width parameters that default to 0 -- both the
interface's and the DUT's -- from the family manifest's `bind.values`, so a
module written to be configured (`parameter int unsigned ADDR_WIDTH = 0`) does
not merely trade its interface-port rejection for a negative-range one.

`<top>` names the module in the NETLIST, which a per-module sweep frequently
renames (`soc_ifc_top1_uhdm`); `--rtl-top` names it in the SOURCES
(`soc_ifc_top`) when the two differ.
"""
import json, re, sys
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
# `axi_if.w_sub s_axi_w_if,` and the ARRAY form `AXI_BUS.Master mst [N-1:0]`
# (PULP's axi_demux_intf / axi_mux_intf / axi_xbar_intf).  An array port needs an
# array of interface INSTANCES in the wrapper and one set of flat ports per
# element; without it the row could not be co-simulated at all ("Interface port
# 'mst' is not connected to interface/modport pin expression").
IFACE_PORT = re.compile(r"^\s*([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s+([A-Za-z_]\w*)"
                        r"\s*(\[[^\]]*\])?\s*,?\s*(?://.*)?$")



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
# ... and the member may carry UNPACKED dimensions after its name
# (`MemoryPortMultiplexerIn mshrMemMuxIn[MSHR_NUM];`, RSD's DCacheIF): group 4.
MEMBER = re.compile(r"^\s*((?:[A-Za-z_]\w*::)?[A-Za-z_]\w*)\s*(\[[^;]*?\])?\s*([A-Za-z_]\w*)\s*((?:\[[^\]]*\]\s*)*);")
TYPEDEF = re.compile(r"^\s*(typedef\s[^;]+;)\s*$", re.M)
IFPARAM = re.compile(r"parameter\s+(?:type\s+)?(?:[\w:]+\s+)*?(\w+)\s*=\s*([^,)]+)")
# Same, but KEEPING the declared type: a parameter of a user-defined type must
# not be re-declared `int unsigned` (see the emission site).
IFPARAM_T = re.compile(r"parameter\s+((?:[\w:]+\s+)*?)(\w+)\s*=\s*([^,)]+)")
_INTEGRAL = {"int", "integer", "logic", "bit", "byte", "shortint", "longint",
             "unsigned", "signed", "reg", "time", "real", "realtime", "type"}
LOCALP = re.compile(r"^\s*(localparam\s[^;]+;)\s*$", re.M)


# --- parameter VALUES from a family manifest --------------------------------
# A module whose interface ports are degenerate standalone almost always has
# degenerate WIDTH parameters as well -- axi_cut_intf declares `ADDR_WIDTH = 0`
# and AXI_BUS declares `AXI_ADDR_WIDTH = 0`, so the wrapper elaborates with
# `[-1:0]` ports and read_slang rejects it for a NEGATIVE RANGE instead of for
# the interface port we just wrapped away.  The external-IP manifests already
# carry the values the family is meant to be swept at (`bind.values`, a list of
# [name regex, value]); with `--manifest` the wrapper binds both its own
# interface parameters and the DUT's from that one list, so the two agree by
# construction (`AXI_ADDR_WIDTH` and `ADDR_WIDTH` both match `(?i)addr_?width$`).
_ZERO = re.compile(r"^(?:\d+'[sdbhoSDBHO]+)?0+$|^'0$")


def manifest_defines(path):
    """The `defines` the sweep reads this family with (ext_flow's own default
    when the manifest does not say)."""
    try:
        man = json.loads(Path(path).read_text())
    except Exception:
        return ["SYNTHESIS"]
    return man.get("defines", ["SYNTHESIS"])


def manifest_values(path):
    """[(name regex, value)] from the manifest's "bind" section."""
    bind = json.loads(Path(path).read_text()).get("bind") or {}
    return [tuple(r) for r in bind.get("values", [])]


def first_match(rules, name):
    for pat, val in rules:
        if re.search(pat, name):
            return str(val)
    return None


def bound_value(rules, name, dflt):
    """The manifest's value for parameter `name`, or None to keep `dflt`.

    Only a DEGENERATE default is overridden.  A parameter with a real default
    is the module's own choice and rebinding it would sweep something the
    family never asked for -- and `bit BYPASS = 1'b0` is a real default that a
    width rule must not touch, which is why the rule has to match the NAME.
    """
    if dflt and not _ZERO.match(dflt.strip()):
        return None
    return first_match(rules, name)


def module_param_text(txt, name):
    """The text inside `module <name> #( ... )`, or '' when it has none."""
    for body in txt.values():
        m = re.search(r"^\s*module\s+" + re.escape(name) + r"\b", body, re.M)
        if not m:
            continue
        i = m.end()
        while i < len(body) and body[i] not in "#(;":
            if body.startswith("import", i):
                i = body.find(";", i)
                if i < 0:
                    return ""
                i += 1
                continue
            i += 1
        if i >= len(body) or body[i] != "#":
            return ""
        s = body.index("(", i)
        depth, j = 0, s
        while j < len(body):
            if body[j] == "(":
                depth += 1
            elif body[j] == ")":
                depth -= 1
                if depth == 0:
                    return body[s + 1:j]
            j += 1
        return ""
    return ""


def module_value_params(txt, name):
    """[(param, default)] of the module's non-type parameters."""
    ptext = re.sub(r"//[^\n]*", "", module_param_text(txt, name))
    out, depth, cur = [], 0, []
    ents = []
    for ch in ptext:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            ents.append("".join(cur)); cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        ents.append("".join(cur))
    for ent in ents:
        e = " ".join(ent.split())
        if e.startswith("localparam") or re.match(r"(parameter\s+)?type\b", e):
            continue
        e = re.sub(r"^parameter\s+", "", e)
        nm, _, dflt = e.partition("=")
        ids = re.findall(r"[A-Za-z_][A-Za-z_0-9$]*", nm)
        if ids:
            out.append((ids[-1], dflt.strip()))
    return out


def module_param_decls(txt, name):
    """[(name, default)] of EVERY entry of the module's parameter port list,
    `localparam` ones included, in declaration order.

    `module_value_params` deliberately skips localparams (they cannot be
    overridden, so they are not bindable), but a copied port declaration may
    still be sized by one: caliptra-ss's axi_adapter writes `localparam int
    unsigned CsrAddrWidth = 12` in its parameter list and declares `output
    logic [CsrAddrWidth-1:0] s_cpuif_addr`.  The wrapper copies that port
    verbatim, so it has to declare the parameter too or Verilator stops at
    "Can't find definition of variable: 'CsrAddrWidth'"."""
    ptext = re.sub(r"//[^\n]*", "", module_param_text(txt, name))
    out, depth, cur, ents = [], 0, [], []
    for ch in ptext:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            ents.append("".join(cur)); cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        ents.append("".join(cur))
    for ent in ents:
        e = " ".join(ent.split())
        if re.match(r"(parameter\s+|localparam\s+)?type\b", e):
            continue
        e = re.sub(r"^(parameter|localparam)\s+", "", e)
        nm, _, dflt = e.partition("=")
        ids = re.findall(r"[A-Za-z_][A-Za-z_0-9$]*", nm)
        if ids and dflt.strip():
            out.append((ids[-1], dflt.strip()))
    return out


def _ids(text):
    return set(re.findall(r"[A-Za-z_][A-Za-z_0-9]*", text or ""))


def dut_param_locals(txt, rtl_top, used, known, values):
    """`localparam` lines for the DUT parameters a copied port declaration names.

    Only the ones actually referenced, transitively (axi_adapter's
    `LowerAddrBits = $clog2(CsrDataWidth/8)` pulls `CsrDataWidth` in), and never
    a name the wrapper already declares -- the interface's own parameters win,
    they are what the member declarations are written against.  A parameter the
    manifest binds is declared at the BOUND value, the same one the DUT instance
    is specialised with."""
    decls = module_param_decls(txt, rtl_top)
    byname = dict(decls)
    want, pending = set(), set(i for i in used if i in byname and i not in known)
    while pending:
        nm = pending.pop()
        if nm in want:
            continue
        want.add(nm)
        for i in _ids(values.get(nm) or byname[nm]):
            if i in byname and i not in known and i not in want:
                pending.add(i)
    return [f"localparam {nm} = {values.get(nm) or dflt}"
            for nm, dflt in decls if nm in want]


def resolve_iface_bits(expr, ifaces, txt):
    """Rewrite `$bits(<iface port>.<member>[.<field>])` to `$bits(<its type>)`.

    caliptra-ss's mci_axi_sub_decode sizes four ordinary ports off one of its
    own interface ports -- `input logic [$bits(soc_resp_if.req_data.user)-1:0]
    strap_mcu_lsu_axi_user`.  Copied verbatim the name means nothing in the
    wrapper (the instance is `soc_resp_if_i`, and it is declared after the port
    list anyway), and Verilator stopped at "Can't find definition of
    scope/variable: 'soc_resp_if'".  The member's declared type is right there
    in the interface, and it is written over the interface parameters the
    wrapper already declares, so substituting it resolves the port."""
    def one(m):
        base, path = m.group(1), [q for q in m.group(2).split(".") if q]
        if base not in ifaces:
            return m.group(0)
        iface = ifaces[base][0]
        hdr, body = iface_body(txt, iface)
        if body is None:
            return m.group(0)
        ty, rng = None, None
        for t, r, nm in iface_members(body):
            if nm == path[0]:
                ty, rng = t, r
                break
        if ty is None:
            return m.group(0)
        for field in path[1:]:
            td = next((t for t in iface_typedefs(body)
                       if re.search(r"\}\s*" + re.escape(ty) + r"\s*;\s*$", t.strip())),
                      None)
            if td is None:
                return m.group(0)
            fm = next((mm for mm in (MEMBER.match(l.strip())
                                     for l in re.sub(r"//.*", "", td).splitlines())
                       if mm and mm.group(3) == field), None)
            if fm is None:
                return m.group(0)
            ty, rng = fm.group(1), fm.group(2)
        # The result is substituted INSIDE a `[...]` port range, so it must not
        # contain a bracket of its own: `[$bits(logic [UW-1:0])-1:0]` does not
        # parse as one range and the port was silently dropped instead.  A
        # declared `[msb:lsb]` is its own width expression.
        if rng:
            mb = re.match(r"^\s*\[(.+):(.+)\]\s*$", rng)
            if not mb:
                return m.group(0)
            return f"(({mb.group(1).strip()})-({mb.group(2).strip()})+1)"
        return "1" if ty in ("logic", "bit", "reg", "wire") else f"$bits({ty})"
    return re.sub(r"\$bits\s*\(\s*(\w+)((?:\s*\.\s*\w+)+)\s*\)", one, expr)


def _dim_count(dim, params):
    """Element count of an interface-array dimension: `[3]`, `[N-1:0]`, `[0:N-1]`.

    The bounds may name the DUT's own parameters, which the manifest has already
    bound to values, so substitute those and evaluate.
    """
    inner = dim.strip().strip("[]").strip()
    if not inner:
        return None
    def val(expr):
        e = expr
        for _ in range(8):      # parameters may be defined in terms of others
            new = re.sub(r"[A-Za-z_]\w*",
                         lambda m: str(params.get(m.group(0), m.group(0))), e)
            if new == e:
                break
            e = new
        # SystemVerilog literals: `32'd3`, `4'hf`, `8'b1010`, plain decimals.
        # A naive `replace("'d", "")` turned `32'd3` into THREE HUNDRED AND
        # TWENTY-THREE and sized an interface array at 323 elements.
        def lit(m):
            w, base, digits = m.group(1), (m.group(2) or "d").lower(), m.group(3)
            try:
                return str(int(digits, {"d": 10, "h": 16, "b": 2, "o": 8}[base]))
            except (ValueError, KeyError):
                return "0"
        e = re.sub(r"(\d+)'([sSdDhHbBoO]?)[sS]?([0-9a-fA-F_]+)", lit, e)
        try:
            return int(eval(e, {"__builtins__": {}}, {}))
        except Exception:
            return None
    if ":" in inner:
        a, b = inner.split(":", 1)
        va, vb = val(a), val(b)
        if va is None or vb is None:
            return None
        return abs(va - vb) + 1
    v = val(inner)
    return v if v and v > 0 else None


def _iface_own_ports(ihdr):
    """[(dir, range_text, name)] of an interface's OWN ports, from its header.

    A grouped list (`interface LoadStoreUnitIF( input logic clk, rst, rstStart )`,
    every RSD interface) carries the direction and type once; the old
    regex only saw the first name after a direction keyword, so `rst` and
    `rstStart` were never even considered for binding.
    """
    i = ihdr.find("(")
    if i < 0:
        return []
    inner = ihdr[i + 1:]
    j = inner.rfind(")")
    if j >= 0:
        inner = inner[:j]
    inner = re.sub(r"//.*", "", inner)
    out, d, rng = [], None, ""
    for tok in inner.split(","):
        tok = " ".join(tok.split())
        if not tok:
            continue
        m = re.match(r"^(?:(input|output|inout)\s+)?(?:(?:logic|wire|reg|bit)\s*)?(\[[^\]]*\]\s*)?(\w+)$", tok)
        if not m:
            continue
        if m.group(1):
            d, rng = m.group(1), ""
        if m.group(2):
            rng = m.group(2).strip()
        if d:
            out.append((d, rng, m.group(3)))
    return out


def _iface_port_conns(ihdr, plain):
    """(`.clk(clk_i), .rst_n(cptra_rst_b)`, unbound) for an interface's OWN ports.

    An interface declared `(input logic clk, input logic rst_n)` left
    unconnected is unclocked, or held in reset forever, and the DUT behind it
    then does nothing at all.  The DUT rarely spells them the same way, so the
    match is by name first and by ROLE second -- the netlist path below has
    done this for a year; the decl path simply never did.

    `unbound` lists the interface inputs no DUT port matches: a module whose
    ports are ALL interfaces (every RSD pipeline stage: `LoadStoreUnit(
    LoadStoreUnitIF.LoadStoreUnit port, ControllerIF.LoadStoreUnit ctrl)`) has
    nothing to tie `clk` / `rst` to, and the wrapper left them undriven --
    every register inside clocked from a free variable, the miter and the
    co-sim comparing two unclocked netlists.  The caller exposes them as
    wrapper ports instead.
    """
    iports = _iface_own_ports(ihdr)
    names = [n for d, rng, n in plain]
    scalars = [n for d, rng, n in plain if d == "input" and not rng]
    conn, unbound = [], []
    for ipd, iprng, ip in iports:
        if ip in names:
            conn.append(f".{ip}({ip})")
            continue
        isrst = bool(RST_RE.search(ip))
        cand = [n for n in scalars if (RST_RE.search(n) if isrst else CLK_RE.search(n))]
        if isrst:
            strict = re.compile(r"(^|_)(rst|reset)(_|$)|_rst\w*$")
            cand = [n for n in cand if strict.search(n)] or cand
            lo = bool(LOW_RE.search(ip))
            cand = [n for n in cand if bool(LOW_RE.search(n)) == lo] or cand
        if cand:
            conn.append(f".{ip}({cand[0]})")
        elif ipd == "input":
            conn.append(f".{ip}({ip})")
            unbound.append((iprng, ip))
    return ", ".join(conn), unbound


def iface_header_end(src, start, stop):
    """Index of the `;` that ends an interface DECLARATION, not the first one.

    `src.find(";", start)` is wrong whenever the interface imports a package
    before its parameter list, which is how every tnoc interface is written:

        interface tnoc_flit_if
          import  tnoc_pkg::*;          <-- the first `;`
        #(parameter ... )(tnoc_types types);

    Taking that semicolon as the end of the header left the parameter list AND
    the port list inside the `body`, so iface_members read `#(`, the parameters
    and the ports as members and the emitted wrapper was nonsense -- literally
    `import import  get_channel_ack;`, which Surelog rejects (tnoc_dummy_node
    and every other tnoc interface user).

    Skip leading `import`/`export` statements, then balance () and [] so the
    header ends at the first top-level `;` after the port list.
    """
    i, n = start, stop
    while True:
        m = re.match(r"\s*(?://[^\n]*\n|/\*.*?\*/\s*)*\s*(import|export)\b", src[i:n], re.S)
        if not m:
            break
        semi = src.find(";", i + m.end())
        if semi < 0 or semi >= n:
            break
        i = semi + 1
    depth = 0
    while i < n:
        c = src[i]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif c == ";" and depth <= 0:
            return i
        elif c == "/" and i + 1 < n and src[i + 1] == "/":
            i = src.find("\n", i)
            if i < 0:
                break
            continue
        elif c == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i)
            i = (j + 2) if j > 0 else n
            continue
        i += 1
    return src.find(";", start)        # unchanged fallback


def iface_body(txt, iface):
    """(header, body) text of `interface <iface> ... endinterface`.

    Also records the whole file in `iface_body.src`, because the macros its body
    invokes are defined by an `include` at the top of that file.
    """
    for src in txt.values():
        m = re.search(r"^\s*interface\s+" + re.escape(iface) + r"\b", src, re.M)
        if not m:
            continue
        end = re.search(r"^\s*endinterface\b", src[m.end():], re.M)
        stop = m.end() + (end.start() if end else len(src) - m.end())
        semi = iface_header_end(src, m.end(), stop)
        iface_body.src = src
        return src[m.end():semi], src[semi + 1:stop]
    return None, None


def declared_ifaces(txt):
    """Every `interface <name>` declared in the given sources."""
    out = set()
    for body in txt.values():
        out.update(re.findall(r"^\s*interface\s+(\w+)", body, re.M))
    return out


def iface_iface_ports(txt, iface):
    """[(type, name)] ports of `iface` whose type is ANOTHER interface.

    tnoc's interfaces take the typedef-exporting `tnoc_types` as a port:

        interface tnoc_flit_if import tnoc_pkg::*;
        #(parameter tnoc_packet_config PACKET_CONFIG = ..., ...)
        (tnoc_types  types);
          typedef types.tnoc_flit tnoc_flit;      <-- members are declared over it

    Such a port carries no direction, so iface_decl's
    `(?:input|output|inout)` scan never saw it and the instance was emitted as
    `tnoc_flit_if receiver_if_i ()` -- which cannot elaborate, the interface
    needs its `types`.  Everything the members are declared over comes through
    that port, so it is load-bearing rather than decorative.
    """
    hdr, _ = iface_body(txt, iface)
    if hdr is None:
        return []
    known = declared_ifaces(txt)
    # the port list is the LAST parenthesised group of the header
    groups = re.findall(r"\(([^()]*)\)", hdr, re.S)
    if not groups:
        return []
    out = []
    for item in groups[-1].split(","):
        item = re.sub(r"//[^\n]*", "", item).strip()
        m = re.match(r"^(\w+)(?:\.\w+)?\s+(\w+)$", item)
        if m and m.group(1) in known:
            out.append((m.group(1), m.group(2)))
    return out


def iface_members(body):
    """[(type, range_text_or_None, name)] in declaration order -- the
    members WITHOUT unpacked dimensions (the netlist-side wrapper has no
    flat spelling for an array member; iface_members_full has them)."""
    return [(t, r, n) for t, r, n, u in iface_members_full(body) if not u]


def iface_members_full(body):
    """[(type, range_text_or_None, name, unpacked_dims_text)] in declaration
    order; unpacked_dims_text is "" for a plain member."""
    out = []
    for line in body.splitlines():
        line = re.sub(r"//.*", "", line)
        mm = MEMBER.match(line)
        if mm and mm.group(1) not in _NOT_A_TYPE:
            out.append((mm.group(1), mm.group(2), mm.group(3),
                        re.sub(r"\s+", "", mm.group(4) or "")))
    return out


def _unpacked_dim_exprs(dims):
    """`[N][A:B]` -> [(count_expr, low_expr), ...] as SV expressions."""
    res = []
    for d in re.findall(r"\[([^\]]*)\]", dims):
        d = d.strip()
        if ":" in d:
            a, b = (x.strip() for x in d.split(":", 1))
            res.append((f"((({a})>({b}))?(({a})-({b})+1):(({b})-({a})+1))",
                        f"((({a})<({b}))?({a}):({b}))"))
        else:
            res.append((f"({d})", "0"))
    return res


def iface_typedefs(body):
    """Every `typedef ... ;` in the interface, whole.

    A regex `typedef[^;]+;` truncates a STRUCT typedef at the first member's
    semicolon (`typedef struct packed { logic [DW-1:0] data;` ...), and the
    fragment copied into the wrapper's parameter list is a syntax error that
    makes the whole design unreadable -- caliptra-ss's axi_mem and mcu_mbox
    both declare their interface members over a packed struct.  Scan to the
    `;` at brace depth 0 instead.
    """
    out, i = [], 0
    while True:
        m = re.compile(r"(^|\n)\s*typedef\s", re.M).search(body, i)
        if not m:
            return out
        j, depth = m.end(), 0
        while j < len(body):
            c = body[j]
            if c in "{[(":
                depth += 1
            elif c in "}])":
                depth -= 1
            elif c == ";" and depth == 0:
                break
            j += 1
        out.append(body[m.end() - len("typedef "):j + 1])
        i = j + 1


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


def guard_free_defines(body):
    """The `define names a file really contributes -- WITHOUT its include guard.

    A WHOLE-FILE include guard defines its macro inside the `ifndef that tests
    it, so a flat scan for `define reports the guard as already defined, the
    `ifndef evaluates FALSE, and strip_inactive blanks THE ENTIRE FILE:

        `ifndef TNOC_FLIT_IF_SV
        `define TNOC_FLIT_IF_SV
        interface tnoc_flit_if ...
        `endif                      <-- end of file

    Every tnoc interface and package is written that way (9 files), so
    iface_body found no declaration for tnoc_flit_if, the interface wrapper
    declined, and the fallback flat wrapper emitted `input tnoc_flit_if.sender
    sender_if` -- not legal SystemVerilog.  24 of tnoc's 43 rows were lost to
    it (12 `elab-fail`, 12 `no reference`).

    The DEFAULT-SETTING idiom opens identically and means the OPPOSITE:

        `ifndef REF
        `define REF
        `endif                      <-- three lines, file continues

    there the macro IS defined afterwards and gates real code (`ifdef REF` in
    RSD's ReadyBitTable / SourceCAM).  Dropping it flipped those arms off and
    silently cost RSD wrappers ports -- ActiveList 40 -> 36, CSR_Unit 26 -> 22,
    FPExecutionStage 34 ports -> no wrapper at all.  Measured with the offline
    old-vs-new diff over all 334 module work dirs, which is the only way this
    was visible.

    So the discriminator is NOT the idiom's opening but its EXTENT: a guard
    whose `endif is the last thing in the file is an include guard; anything
    shorter is a default.
    """
    guards = set()
    stack = []                      # [(name, index_of_directive)]
    for m in re.finditer(r"^[ \t]*`(ifndef|ifdef|elsif|else|endif|define)\b[ \t]*(\w+)?",
                         body, re.M):
        kind, nm = m.group(1), m.group(2)
        if kind in ("ifndef", "ifdef"):
            stack.append((nm if kind == "ifndef" else None, m.start()))
        elif kind == "endif":
            if not stack:
                continue
            nm_open, _ = stack.pop()
            if nm_open and not stack:
                # tail after this `endif: only whitespace/comments -> whole-file guard
                tail = body[m.end():]
                tail = re.sub(r"//[^\n]*", "", tail)
                tail = re.sub(r"/\*.*?\*/", "", tail, flags=re.S)
                if not tail.strip():
                    guards.add(nm_open)
        elif kind in ("else", "elsif") and stack:
            stack[-1] = (None, stack[-1][1])
    names = set(re.findall(r"^\s*`define\s+(\w+)", body, re.M))
    return names - guards


def defined_names(txt, defines):
    """Macro names that are defined when the sweep reads these sources.

    The sweep hands every design ONE define set (the manifest's `defines`), so
    which arm of a `ifdef the elaborated module really has is knowable: a name
    counts as defined when the manifest lists it, when any source `define's it,
    or when an included header next to a source does."""
    names = set(defines)
    for body in txt.values():
        names.update(guard_free_defines(body))
    seen = set()
    for path, body in txt.items():
        d = Path(path).parent
        for inc in re.findall(r"^\s*`include\s+\"([^\"]+)\"", body, re.M):
            for cand in (d / inc, d / Path(inc).name):
                if cand.is_file() and str(cand) not in seen:
                    seen.add(str(cand))
                    names.update(re.findall(r"^\s*`define\s+(\w+)",
                                            cand.read_text(errors="replace"), re.M))
    return names


def strip_inactive(txt, defines):
    """Blank the `ifdef arms the sweep's define set does NOT take.

    A regex scan of a module declaration sees every arm at once: caliptra-ss's
    i3c declares its frontend bus as `ifdef I3C_USE_AHB <13 AHB ports> `elsif
    I3C_USE_AXI <two interface ports>, and neither macro is defined anywhere in
    the repository.  The wrapper was therefore generated for interface ports
    the elaborated module does not have, over AHB ports it does not have
    either, and Verilator stopped at "Can't find definition of variable:
    'AhbAddrWidth'" -- the sweep could only report `skip (sim build)`, with
    nothing measured for i3c or i3c_wrapper.

    Inactive lines are blanked rather than removed so every diagnostic keeps
    pointing at the right line of the original file."""
    names = defined_names(txt, defines)
    out = {}
    for path, body in txt.items():
        if "`if" not in body:
            out[path] = body
            continue
        res, stack = [], []        # [taken_any, active_now, parent_active]
        for line in body.splitlines(True):
            nl = "\n" if line.endswith("\n") else ""
            m = re.match(r"`(ifdef|ifndef|elsif|else|endif)\b\s*(\w+)?", line.strip())
            if m:
                kind, nm = m.group(1), m.group(2)
                parent = stack[-1][1] if stack else True
                if kind in ("ifdef", "ifndef"):
                    cond = (nm in names) if kind == "ifdef" else (nm not in names)
                    stack.append([cond, cond and parent, parent])
                elif stack and kind == "elsif":
                    taken, _, parent = stack[-1]
                    cond = (not taken) and (nm in names)
                    stack[-1] = [taken or cond, cond and parent, parent]
                elif stack and kind == "else":
                    taken, _, parent = stack[-1]
                    stack[-1] = [True, (not taken) and parent, parent]
                elif stack and kind == "endif":
                    stack.pop()
                res.append(nl)
                continue
            res.append(line if (not stack or stack[-1][1]) else nl)
        out[path] = "".join(res)
    return out


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


def _enum_scope(txt, ty):
    """`pkg::` when the enum typedef `ty` lives in a package, else "".

    The flat wrapper imports nothing, so a cast to a PACKAGE enum must name
    the package (tnoc_axi_pkg's tnoc_axi_burst_size, read_slang: "no implicit
    conversion from 'logic[2:0]' to 'tnoc_axi_burst_size'" on a plain
    `assign slave_if_i.awsize = slave_if__awsize`).  A typedef in a module or
    interface body is cast by its bare name as before.
    """
    pat = re.compile(r"\btypedef\s+enum\b[^;]*?\b" + re.escape(ty) + r"\s*;", re.S)
    for body in txt.values():
        m = pat.search(body)
        if not m:
            continue
        pkg = None
        for pm in re.finditer(r"^\s*(package|endpackage)\b\s*(\w+)?", body[:m.start()], re.M):
            pkg = pm.group(2) if pm.group(1) == "package" else None
        return f"{pkg}::" if pkg else ""
    return ""


def _is_enum_type(txt, ty):
    """True when `ty` is a typedef'd ENUM anywhere in the collected sources.

    Only an ENUM needs an explicit cast: SystemVerilog has no implicit
    conversion TO an enum, so read_slang rejects
    `assign port_i.rm[g] = port__rm[...]` with "no implicit conversion from
    'logic[2:0]' to 'Rounding_Mode'" while Verilator accepts it.  A typedef'd
    vector or packed struct converts implicitly and must be left alone -- a
    blanket cast would rewrite hundreds of assigns in ~69 existing wrappers
    for no reason.
    """
    if not ty or ty in ("logic", "bit", "reg", "wire", "int", "integer", "byte"):
        return False
    pat = re.compile(r"\btypedef\s+enum\b[^;]*?\b" + re.escape(ty) + r"\s*;", re.S)
    for body in txt.values():
        if pat.search(body):
            return True
    return False


def iface_ports_of(txt, top):
    """{port: (iface_type, modport)} declared by module `top`."""
    hdr = module_header(txt, top)
    if hdr is None:
        return {}
    found = {}
    # Split on the commas that SEPARATE PORTS, not on newlines: a module may
    # declare every interface port on ONE line --
    #     module FPDivSqrtUnit(FPDivSqrtUnitIF.FPDivSqrtUnit port,
    #                          RecoveryManagerIF.FPDivSqrtUnit recovery);
    # written without the line break (RSD FPDivSqrtUnit) -- and IFACE_PORT is
    # anchored at both ends, so a line holding two declarations matched
    # NEITHER and the module was reported as declaring no interface ports at
    # all.  read_slang then refused it ("top-level module has unconnected
    # interface port") and the row had no reference and no co-sim run.
    # Commas inside a range or a parameter expression do not separate ports,
    # so only depth-0 commas count.
    hdr = re.sub(r"//.*", "", hdr)
    parts, depth, cur = [], 0, []
    for c in hdr:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            parts.append("".join(cur)); cur = []
            continue
        cur.append(c)
    parts.append("".join(cur))
    # A port written WITHOUT a modport -- `tnoc_types types` -- is still an
    # interface port, but IFACE_PORT requires the `.modport`, so it was missed
    # and the wrapper left it dangling ("interface port 'types' not connected").
    # Only a type that is actually a declared `interface` here qualifies, so an
    # ordinary typed port (`my_struct_t cfg`) is never mistaken for one.
    known = declared_ifaces(txt)
    for part in parts:
        p_ = part.strip()
        m = IFACE_PORT.match(p_)
        if m and not re.match(r"^(input|output|inout|logic|wire|reg|bit|parameter|localparam|import)$", m.group(1)):
            found[m.group(3)] = (m.group(1), m.group(2), (m.group(4) or "").strip())
            continue
        mb = re.match(r"^([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*((?:\[[^\]]*\]\s*)*)$", p_)
        if mb and mb.group(1) in known:
            found[mb.group(2)] = (mb.group(1), "", (mb.group(3) or "").strip())
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


def emit_from_decl(txt, rtl_top, ifaces, out, iface_params, dut_params,
                   value_rules=()):
    """Wrapper built from the INTERFACE DECLARATION rather than the netlist."""
    decls, insts, conns, dut, plines = [], [], [], [], []
    seen_param = set()
    locals_, imports = [], []
    macro_typedefs, macro_includes, param_includes = [], [], []
    param_vals = {}
    # The DUT's own (non-interface) ports come first: an interface with its own
    # `(input logic clk, input logic rst_n)` has to be tied to the DUT's clock
    # and reset, and those are among these.
    plain = []
    exposed_iface_ports = set()
    mhdr = module_header(txt, rtl_top)
    for line in (mhdr or "").splitlines():
        # `.rstrip(",")` alone leaves the SPACES that PULP puts before the
        # comma (`input logic     clk_i  ,`), the name then does not end the
        # line and the port is silently dropped -- axi_cut_intf's wrapper came
        # out with no clk_i and no rst_ni at all, so the co-sim clocked
        # nothing ("0 cycles with an output change") and the miter compared two
        # unclocked netlists.
        line = re.sub(r"//.*", "", line).strip().rstrip(",").strip()
        line = resolve_iface_bits(line, ifaces, txt)
        mm = re.match(r"^(input|output|inout)\s+(?:logic|wire|reg|bit)?\s*(\[[^\]]*\]\s*)?(\w+)$", line)
        if mm:
            plain.append((mm.group(1), mm.group(2) or "", mm.group(3)))
    # The DUT's own value parameters, for sizing an interface ARRAY port.
    dut_value_params = {}
    for dn, dflt in module_value_params(txt, rtl_top):
        v = dut_params.get(dn) or bound_value(value_rules, dn, dflt) or dflt
        if v:
            dut_value_params[dn] = v
    for base, (iface, modport, adim) in sorted(ifaces.items()):
        hdr, body = iface_body(txt, iface)
        src_of_iface = getattr(iface_body, "src", "")
        if hdr is None:
            sys.exit(f"# gen_iface_wrapper: no declaration for interface {iface}")
        # the interface's own parameters become the WRAPPER's parameters, so the
        # member declarations below can be copied verbatim
        # An interface may declare its parameters with an `include: VeeR's
        # css_mcu0_el2_mem_if is `#( `include "css_mcu0_el2_param.vh" )`, one
        # 2291-bit struct parameter `pt` that every member width is written
        # over.  That include belongs in the WRAPPER's parameter list, where the
        # interface itself puts it -- emitted at file scope the parameter lands
        # in the compilation unit and the port list cannot see it ("use of
        # undeclared identifier 'pt'", 7 caliptra-ss css_mcu0 rows).
        for inc in re.findall(r"`include\s+\"[^\"]+\"", hdr or ""):
            if inc not in param_includes:
                param_includes.append(inc)
        my_param = []
        # The declared TYPE, where it is a user-defined one.  Re-declaring every
        # parameter `int unsigned` breaks a parameter of a STRUCT type, which is
        # how tnoc configures everything:
        #     parameter tnoc_packet_config PACKET_CONFIG = TNOC_DEFAULT_PACKET_CONFIG,
        #     parameter int                CHANNELS      = PACKET_CONFIG.virtual_channels
        # As `int unsigned PACKET_CONFIG`, the very next parameter's default is
        # "invalid member access for type 'int unsigned'" (read_slang).  Only a
        # non-integral, non-`type` type is carried over, so every existing
        # width parameter keeps the exact declaration it had before.
        ptype = {}
        for pm in IFPARAM_T.finditer(hdr):
            toks = pm.group(1).split()
            if toks and not all(t in _INTEGRAL for t in toks):
                ptype[pm.group(2)] = " ".join(toks)
        for pm in IFPARAM.finditer(hdr):
            nm, dflt = pm.group(1), pm.group(2).strip()
            my_param.append(nm)
            if nm in seen_param:
                continue
            seen_param.add(nm)
            val = iface_params.get(nm) or bound_value(value_rules, nm, dflt) or dflt
            param_vals[nm] = val
            plines.append(f"  parameter {ptype.get(nm, 'int unsigned')} {nm} = {val}")
        # Localparams and typedefs must reach the PORT LIST, which the ports
        # below are declared with -- so they go into the ANSI parameter list as
        # `localparam` / `localparam type` entries, not into the body (a
        # typedef declared after the port list is "used before its
        # declaration").
        for lp in LOCALP.findall(body):
            e = lp.rstrip(";").strip()
            if e not in locals_:
                locals_.append(e)
        # A member type may be built by a MACRO rather than a `typedef`:
        # PULP's AXI_BUS_ASYNC_GRAY declares its channels with
        # `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)`.  Those have
        # to be emitted at FILE scope (a macro invocation cannot be a
        # `localparam type` entry in a parameter list), together with the
        # include that defines them -- otherwise the wrapper names a type
        # nothing declares and Verilator stops at "Can't find
        # typedef/interface: 'aw_chan_t'", which the sweep could only report as
        # "skip (sim build)" with no measurement at all.
        for mline in re.findall(r"^[ \t]*(`[A-Z][A-Z0-9_]*\s*\([^\n]*\))[ \t]*$",
                                body, re.M):
            if mline not in macro_typedefs:
                macro_typedefs.append(mline)
        for inc in re.findall(r"^[ \t]*(`include\s+\"[^\"]+\")", src_of_iface, re.M):
            if inc not in macro_includes and inc not in param_includes:
                macro_includes.append(inc)
        for td in iface_typedefs(body):
            # `typedef logic [AXI_ID_WIDTH-1:0] id_t;` -> `localparam type id_t = logic [AXI_ID_WIDTH-1:0]`
            mm = re.match(r"typedef\s+(.*?)\s+(\w+)\s*;\s*$", td.strip(), re.S)
            if not mm:
                continue
            e = f"localparam type {mm.group(2)} = {mm.group(1).strip()}"
            if e not in locals_:
                locals_.append(e)
        # A member may be declared over a type the interface imports --
        # caliptra's axi_if declares `logic [$bits(axi_burst_e)-1:0] arburst`
        # under `import axi_pkg::*;` -- and the declaration is copied verbatim
        # into the wrapper's port list, so the wrapper needs the same import.
        # It goes between the module name and the parameter list, the only
        # place an import reaches an ANSI port list from.
        # A MODPORT may import tasks/functions -- every tnoc interface does:
        #     modport receiver (input valid, ..., import get_ack,
        #                       import get_channel_ack, ...);
        # Those are not package imports, and `[^;]+` runs from the first
        # `import` all the way to the modport's closing `;`, so the wrapper came
        # out with `import get_ack;` followed by `import import
        # get_channel_ack;`.  A package import always names a scope with `::`
        # (`import axi_pkg::*`), a modport function import never does, so that
        # is the discriminator.
        # Scan the HEADER as well as the body: an interface may import its
        # package BEFORE the parameter list -- `interface tnoc_flit_if import
        # tnoc_pkg::*; #(parameter tnoc_packet_config PACKET_CONFIG =
        # TNOC_DEFAULT_PACKET_CONFIG, ...)` -- and the parameter defaults
        # copied into the wrapper then name constants only that package
        # declares ("use of undeclared identifier
        # 'TNOC_DEFAULT_PACKET_CONFIG'" from read_slang).
        for im in re.findall(r"^\s*import\s+([^;]+);", (hdr or "") + "\n" + body, re.M):
            for one in im.split(","):
                one = one.strip()
                if one and "::" in one and one not in imports:
                    imports.append(one)
        mports = iface_modports(body)
        dirs = mports.get(modport, {})
        # ONLY this interface's own parameters: a module with two DIFFERENT
        # interface ports (caliptra-ss axi_mem has three) would otherwise be
        # handed the union, and read_slang rejects the instance outright
        # ("parameter 'DW' does not exist in ...").
        # Pass the VALUES, not the names: the parameters live at file scope now,
        # and Surelog records a parameter actual that is a compilation-unit
        # localparam with NO right-hand side -- the interface instance then has
        # P unbound, its members go degenerate, and the row diverges from the
        # RTL by hundreds of cycles while read_slang (which resolves it) stays
        # clean.  That is the same trap the cvw configuration wrapper hit.
        pv = ", ".join(f".{n}({param_vals.get(n, n)})" for n in my_param)
        pfx = f"#({pv}) " if pv else ""
        iports, unbound = _iface_port_conns(hdr, plain)
        # Interface inputs no DUT port binds (RSD's all-interface modules):
        # one wrapper input each, shared by name across the interfaces
        # (`clk` of ControllerIF and of LoadStoreUnitIF are the same clock).
        for urng, uname in unbound:
            if uname in exposed_iface_ports:
                continue
            exposed_iface_ports.add(uname)
            decls.insert(len(exposed_iface_ports) - 1, f"  input logic {urng + ' ' if urng else ''}{uname}")
        # An interface ARRAY port (`AXI_BUS.Master mst [NO_MST_PORTS-1:0]`,
        # PULP's axi_demux_intf / axi_mux_intf / axi_xbar_intf) needs an ARRAY
        # of interface instances and one set of flat ports per element.  With a
        # single instance the port cannot bind at all -- "Interface port 'mst'
        # is not connected to interface/modport pin expression" -- and the row
        # was reported as a skipped co-simulation with nothing measured.
        count = 1
        if adim:
            count = _dim_count(adim, dut_value_params)
            if count is None:
                sys.exit(f"# gen_iface_wrapper: cannot size the interface array "
                         f"port {base}{adim} of {rtl_top}")
        # An array port of ONE element is still an array port: rggen's
        # adapters declare `rggen_register_if.host register_if[REGISTERS]`
        # with REGISTERS defaulting to 1, and a scalar instance for it drew
        # "dimensions of connection for port 'register_if' do not match its
        # declaration" from read_slang -- five rows with no reference at all.
        # Key the array shape on the DIMENSION being there, not on count > 1.
        if adim:
            insts.append(f"  {iface} {pfx}{base}_i [{count-1}:0] ({iports});")
            dut.append(f"    .{base}({base}_i)")
        else:
            insts.append(f"  {iface} {pfx}{base}_i ({iports});")
            dut.append(f"    .{base}({base}_i.{modport})")
        for e in range(count):
            sel = f"[{e}]" if adim else ""
            tag = f"_{e}" if adim else ""
            for ty, rng, mem, udims in iface_members_full(body):
                d = dirs.get(mem)
                if not d:                  # not in this modport
                    continue
                flat = f"{base}{tag}__{mem}"
                if udims:
                    # An UNPACKED-array member (`MemoryPortMultiplexerIn
                    # mshrMemMuxIn[MSHR_NUM]` in RSD's DCacheIF) used to be
                    # dropped by the member regex, so the DUT's main inputs
                    # were never driven: every DCache* / Rename* / Decode*
                    # row of RSD was "differs" on an undriven interface
                    # member, with nothing measured.  Flatten it the way
                    # gen_flat_wrapper.py flattens an unpacked PORT: one
                    # vector, row-major, element 0 at the LSBs.
                    ew = f"$bits({ty}{' ' + rng if rng else ''})"
                    dl = _unpacked_dim_exprs(udims)
                    total = "*".join(c for c, _ in dl)
                    decls.append(f"  {d} logic [({total})*({ew})-1:0] {flat}")
                    idx = "0"
                    for k, (c, _) in enumerate(dl):
                        idx = f"(({idx})*{c}+g{k})"
                    elem = "".join(f"[{lo} + g{k}]" for k, (_, lo) in enumerate(dl))
                    heads = "".join(f"  for (genvar g{k} = 0; g{k} < {c}; g{k}++) "
                                    f"begin : g_flat_{flat}_{k}\n"
                                    for k, (c, _) in enumerate(dl))
                    tails = "  end\n" * len(dl)
                    if d == "input":
                        # The flat port is plain `logic [...]`, the member may
                        # be an ENUM -- and there is no implicit conversion to
                        # an enum, so read_slang rejects the wrapper
                        # ("no implicit conversion from 'logic[2:0]' to
                        # 'Rounding_Mode'; explicit conversion exists") while
                        # Verilator accepts it, leaving the row with a co-sim
                        # but NO reference (RSD FPDivSqrtUnit's
                        # `Rounding_Mode rm [FP_DIVSQRT_ISSUE_WIDTH]`).  Cast
                        # to the member's declared type whenever that is a
                        # NAMED type: `logic`/`bit`/`reg`/`wire` must not be
                        # cast (`logic'(x)` would narrow it to one bit), and a
                        # typedef'd packed struct or enum casts cleanly.
                        slice_ = f"{flat}[({idx})*({ew}) +: ({ew})]"
                        if not rng and _is_enum_type(txt, ty):
                            slice_ = f"{_enum_scope(txt, ty)}{ty}'({slice_})"
                        body_ = (f"    assign {base}_i{sel}.{mem}{elem} = "
                                 f"{slice_};\n")
                    else:
                        body_ = (f"    assign {flat}[({idx})*({ew}) +: ({ew})] = "
                                 f"{base}_i{sel}.{mem}{elem};\n")
                    conns.append((heads + body_ + tails).rstrip("\n"))
                    continue
                decls.append(f"  {d} {ty} {rng + ' ' if rng else ''}{flat}")
                if d == "input":
                    conns.append(f"  assign {base}_i{sel}.{mem} = {flat};")
                else:
                    conns.append(f"  assign {flat} = {base}_i{sel}.{mem};")
    # the DUT's own width parameters, matched by ROLE: this codebase spells them
    # ADDR_WIDTH / AXI_ADDR_WIDTH / ... interchangeably
    dparams = []
    dbind = dict(dut_params)
    for dn, dflt in module_value_params(txt, rtl_top):
        if dn not in dbind:
            v = bound_value(value_rules, dn, dflt)
            if v is not None:
                dbind[dn] = v
    for dn, dv in sorted(dbind.items()):
        dparams.append(f".{dn}({dv})")
    # A copied plain-port declaration may be sized by one of the DUT's OWN
    # parameters, which nothing has declared in the wrapper so far.
    known = set(seen_param)
    for l in locals_:
        mm = re.match(r"^localparam\s+(?:type\s+)?(?:\w+\s+)*?(\w+)\s*=", l.strip())
        if mm:
            known.add(mm.group(1))
    used = set()
    for _, rng, _nm in plain:
        used |= _ids(rng)
    for l in dut_param_locals(txt, rtl_top, used, known, dbind):
        if l not in locals_:
            locals_.append(l)
    # plain (non-interface) ports of the DUT
    for d, rng, nm in plain:
        decls.append(f"  {d} logic {rng}{nm}")
        dut.append(f"    .{nm}({nm})")
    with open(out, "w") as fh:
        fh.write(f"// GENERATED by test/gen_iface_wrapper.py (--from-decl).\n"
                 f"// Flat-port wrapper around {rtl_top}.  Its interface ports are\n"
                 f"// DEGENERATE standalone (the interface's width parameters default to 0),\n"
                 f"// so the ports below are the interface's own member declarations copied\n"
                 f"// verbatim.\n")
        if macro_typedefs:
            fh.write(
                 f"//\n"
                 f"// This interface declares its member types with MACROS\n"
                 f"// (`AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, ...)`, PULP's\n"
                 f"// AXI_BUS_ASYNC_GRAY), and a macro invocation cannot be a `localparam\n"
                 f"// type` entry in a parameter list -- so for THIS shape the whole chain\n"
                 f"// (parameters, localparams, typedefs, macros) is emitted at file scope,\n"
                 f"// where the macros can see what they need.  The parameter-list form\n"
                 f"// below is kept for every other interface: file-scope parameters would\n"
                 f"// otherwise reach the interface instance as a compilation-unit\n"
                 f"// localparam, which Surelog records with no right-hand side (the same\n"
                 f"// trap the cvw configuration wrapper hit) -- axi_cut_intf went from\n"
                 f"// equivalent to 280 diverging cycles that way.\n")
        for inc in macro_includes:
            fh.write(inc + "\n")
        for imp in imports:
            fh.write(f"import {imp};\n")
        for pl in (plines if macro_typedefs else []):
            fh.write(re.sub(r"^parameter\b", "localparam", pl.strip()) + ";\n")
        for l in (locals_ if macro_typedefs else []):
            e = l.strip()
            m_lt = re.match(r"^localparam\s+type\s+(\w+)\s*=\s*(.+)$", e)
            # `localparam type id_t = logic [W-1:0]` is a parameter-list form;
            # at file scope the same thing is `typedef logic [W-1:0] id_t;`
            # (name LAST -- emitting it in parameter order gave
            # `typedef id_t logic [...]`, which is a syntax error).
            fh.write((f"typedef {m_lt.group(2).rstrip(';')} {m_lt.group(1)};\n")
                     if m_lt else (e.rstrip(";") + ";\n"))
        for td in macro_typedefs:
            fh.write(td + "\n")
        fh.write("\n")
        if macro_typedefs:
            fh.write(f"module {rtl_top}_flat"
                     + (" import " + ", ".join(imports) + ";" if imports else "")
                     + " (\n")
        else:
            # An EMPTY parameter list is a syntax error (`module m #( ) (...)`,
            # "missing ';' at 'module'"), and a module whose interface declares
            # no parameters of its own gets one -- that is the whole of why
            # caliptra-ss's css_mcu0_el2_veer_wrapper reported `elab-fail`.
            plist = plines + ["  " + i for i in param_includes] \
                           + ["  " + l for l in locals_]
            fh.write(f"module {rtl_top}_flat"
                     + (" import " + ", ".join(imports) + ";" if imports else "")
                     + (" #(\n" if plist else " (\n"))
            if plist:
                fh.write(",\n".join(plist) + "\n) (\n")
        fh.write(",\n".join(decls) + "\n);\n\n")
        fh.write("\n".join(insts) + "\n\n")
        pv = (" #(" + ", ".join(dparams) + ")") if dparams else ""
        fh.write(f"  {rtl_top}{pv} dut (\n" + ",\n".join(dut) + "\n  );\n\n")
        fh.write("\n".join(conns) + "\nendmodule\n")
    print(f"# wrote {out}: {len(decls)} ports, {len(insts)} interface instance(s) "
          f"from the interface declaration")


def type_from_iface_port(txt, ifaces):
    """True when an interface used here declares members over a type taken from
    an interface PORT -- `interface tnoc_flit_if (tnoc_types types); typedef
    types.tnoc_flit tnoc_flit;`.  Such a declaration cannot be restated in a
    wrapper's port list, because a port list cannot reference an instance."""
    for ent in ifaces.values():
        iface = ent[0]
        subs = [n for _, n in iface_iface_ports(txt, iface)]
        if not subs:
            continue
        _, body = iface_body(txt, iface)
        for n in subs:
            if re.search(r"\btypedef\s+" + re.escape(n) + r"\.", body or ""):
                return True
    return False


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
    value_rules = []
    defines = None
    if "--manifest" in argv:
        i = argv.index("--manifest")
        value_rules = manifest_values(argv[i + 1])
        defines = manifest_defines(argv[i + 1])
        del argv[i:i + 2]
    extra_defs = []
    while "--define" in argv:
        i = argv.index("--define")
        extra_defs.append(argv[i + 1])
        del argv[i:i + 2]
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
    # Scan only the arms the sweep's define set actually takes -- see
    # strip_inactive().  With no manifest and no --define we would be guessing,
    # so leave the text alone.
    if defines is not None or extra_defs:
        txt = strip_inactive(txt, set(defines or []) | set(extra_defs))
    if from_decl:
        ifaces = iface_ports_of(txt, rtl_top)
        if not ifaces:
            sys.exit(f"# gen_iface_wrapper: {rtl_top} declares no interface ports")
        # --from-decl copies the interface's MEMBER DECLARATIONS into the
        # wrapper's port list verbatim, which only works when those
        # declarations can be read standalone.  tnoc's cannot: every member of
        # tnoc_flit_if is declared over `typedef types.tnoc_flit tnoc_flit`, a
        # type taken from ANOTHER interface handed in as a port, and a port
        # list cannot reference an instance.  The wrapper came out with
        # `tnoc_flit` unresolved -- receiver_if__flit 32 bits where the
        # elaborated netlist says 582 (2 x 291) -- and read_slang rejected it
        # with "use of undeclared identifier 'types'".
        #
        # The NETLIST path has neither problem: read_uhdm has already
        # elaborated the module, so the flattened `\receiver_if.flit` port
        # carries the real width, and the wrapper instantiates the interfaces
        # (and the `types` they take as a port) instead of restating their
        # members.  Use it for exactly that shape and leave every other family
        # on --from-decl, where it is proven over 69 wrappers.
        if type_from_iface_port(txt, ifaces):
            have = []
            if il and Path(il).exists():
                have = [n for _, _, n in netlist_ports(il, top) if "." in n]
            if have:
                print("# gen_iface_wrapper: member types come from an interface "
                      "port -- using the elaborated netlist instead of the "
                      "declaration")
                from_decl = False
            else:
                # The caller generates the wrapper BEFORE the first read, so on
                # a fresh work directory there is no netlist yet.  Say so, so
                # the flow can elaborate the bare module once and retry; fall
                # through to --from-decl meanwhile, which is what it did
                # before and keeps this a no-op for a caller that ignores the
                # marker.
                print(f"# gen_iface_wrapper: NEEDS-NETLIST {rtl_top}")
        if from_decl:
            emit_from_decl(txt, rtl_top, ifaces, out, iface_params, dut_params,
                           value_rules)
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
    sub_insts = []
    for base in dotted:
        # iface_ports_of returns (iface, modport, unpacked_dims); the third
        # element was added for interface ARRAY ports and this caller was never
        # updated, so the netlist path died with "too many values to unpack"
        # the first time anything reached it (tnoc_dummy_node).
        iface, modport = ifaces[base][0], ifaces[base][1]
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
        # An interface that itself takes an interface port (tnoc_flit_if's
        # `tnoc_types types`) needs that one instantiated too, and shared: the
        # member typedefs of every flit interface come from the SAME types
        # instance, so a per-port copy would be a different type.
        for sub_t, sub_n in iface_iface_ports(txt, iface):
            inst_n = f"{sub_t}_shared_i"
            decl = f"  {sub_t} {inst_n} ();"
            if decl not in sub_insts:
                sub_insts.append(decl)
            conn.append(f".{sub_n}({inst_n})")
        args = ", ".join(conn)
        insts.append(f"  {iface} {pfx}{base}_i ({args});")
        dut.append(f"    .{base}({base}_i.{modport})")

    # The DUT's OWN interface ports that carry no signals: tnoc_types exports
    # only typedefs, so it contributes no flattened `types.x` port and never
    # appears in `dotted` -- the wrapper left it dangling and read_slang
    # refused the instance ("interface port 'types' not connected",
    # tnoc_flit_if_fifo / tnoc_if_transposer / tnoc_vc_splitter).  Connect it
    # to the SAME shared instance the member interfaces were given, which is
    # what the DUT's own typedefs are resolved against.
    for base in sorted(ifaces):
        if base in dotted:
            continue
        sub_t = ifaces[base][0]
        if sub_t not in declared_ifaces(txt):
            continue
        inst_n = f"{sub_t}_shared_i"
        decl = f"  {sub_t} {inst_n} ();"
        if decl not in sub_insts:
            sub_insts.append(decl)
        mp = ifaces[base][1]
        dut.append(f"    .{base}({inst_n}{'.' + mp if mp else ''})")

    # The member's DECLARED type per interface port: the netlist knows only
    # the width, and an ENUM-typed member needs an explicit cast from the flat
    # `logic` port (no implicit conversion TO an enum -- see emit_from_decl's
    # unpacked branch; here the plain-member case: tnoc_axi_if's
    # `tnoc_axi_burst_size awsize`, which left tnoc_axi_if_connector with a
    # co-sim and NO read_slang reference).
    mem_ty = {}
    for base in dotted:
        _ih, ibody = iface_body(txt, ifaces[base][0])
        if ibody:
            mem_ty[base] = {m: (ty, rng) for ty, rng, m, ud in iface_members_full(ibody)
                            if not ud}
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
            ty, trng = mem_ty.get(base, {}).get(field, (None, None))
            rhs = flat
            if ty and not trng and _is_enum_type(txt, ty):
                rhs = f"{_enum_scope(txt, ty)}{ty}'({flat})"
            conns.append(f"  assign {base}_i.{field} = {rhs};")
        else:
            conns.append(f"  assign {flat} = {base}_i.{field};")

    with open(out, "w") as fh:
        fh.write(f"// GENERATED by test/gen_iface_wrapper.py -- do not edit.\n"
                 f"// Flat-port wrapper around {rtl_top}: each interface port becomes a set of\n"
                 f"// ordinary ports, so a co-sim testbench can drive it (Verilator cannot\n"
                 f"// take an escaped port name containing a dot).\n"
                 f"module {rtl_top}_flat (\n")
        fh.write(",\n".join(decls) + "\n);\n\n")
        # the shared sub-interface instances must precede the interfaces
        # that take them as a port
        fh.write("\n".join(sub_insts + insts) + "\n\n")
        fh.write(f"  {rtl_top} dut (\n" + ",\n".join(dut) + "\n  );\n\n")
        fh.write("\n".join(conns) + "\nendmodule\n")
    print(f"# wrote {out}: {len(decls)} ports, {len(insts)} interface instance(s) "
          f"for {', '.join(dotted)}")


main()
