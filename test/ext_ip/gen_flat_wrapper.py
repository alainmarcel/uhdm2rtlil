#!/usr/bin/env python3
"""Flat shim for a module with UNPACKED-ARRAY ports.

    output tlul_pkg::tl_h2d_t tl_d_o [N]      ->  output logic [$bits(tlul_pkg::tl_h2d_t)*(N)-1:0] tl_d_o_flat

Every RTLIL frontend flattens an unpacked-array port to one vector, but they do
not agree on the element order for an ASCENDING dimension (`x [N]` is `[0:N-1]`):
read_slang puts element 0 at the MSBs, read_uhdm at the LSBs, and both agree for
`[N-1:0]`.  Mitered as-is the two netlists "differ" on a pure convention, and a
Verilator testbench cannot connect a vector to an array port at all ("skip (sim
build)").  The pavona harness papers over the same thing with hand-written
shims (test/pavona_tlul_equiv/wrappers/flat_tlul_socket_1n.sv); this generates
one: the wrapper declares the arrays, connects element i to bits [i*W +: W]
(element 0 at the LSBs, whatever the declared direction) with explicit index
arithmetic both frontends read identically, and instantiates the module with
its DEFAULT parameters under `.*`.  The parameter header (an `include`d struct
parameter in VeeR's case) and the package imports are copied verbatim so the
port types and dimension expressions resolve exactly as in the module.

usage: gen_flat_wrapper.py --module M --out M_flat.sv <srcs...>
exit 3 = the module has no unpacked-array port (nothing to do).
"""
import re, argparse, re, sys
from pathlib import Path

PORT_RE = re.compile(
    # The type may hold one level of balanced parentheses: `logic
    # [$clog2(ENTRY_NUM)-1:0] wa[WRITE_NUM]` (RSD's RAM models) was skipped
    # by a paren-free type class, so `wa` / `ra` stayed unpacked ports.
    r"(?P<dir>\b(?:input|output|inout)\b)\s+(?P<type>(?:[^,;()]|\([^()]*\))*?)\s+(?P<name>[A-Za-z_]\w*)"
    r"\s*(?P<dims>(?:\[[^\]]*\]\s*)+)(?=\s*(?:,|\)|$|//|/\*))", re.M)
NETKW = {"wire", "var", "logic", "reg", "tri"}


def balanced(t, i):
    d = 0
    for j in range(i, len(t)):
        if t[j] == "(": d += 1
        elif t[j] == ")":
            d -= 1
            if d == 0: return j + 1
    raise ValueError("unbalanced")


def module_span(txt, name):
    m = re.search(r"^\s*module\s+" + re.escape(name) + r"\b", txt, re.M)
    if not m:
        sys.exit(f"# gen_flat_wrapper: module {name} not found")
    i = m.end()
    j = txt.find("#", i); k = txt.find("(", i)
    pre = ""
    if j != -1 and j < k:
        pre = txt[i:j]                     # `import pkg::*;` between name and #(
        s = txt.index("(", j); e = balanced(txt, s)
        params = txt[j:e]                  # "#( ... )"
        i = e
    else:
        pre = txt[i:k]; params = ""
    s = txt.index("(", i); e = balanced(txt, s)
    ports = txt[s + 1:e - 1]
    body_end = txt.find(";", e)
    return pre, params, ports, txt[m.start():body_end + 1]


def split_top_level(t, sep=","):
    out, depth, cur = [], 0, []
    for c in t:
        if c in "([{": depth += 1
        elif c in ")]}": depth -= 1
        if c == sep and depth == 0:
            out.append("".join(cur)); cur = []
        else:
            cur.append(c)
    out.append("".join(cur))
    return out


