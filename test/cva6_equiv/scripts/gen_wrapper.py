#!/usr/bin/env python3
"""Generate a per-module equivalence wrapper for CVA6.

The wrapper copies cva6.sv's OWN parameter block verbatim (CVA6Cfg =
build_config(...) plus every shared `parameter/localparam type`), mirrors the
target module's port list, and instantiates the target binding every
same-named parameter — reproducing the real hierarchy's parameterization.
"""
import re, sys, os, glob

# Default to the VENDORED CVA6 RTL so wrapper generation works from a clean
# checkout; override with CVA6_CORE=<path> to point at an upstream working tree
# (e.g. when refreshing the vendored copy).
CORE = os.environ.get(
    "CVA6_CORE",
    os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                 "rtl", "core"))

def extract_param_block(text, modname):
    """Return the text inside the module's #( ... ) block."""
    m = re.search(r"module\s+" + re.escape(modname) + r"\b", text)
    if not m: raise SystemExit(f"module {modname} not found")
    i = text.find("#", m.end())
    # allow 'import pkg::*;' between name and #(
    i = text.find("#(", m.end())
    if i < 0: return "", m.end()
    depth = 0; j = i + 1
    while j < len(text):
        if text[j] == '(': depth += 1
        elif text[j] == ')':
            depth -= 1
            if depth == 0: break
        j += 1
    return text[i+2:j], j+1

def extract_port_block(text, after):
    i = text.find("(", after)
    depth = 0; j = i
    while j < len(text):
        if text[j] == '(': depth += 1
        elif text[j] == ')':
            depth -= 1
            if depth == 0: break
        j += 1
    return text[i+1:j]

def extract_body_localparams(text, header_end):
    """Top-level `localparam ...;` statements in the module body (cva6.sv
    defines interrupts_t / INTERRUPTS there, not in the param block)."""
    body = text[header_end:text.find("endmodule", header_end)]
    out = []
    i = 0
    while True:
        j = body.find("\n  localparam ", i)
        if j < 0: break
        k = j + 1; depth = 0
        while k < len(body):
            c = body[k]
            if c in "({[": depth += 1
            elif c in ")}]": depth -= 1
            elif c == ";" and depth == 0: break
            k += 1
        out.append(body[j+1:k+1])
        i = k
    return "\n".join(out)

def param_names(block, bindable_only=False):
    # parameter/localparam [type] NAME  (= default).  bindable_only: only
    # `parameter` entries — a localparam in a target's #() header (fifo_v3's
    # derived ADDR_DEPTH) cannot be overridden at instantiation.
    names = []
    kw = r"parameter" if bindable_only else r"(?:parameter|localparam)"
    for m in re.finditer(r"\b" + kw + r"\s+(?:type\s+)?(?:[\w:\[\]\.\$ ]+?\s+)?(\w+)\s*=", block):
        names.append(m.group(1))
    return names



def find_parent_file(target):
    """The file of the module that INSTANTIATES `target`.

    A child often takes types that are local to its parent
    (`wt_dcache.sv` declares `localparam type wbuffer_t = struct packed {...}`
    and passes it to wt_dcache_wbuffer).  Those cannot come from cva6.sv, so
    the wrapper has to lift them from the real instantiation site — which is
    what the hand-written extras_<mod>.svh files do."""
    pat = re.compile(r"^\s*" + re.escape(target) + r"\s*#?\s*\(", re.M)
    for f in glob.glob(f"{CORE}/**/*.sv", recursive=True):
        if os.path.basename(f) == f"{target}.sv":
            continue
        try:
            if pat.search(open(f, errors="ignore").read()):
                return f
        except OSError:
            pass
    return None

def parent_local_types(parent_file):
    """Top-level `localparam type NAME = ...;` declarations in a module body."""
    if not parent_file:
        return {}
    txt = open(parent_file, errors="ignore").read()
    out = {}
    for m in re.finditer(r"\blocalparam\s+type\s+(\w+)\s*=", txt):
        i = m.end(); depth = 0
        while i < len(txt):
            c = txt[i]
            if c in "{([": depth += 1
            elif c in "})]": depth -= 1
            elif c == ";" and depth == 0: break
            i += 1
        out[m.group(1)] = txt[m.start():i].strip()
    return out

