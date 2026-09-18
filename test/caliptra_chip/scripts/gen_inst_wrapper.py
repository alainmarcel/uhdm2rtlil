#!/usr/bin/env python3
"""gen_inst_wrapper.py <inst.il> <il_top> <rtl_module> <out.sv> [--param K=V ...]
                       [--clk NAME] [--rst NAME]

Flat-port wrapper around ONE direct instance's RTL module (the per-instance
sibling of gen_wrapper.py): every SystemVerilog INTERFACE port of the module
(the four axi_if modports, VeeR's el2_mem_if exports, the ABR memory export)
becomes a set of ordinary `<port>_<member>` wrapper ports, so the instance's
read_uhdm / read_slang netlists (whose interface members are the escaped
`\\<port>.<member>` ports, renamed by netlist_cosim.py --iface-flat) can be
co-simulated against the RTL.  Port geometry comes from the instance's split
RTLIL (`work/inst/<name>_uhdm.il`, top `<name>_uhdm`) — the one place the
elaborated interface widths are written down — and the instance's parameter
values are baked into the inner instantiation, so the wrapper itself takes no
parameters.
"""
import argparse, re, sys

# interface port base -> (interface type, modport, AXI param tag or None)
IFACES = {
    "s_axi_w_if":        ("axi_if",     "w_sub",            "S_AXI"),
    "s_axi_r_if":        ("axi_if",     "r_sub",            "S_AXI"),
    "m_axi_w_if":        ("axi_if",     "w_mgr",            "M_AXI"),
    "m_axi_r_if":        ("axi_if",     "r_mgr",            "M_AXI"),
    "el2_mem_export":    ("el2_mem_if", "veer_sram_src",    None),
    "el2_icache_export": ("el2_mem_if", "veer_icache_src",  None),
    "abr_memory_export": ("abr_mem_if", "req",              None),
}
# ports sharing one interface instance (write + read halves of an AXI bus,
# the two VeeR memory exports)
SHARED = {"s_axi_w_if": "s_axi_i", "s_axi_r_if": "s_axi_i",
          "m_axi_w_if": "m_axi_i", "m_axi_r_if": "m_axi_i",
          "el2_mem_export": "el2_mem_i", "el2_icache_export": "el2_mem_i",
          "abr_memory_export": "abr_mem_i"}

WIRE = re.compile(
    r"^\s+wire\s+(?:width\s+(\d+)\s+)?(?:offset\s+(-?\d+)\s+)?"
    r"(input|output|inout)\s+\d+\s+\\(\S+)\s*$")