def normalize_port_groups(ports):
    """Rewrite a grouped ANSI port list so every declaration carries its own
    direction and type (see the caller).  Entries holding a preprocessor
    directive are left untouched."""
    ent_re = re.compile(r"^(\s*)(?:(input|output|inout)\b\s*)?(.*?)\s*([A-Za-z_]\w*)\s*((?:\[[^\]]*\]\s*)*)$", re.S)
    cur_dir, cur_type, out = None, "", []
    for e in split_top_level(ports):
        if "`" in e or not e.strip():
            out.append(e); continue
        m = ent_re.match(e)
        if not m:
            out.append(e); continue
        lead, d, typ, name, dims = m.groups()
        typ = typ.strip()
        if d:
            cur_dir, cur_type = d, typ
        elif typ:
            cur_type = typ            # its own type, the group's direction
        else:
            typ = cur_type            # a bare name: the group's type too
        if cur_dir is None:
            out.append(e); continue
        parts = [cur_dir] + ([typ] if typ else []) + [name]
        out.append(lead + " ".join(parts) + (" " + dims.strip() if dims.strip() else ""))
    return ",".join(out)


def dim_count(d):
    """SV size of one unpacked dimension text: `[N]` -> N, `[A:B]` -> |A-B|+1."""
    inner = d.strip()[1:-1].strip()
    # The range separator is a SINGLE colon: a package-qualified bound
    # (`bindpkg::NUM_CHANNELS-1:0`, a bound wrapper's dimension) must not be
    # split at its `::`.
    inner_sep = re.sub(r"::", "\x00", inner)
    if ":" not in inner_sep:
        return f"({inner})", "0"
    a, b = (x.replace("\x00", "::") for x in inner_sep.split(":", 1))
    a, b = a.strip(), b.strip()
    return (f"((({a})>({b}))?(({a})-({b})+1):(({b})-({a})+1))",
            f"((({a})<({b}))?({a}):({b}))")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("srcs", nargs="+")
    a = ap.parse_args()
    txt = None
    for s in a.srcs:
        t = Path(s).read_text(errors="replace")
        if re.search(r"^\s*module\s+" + re.escape(a.module) + r"\b", t, re.M):
            txt = t; break
    if txt is None:
        sys.exit(f"# gen_flat_wrapper: no source declares module {a.module}")
    pre, params, ports, _ = module_span(txt, a.module)
    # Line comments inside the PORT LIST are not decoration to the rewrites
    # below: `// 57 = FP64_FRAC_W + 4` carries an `=` at depth 0, and the
    # initialiser stripper then deleted everything from it to the next comma --
    # taking the port declared on the following line with it.  xiangshan's
    # fpdiv_r64_block lost `divisor_i` that way, and `u_dut (.*)` could not
    # bind ("could not find connection for implicit named port 'divisor_i'").
    ports = re.sub(r"/\*.*?\*/", "", ports, flags=re.S)
    ports = re.sub(r"//[^\n]*", "", ports)
    # A GROUPED ANSI list writes the direction once for several declarations
    # (RSD DecodedBranchResolver: `output logic insnValidOut[DW], logic
    # insnFlushed[DW], ..., BranchPred brPredOut[DW], PC_Path recoveredPC`).
    # PORT_RE anchors on a direction keyword, so only the first declaration
    # of each group was flattened and the rest stayed unpacked ports that the
    # two frontends order differently (the miter compared brPredOut's two
    # elements swapped).  Give every declaration its group's direction, and a
    # bare name (`logic clk, rst`) the group's type as well.
    ports = normalize_port_groups(ports)

    arrays = []
    def rewrite(m):
        dirn, typ, name, dims = m.group("dir"), " ".join(m.group("type").split()), m.group("name"), m.group("dims")
        dl = re.findall(r"\[[^\]]*\]", dims)
        # A multi-dimensional unpacked port (`x [DW][SRC]`, RSD SourceCAM's
        # dispatchedSrcRegNum) is flattened too, row-major with the FIRST
        # dimension slowest: element [i][j] at ((i*C)+j)*ew.  Left as is, the
        # two frontends ordered its elements differently and the miter fed
        # the DUT different operands -- SourceCAM, ReadyBitTable and
        # DecodedBranchResolver all `differs` on nothing.
        # an `ifdef line glued in front of the direction keyword stays put: the
        # regex anchors on the direction keyword, so `typ` is the type only.
        toks = [t for t in typ.split() if t not in NETKW]
        elem = " ".join(toks) if toks else "logic"
        if re.match(r"^\[", elem):         # `logic [31:0]` -> `logic [31:0]`
            elem = "logic " + elem
        cls = [dim_count(d) for d in dl]          # (count, low) per dimension
        cnt = "*".join(f"({c})" for c, _ in cls) if len(cls) > 1 else cls[0][0]
        lo = cls[0][1]
        # Element width: `$bits(T)` for a named type; for a plain vector
        # (`logic [31:0]`, `logic`) the product of its packed ranges instead --
        # read_uhdm evaluates `$bits(logic [31:0])` as 1 (a reader bug tracked
        # separately), which would size the flat port 32x too narrow.
        pk = re.findall(r"\[[^\]]*\]", elem)
        base = re.sub(r"\[[^\]]*\]", "", elem).strip()
        if base in ("logic", "reg", "bit", "wire") or not base:
            ew = "*".join(dim_count(d)[0] for d in pk) if pk else "1"
        else:
            ew = f"$bits({elem})"
        arrays.append((dirn, elem, name, "".join(dl), cnt, lo, ew, cls))
        return f"{dirn} logic [({ew})*{cnt}-1:0] {name}_flat"
    new_ports = PORT_RE.sub(rewrite, ports)
    # A port initialiser (`output logic [4:0] counter = 5'd0`, hdmi
    # packet_assembler) belongs to the module, not to the shim: the shim's
    # port is driven by `u_dut (.*)`, and read_uhdm lowered the copied
    # initialiser into a constant driver on that same net -- flatten then
    # died with "Cell port u_dut.counter is driving constant bits".  Drop
    # `= <expr>` up to the next top-level `,` / `)`.
    def strip_init(t):
        out, depth, i, n = [], 0, 0, len(t)
        while i < n:
            c = t[i]
            if c in "([{": depth += 1
            elif c in ")]}": depth -= 1
            if c == "=" and depth == 0 and t[i-1:i] not in "=!<>" and t[i+1:i+2] != "=":
                j = i + 1
                while j < n and (t[j] != "," or depth) and not (t[j] == ")" and depth == 0):
                    if t[j] in "([{": depth += 1
                    elif t[j] in ")]}": depth -= 1
                    j += 1
                i = j
                continue
            out.append(c); i += 1
        return "".join(out)
    new_ports = strip_init(new_ports)
    if not arrays:
        sys.exit(3)
    L = [f"// GENERATED by test/ext_ip/gen_flat_wrapper.py -- flat shim for {a.module}:",
         f"// its unpacked-array ports become one vector each, element 0 at the LSBs,",
         f"// so read_uhdm, read_slang and the Verilator co-sim see the same port list.",
         f"module {a.module}_flat{pre.rstrip()}{(' ' + params) if params else ''} ({new_ports});"]
    for dirn, elem, name, dim, cnt, lo, ew, cls in arrays:
        L.append(f"  {elem} {name} {dim};")
    for dirn, elem, name, dim, cnt, lo, ew, cls in arrays:
        # One genvar per dimension; the flat index is row-major over them.
        gv = [f"g{k}" for k in range(len(cls))]
        for k, (c, l) in enumerate(cls):
            ind = "  " * (k + 1)
            blk = f"g_flat_{name}" if k == 0 else f"g_flat_{name}_{k}"
            L.append(f"{ind}for (genvar {gv[k]} = 0; {gv[k]} < {c}; {gv[k]}++) begin : {blk}")
        sel = "".join(f"[{l} + {gv[k]}]" for k, (c, l) in enumerate(cls))
        idx = gv[0]
        for k in range(1, len(cls)):
            idx = f"({idx})*({cls[k][0]}) + {gv[k]}"
        ind = "  " * (len(cls) + 1)
        if dirn == "input":
            L.append(f"{ind}assign {name}{sel} = {name}_flat[({idx})*({ew}) +: ({ew})];")
        else:
            L.append(f"{ind}assign {name}_flat[({idx})*({ew}) +: ({ew})] = {name}{sel};")
        for k in range(len(cls) - 1, -1, -1):
            L.append("  " * (k + 1) + "end")
    L.append(f"  {a.module} u_dut (.*);")
    L.append("endmodule")
    Path(a.out).write_text("\n".join(L) + "\n")
    print(f"# gen_flat_wrapper: {a.module}_flat with {len(arrays)} flattened array port(s): "
          + ", ".join(n for _, _, n, _, _, _, _, _ in arrays))


if __name__ == "__main__":
    main()