def split_param_entries(block):
    """Yield the target's #() entries, split on top-level commas.

    Keeps struct/array bodies intact (`parameter type x = struct packed {a; b;}`
    contains commas and semicolons inside braces)."""
    out, depth, cur = [], 0, []
    for c in block:
        if c in "({[": depth += 1
        elif c in ")}]": depth -= 1
        if c == "," and depth == 0:
            out.append("".join(cur)); cur = []
        else:
            cur.append(c)
    if "".join(cur).strip(): out.append("".join(cur))
    return [e.strip() for e in out if e.strip()]

def gen(target, out_path, extra_binds=None, import_pkgs=None):
    cva6_txt = open(f"{CORE}/cva6.sv").read()
    cva6_params, _ = extract_param_block(cva6_txt, "cva6")
    tgt_file = f"{CORE}/{target}.sv"
    if not os.path.exists(tgt_file):
        # search
        import glob
        cands = glob.glob(f"{CORE}/**/{target}.sv", recursive=True)
        if not cands:
            # Vendored common_cells / axi live outside core/ (popcount, lzc, …)
            # but are part of the design and worth proving too.
            rtl_root = os.path.dirname(CORE)
            cands = glob.glob(f"{rtl_root}/**/{target}.sv", recursive=True)
        if not cands: raise SystemExit(f"{target}.sv not found under {CORE}")
        tgt_file = cands[0]
    tgt_txt = open(tgt_file).read()
    tgt_params, after = extract_param_block(tgt_txt, target)
    tgt_ports = extract_port_block(tgt_txt, after)

    # cva6.sv BODY localparams (interrupts_t, INTERRUPTS, ...)
    _, cva6_hdr_end = extract_param_block(cva6_txt, "cva6")
    cva6_body_lp = extract_body_localparams(cva6_txt, cva6_hdr_end)

    # Optional per-module extras (extras_<mod>.svh next to the output): local
    # typedefs/localparams copied from the module's REAL instantiation site
    # (e.g. frontend.sv's `localparam type ras_t = struct packed {...}`), for
    # target params that are parent-local rather than cva6.sv-level.  Names
    # declared there participate in same-name binding.
    extras = ""
    efile = os.path.join(os.path.dirname(out_path) or ".", f"extras_{target}.svh")
    if os.path.exists(efile):
        extras = open(efile).read()

    # The wrapper's PORT list may use these types, so they must be declared in
    # the wrapper's PARAMETER block (localparam entries are legal there), not
    # the body.  Convert statement `;` at brace-depth 0 into param-list `,`
    # (struct-member semicolons inside {} are kept).
    extras_pl = ""
    if extras.strip():
        out_chars, depth = [], 0
        for c in extras:
            if c in "{([": depth += 1
            elif c in "})]": depth -= 1
            elif c == ";" and depth == 0:
                out_chars.append(",")
                continue
            out_chars.append(c)
        body = "".join(out_chars).rstrip().rstrip(",")
        extras_pl = ",\n" + body

    # A target may use its OWN body localparam in its PORT LIST
    # (perf_counters' `NumPorts`, popcount's `PopcountWidth`).  The port list is
    # copied verbatim into the wrapper, so those names must be declared BEFORE
    # the ports — i.e. in the wrapper's parameter block, not the body, or slang
    # reports "identifier used before its declaration".  Hoist only the ones the
    # port list actually references, so unrelated body localparams (which may
    # depend on signals) stay put.
    tgt_body_lp = extract_body_localparams(tgt_txt, after)
    hoisted = []
    for stmt in [s for s in tgt_body_lp.split("\n") if s.strip()]:
        nm = param_names(stmt)
        if nm and re.search(r"\b" + re.escape(nm[0]) + r"\b", tgt_ports):
            hoisted.append(stmt.strip().rstrip(";"))
    if hoisted:
        extras_pl += ("," if extras_pl else ",\n") + "\n" + ",\n".join(
            "  " + h for h in hoisted)
        print(f"  hoisted target localparams used in ports: "
              f"{', '.join(param_names(h)[0] for h in hoisted)}")

    wrp_names = set(param_names(cva6_params)) | set(param_names(cva6_body_lp)) \
                | set(param_names(extras)) | set(param_names(tgt_body_lp))

    # A generic library module parameterises its own ports
    # (`hpdcache_fifo_reg #(parameter int WIDTH = 8) (input logic [WIDTH-1:0] …)`).
    # The wrapper copies that port list verbatim, so every such name must be
    # declared BEFORE the ports or slang reports "use of undeclared identifier
    # 'WIDTH'" — the single biggest cause of wrappers that would not elaborate.
    # Re-declare the target's own entries, keeping their defaults, but only the
    # ones cva6.sv / extras do not already provide (those must win, since they
    # carry the values the real hierarchy uses).
    # Types a target takes but nothing here defines are usually local to its
    # PARENT; lift them from the real instantiation site so a
    # `parameter type foo_t = logic` default does not survive into the wrapper
    # (slang then rejects every field access: "invalid member access for type
    # 'wbuffer_t' (aka 'logic')").
    ptypes = parent_local_types(find_parent_file(target))

    # cva6.sv's BODY localparams are emitted into the wrapper's body, i.e.
    # AFTER the port list.  When the target's ports reference one of them
    # (perf_counters' NumPorts) slang reports "identifier 'NumPorts' used
    # before its declaration".  Hoist just those into the parameter block.
    hoist_body = []
    for stmt in [s for s in cva6_body_lp.split("\n") if s.strip()]:
        nm = param_names(stmt)
        if nm and re.search(r"\b" + re.escape(nm[0]) + r"\b", tgt_ports):
            hoist_body.append(stmt.strip().rstrip(";"))
    if hoist_body:
        extras_pl += ("," if extras_pl else ",\n") + "\n" + ",\n".join(
            "  " + h for h in hoist_body)
        # drop them from the body so they are not declared twice
        for h in hoist_body:
            cva6_body_lp = cva6_body_lp.replace(h + ";", "")
        print(f"  hoisted cva6 body localparams used in ports: "
              f"{', '.join(param_names(h)[0] for h in hoist_body)}")

    own = []
    for entry in split_param_entries(tgt_params):
        nm = param_names(entry)
        if not nm or nm[0] in wrp_names:
            continue
        n = nm[0]
        # `parameter type X = logic` + a parent/package definition of X ->
        # declare X as that real type instead of the placeholder default.
        if re.search(r"\bparameter\s+type\b", entry) and n in ptypes:
            own.append(ptypes[n].replace("localparam", "parameter", 1))
            print(f"  bound parent-local type: {n}")
        else:
            own.append(entry)
        wrp_names.add(n)
    if own:
        extras_pl += ("," if extras_pl else ",\n") + "\n" + ",\n".join(
            "  " + o.replace("\n", "\n  ") for o in own)
        print(f"  declared target's own params: "
              f"{', '.join(param_names(o)[0] for o in own)}")
    binds = []
    unbound = []
    for p in param_names(tgt_params, bindable_only=True):
        if extra_binds and p in extra_binds:
            binds.append(f".{p}({extra_binds[p]})")
        elif p in wrp_names:
            binds.append(f".{p}({p})")
        else:
            unbound.append(p)

    # Inherit the target's OWN package imports.  A module that says
    # `import hpdcache_pkg::*;` uses that package's types in its port list, and
    # the wrapper copies that port list verbatim — without the same import
    # slang stops at "use of undeclared identifier 'hpdcache_cfg_t'".  This is
    # the single biggest remaining cause of wrappers that will not elaborate.
    tgt_pkgs = []
    for pm in re.finditer(r"\bimport\s+([A-Za-z_]\w*)\s*::", tgt_txt):
        if pm.group(1) not in tgt_pkgs:
            tgt_pkgs.append(pm.group(1))
    pkgs = import_pkgs or (["ariane_pkg"] + [q for q in tgt_pkgs if q != "ariane_pkg"])
    if tgt_pkgs:
        print(f"  inherited target imports: {', '.join(tgt_pkgs)}")
    imports = "\n".join(f"  import {p}::*;" for p in pkgs)
    wtop = f"{target}_equiv"
    out = f"""// AUTO-GENERATED per-module equivalence wrapper for {target}
// Parameter environment copied verbatim from cva6.sv (build_config-computed
// CVA6Cfg + shared type params) = the values used in the real hierarchy.
`include "rvfi_types.svh"
`include "cvxif_types.svh"

module {wtop}
{imports}
#(
{cva6_params}{extras_pl}
) (
{tgt_ports}
);

{cva6_body_lp}

  {target} #(
      {(',' + chr(10) + '      ').join(binds)}
  ) dut (.*);

endmodule
"""
    open(out_path, "w").write(out)
    print(f"wrote {out_path}; bound: {len(binds)}; kept-default: {unbound}")

if __name__ == "__main__":
    target = sys.argv[1]
    # Default output next to the other wrappers, so `gen_wrapper.py <mod>`
    # drops the file where the runner looks for it.
    _wdir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                         "wrappers")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_wdir, f"wrapper_{target}.sv")
    extra = dict(kv.split("=",1) for kv in sys.argv[3:])
    gen(target, out, extra)