def ports_of(il_path, top):
    out, inmod = [], False
    with open(il_path, errors="replace") as fh:
        for line in fh:
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("il")
    ap.add_argument("il_top")
    ap.add_argument("rtl_module")
    ap.add_argument("out")
    ap.add_argument("--param", action="append", default=[], help="K=V baked into the instantiation")
    ap.add_argument("--clk", default=None, help="clock port fed to the axi_if instances (default: auto)")
    ap.add_argument("--rst", default=None, help="active-low reset fed to the axi_if instances (default: auto)")
    ap.add_argument("--rtl-src", default=None,
                    help="the RTL file declaring <rtl_module>: only its overridable `parameter`s "
                         "(not localparams / type parameters) are baked into the instantiation")
    a = ap.parse_args()
    if a.rtl_src:
        txt = open(a.rtl_src, errors="replace").read()
        m = re.search(r"\bmodule\s+" + re.escape(a.rtl_module) + r"\b(.*?)\)\s*;", txt, re.S)
        hdr = m.group(1) if m else ""
        hdr = re.sub(r"//[^\n]*", "", hdr)
        keep = set(re.findall(r"\bparameter\s+(?!type\b)(?:[\w:\[\]\s]*?\s)?(\w+)\s*=", hdr))
        kept = [x for x in a.param if x.split("=", 1)[0] in keep]
        dropped = [x.split("=", 1)[0] for x in a.param if x.split("=", 1)[0] not in keep]
        if dropped:
            print(f"# dropping {len(dropped)} non-overridable parameter(s): {dropped[:6]}", file=sys.stderr)
        a.param = kept
    all_ports = ports_of(a.il, a.il_top)
    if not all_ports:
        print(f"# no ports for {a.il_top} in {a.il}", file=sys.stderr)
        sys.exit(1)
    names = [n for _, _, n in all_ports]
    plain = [n for n in names if "." not in n]
    clk = a.clk or next((n for n in plain if n in ("clk", "clk_i", "hclk")), None)
    rst = a.rst or next((n for n in plain if re.match(r"^(cptra_)?rst_?[bnl]$|^rst_ni$|^hreset_n$|^rst_n$", n)), None)
    by_name = {n: w for w, _, n in all_ports}
    axi_params = {}
    for tag, rd in (("S_AXI", "s_axi_r_if"), ("M_AXI", "m_axi_r_if")):
        if any(n.startswith(rd + ".") for n in names):
            for sfx, sig in (("AW", "araddr"), ("DW", "rdata"), ("IW", "arid"), ("UW", "aruser")):
                axi_params[f"{tag}_{sfx}"] = by_name.get(f"{rd}.{sig}", 32)
    decls, insts, conns, inner, seen_inst, used_ifaces = [], [], [], [], set(), []
    for width, direction, name in all_ports:
        base, _, field = name.partition(".")
        rng = "" if width == 1 else f"[{width - 1}:0] "
        if not field or base not in IFACES:
            if field:
                print(f"# WARNING: interface port '{base}' not in IFACES table — left as flat ports", file=sys.stderr)
            flat = name.replace(".", "_")
            decls.append(f"  {direction} logic {rng}{flat}")
            inner.append(f"    .{name}({flat})" if not field else f"    /* unmapped */ .{name}({flat})")
            continue
        iface, modport, params = IFACES[base]
        inst = SHARED[base]
        if inst not in seen_inst:
            seen_inst.add(inst)
            if iface == "axi_if":
                if not clk or not rst:
                    print("# cannot find the clock / reset ports for the axi_if instances "
                          "(use --clk / --rst)", file=sys.stderr)
                    sys.exit(1)
                pfx = (f"#(.AW({params}_AW), .DW({params}_DW), .IW({params}_IW), "
                       f".UW({params}_UW)) ")
                insts.append(f"  {iface} {pfx}{inst} (.clk({clk}), .rst_n({rst}));")
            else:
                insts.append(f"  {iface} {inst} ();")
        if base not in used_ifaces:
            used_ifaces.append(base)
        flat = f"{base}_{field}"
        decls.append(f"  {direction} logic {rng}{flat}")
        if direction == "input":
            conns.append(f"  assign {inst}.{field} = {flat};")
        else:
            conns.append(f"  assign {flat} = {inst}.{field};")
    for base in used_ifaces:
        iface, modport, _ = IFACES[base]
        inner.append(f"    .{base}({SHARED[base]}.{modport})")
    params = "".join(f"  localparam int {k} = {v};\n" for k, v in sorted(axi_params.items()))
    povr = ", ".join(f".{p.split('=', 1)[0]}({p.split('=', 1)[1]})" for p in a.param)
    ptxt = f" #({povr})" if povr else ""
    with open(a.out, "w") as fh:
        fh.write(f"// GENERATED by scripts/gen_inst_wrapper.py -- do not edit by hand.\n"
                 f"// Flat-port wrapper around {a.rtl_module} (instance netlist top {a.il_top}).\n"
                 f"module {a.rtl_module}_flat (\n")
        fh.write(",\n".join(decls) + "\n);\n")
        fh.write(params)
        fh.write("\n".join(insts) + "\n\n")
        fh.write(f"  {a.rtl_module}{ptxt} u_dut (\n" + ",\n".join(inner) + "\n  );\n\n")
        fh.write("\n".join(conns) + "\nendmodule\n")
    print(f"# wrote {a.out}: {len(decls)} ports, {len(insts)} interface instances, "
          f"clk={clk} rst={rst}")


if __name__ == "__main__":
    main()
