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

def code_mask(text):
    """Per-character flags: True where the character is code, not a comment.

    Every scanner below counts brackets, and the hpdcache sources fence their
    sections with `//  {{{` / `//  }}}` fold markers.  Counting those as real
    braces made a declaration scan run past its `;` and swallow the whole port
    list into the wrapper's parameter block."""
    mask = [True] * len(text)
    i, n = 0, len(text)
    while i < n:
        two = text[i:i+2]
        if two == "//":
            j = text.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j): mask[k] = False
            i = j
        elif two == "/*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j): mask[k] = False
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            for k in range(i, min(j + 1, n)): mask[k] = False
            i = j + 1
        else:
            i += 1
    return mask

def match_close(text, open_idx, mask=None):
    """Index of the `)` closing the `(` at open_idx, ignoring comments."""
    mask = mask if mask is not None else code_mask(text)
    depth = 0
    for j in range(open_idx, len(text)):
        if not mask[j]:
            continue
        if text[j] == '(': depth += 1
        elif text[j] == ')':
            depth -= 1
            if depth == 0: return j
    return len(text)

def extract_param_block(text, modname):
    """Return the text inside the module's #( ... ) block."""
    m = re.search(r"module\s+" + re.escape(modname) + r"\b", text)
    if not m: raise SystemExit(f"module {modname} not found")
    mask = code_mask(text)
    # allow 'import pkg::*;' and comments between the name and #(
    i = m.end()
    while True:
        i = text.find("#(", i)
        if i < 0: return "", m.end()
        if mask[i]: break
        i += 2
    j = match_close(text, i + 1, mask)
    return text[i+2:j], j+1

def extract_port_block(text, after):
    mask = code_mask(text)
    i = after
    while i < len(text) and not (text[i] == "(" and mask[i]):
        i += 1
    j = match_close(text, i, mask)
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
    # The name may carry an UNPACKED dimension before the default
    # (`parameter copro_issue_resp_t CoproInstr [NbInstr] = {0}`).  Missing
    # those left the array parameter undeclared while its companion count was
    # taken from the real site, so the two disagreed and slang rejected the
    # default's concatenation: "requires 10 elements but got 1".
    for m in re.finditer(r"\b" + kw + r"\s+(?:type\s+)?(?:[\w:\[\]\.\$ ]+?\s+)?"
                         r"(\w+)\s*(?:\[[^\]]*\]\s*)*=", block):
        names.append(m.group(1))
    return names



def all_sv_files():
    """Every vendored source, core first (core definitions should win)."""
    rtl_root = os.path.dirname(CORE)
    core = sorted(glob.glob(f"{CORE}/**/*.sv", recursive=True))
    rest = [f for f in sorted(glob.glob(f"{rtl_root}/**/*.sv", recursive=True))
            if f not in set(core)]
    return core + rest

def find_parent_files(target):
    """Every file that INSTANTIATES `target`.

    A child often takes types that are local to its parent
    (`wt_dcache.sv` declares `localparam type wbuffer_t = struct packed {...}`
    and passes it to wt_dcache_wbuffer).  Those cannot come from cva6.sv, so
    the wrapper has to lift them from the real instantiation site — which is
    what the hand-written extras_<mod>.svh files do."""
    pat = re.compile(r"^\s*" + re.escape(target) + r"\s*#?\s*\(", re.M)
    out = []
    for f in all_sv_files():
        if os.path.basename(f) == f"{target}.sv":
            continue
        try:
            if pat.search(open(f, errors="ignore").read()):
                out.append(f)
        except OSError:
            pass
    return out

def find_parent_file(target):
    p = find_parent_files(target)
    return p[0] if p else None

def module_name_of(path):
    return os.path.splitext(os.path.basename(path))[0]

def ancestor_files(target, depth=4):
    """The instantiation chain above `target`, nearest ancestors first.

    A type a module needs is not always declared by its immediate parent:
    `wt_dcache_missunit` takes `dcache_rtrn_t`, but that is a localparam of
    `wt_cache_subsystem` — its GRANDparent — and is merely passed through
    `wt_dcache`.  Walking only one level up left the type at its
    `= logic` default and slang rejected every field access on it."""
    seen, order, frontier = set(), [], [target]
    for _ in range(depth):
        nxt = []
        for mod in frontier:
            for f in find_parent_files(mod):
                if f in seen:
                    continue
                seen.add(f); order.append(f); nxt.append(module_name_of(f))
        if not nxt:
            break
        frontier = nxt
    return order

def site_bindings(target):
    """`.PARAM(expr)` bindings from the module's real instantiation site.

    Same-name binding cannot express the common case where the parent renames:
    cva6.sv instantiates the AXI adapter as `.axi_req_t(noc_req_t)`.  Copying
    the site's own bindings reproduces the real hierarchy exactly, which is the
    whole point of this wrapper."""
    for f in find_parent_files(target):
        txt = open(f, errors="ignore").read()
        mask = code_mask(txt)
        m = None
        for cand in re.finditer(r"^[ \t]*" + re.escape(target) + r"\s*#\s*\(",
                                txt, re.M):
            if mask[cand.start()]:
                m = cand; break
        if not m:
            continue
        start = m.end()
        body, out = txt[start:match_close(txt, start - 1, mask)], {}
        for entry in split_param_entries(body):
            em = re.match(r"\.\s*(\w+)\s*\((.*)\)\s*$", entry.strip(), re.S)
            if em:
                out[em.group(1)] = " ".join(em.group(2).split())
        if out:
            return out, f
    return {}, None

def resolve_param(target, pname, known, depth=0, _seen=None):
    """What the real hierarchy gives `target`'s parameter `pname`.

    A binding is rarely a literal at the first level up.  `axi_shim` is given
    `.axi_req_t(axi_req_t)` by `std_nbdcache`, whose OWN `axi_req_t` parameter
    cva6.sv fills in with `noc_req_t` — so resolving one level finds only
    another placeholder, and the wrapper kept `= logic`.  Walk up until the
    name lands on something real: a literal/expression the wrapper can name, or
    an ancestor's localparam whose definition we can inline.

    Returns the text to use as the parameter's value, or None.
    """
    _seen = _seen or set()
    if depth > 6 or (target, pname) in _seen:
        return None
    _seen.add((target, pname))
    site, f = site_bindings(target)
    if not f or pname not in site:
        return None
    expr = site[pname]
    if re.fullmatch(r"\w+", expr):
        locals_ = parent_local_types(f, values=True)
        if expr in locals_:                       # parent declares it: inline
            return rhs_of(locals_[expr])
        up = resolve_param(module_name_of(f), expr, known, depth + 1, _seen)
        if up:
            return up
    return expr if expr_resolves(expr, known) else None

def closure_types(text, defs, known):
    """Ancestor type definitions that `text` references, transitively.

    An inlined struct is not self-contained: `dcache_rtrn_t` embeds
    `dcache_inval_t`, which is equally local to the ancestor, so inlining only
    the outer one leaves the wrapper referring to an undeclared identifier."""
    out, todo = {}, list(IDENT.findall(text))
    while todo:
        t = todo.pop()
        if t in out or t in known or t not in defs:
            continue
        out[t] = defs[t]
        todo += IDENT.findall(rhs_of(defs[t]))
    return out

def provider_types(wrp_dir):
    """Names supplied by helper packages shipped next to the wrappers.

    Some parameters cannot be resolved by walking the hierarchy at all: the
    hpdcache types are built by `HPDCACHE_TYPEDEF_*` macros inside
    cva6_hpdcache_subsystem's module BODY, which a wrapper cannot reach into.
    `hpdcache_equiv_pkg.svh` (generated by gen_hpdcache_pkg.py) re-emits that
    environment as a package; anything it declares is offered here as a
    last-resort binding.

    Returns {name: (package, include-file)}.
    """
    out = {}
    for f in sorted(glob.glob(os.path.join(wrp_dir, "*.svh"))):
        txt = open(f, errors="ignore").read()
        m = re.search(r"\bpackage\s+(\w+)\s*;", txt)
        if not m:
            continue
        # `HPDCACHE_TYPEDEF_REQ_ATTR_T(a_t, b_t, …, Cfg)` declares EVERY type
        # named in it, not just the first, so take all `*_t` arguments.
        names = set()
        for call in re.finditer(r"`\w*TYPEDEF_\w+\(([^;]*?)\)\s*;", txt, re.S):
            names |= {a.strip() for a in call.group(1).split(",")
                      if a.strip().endswith("_t")}
        names |= set(re.findall(r"\btypedef\s+[^;]*?(\w+)\s*;", txt))
        names |= set(re.findall(r"\blocalparam\s+(?:type\s+)?(?:[\w:]+\s+)*?"
                                r"(\w+)\s*=", txt))
        # Declarations lifted alongside these names are written in the
        # package's scope and spell its types unqualified (`hpdcache_cfg_t`),
        # so a wrapper that uses them needs the same imports.
        imports = re.findall(r"\bimport\s+([A-Za-z_]\w*)\s*::", txt)
        for n in names:
            out[n] = (m.group(1), os.path.basename(f), tuple(imports))
    return out

def package_names(pkgs):
    """Every name a package declares, so a site binding that uses one is usable.

    `.l_data_t(cache_line_t)` is only worth copying if the wrapper can name
    `cache_line_t`; most such names come from an imported package rather than
    from cva6.sv, and treating them as unresolvable threw away good bindings."""
    out = set()
    for f in all_sv_files() + glob.glob(f"{os.path.dirname(CORE)}/**/*.svh",
                                        recursive=True):
        base = os.path.splitext(os.path.basename(f))[0]
        if base not in pkgs:
            continue
        txt = open(f, errors="ignore").read()
        out |= set(re.findall(r"}\s*(\w+)\s*;", txt))            # struct/enum
        out |= set(re.findall(r"\btypedef\s+[^;]*?(\w+)\s*;", txt))
        out |= set(re.findall(r"\b(?:localparam|parameter)\s+"
                              r"(?:type\s+)?(?:\w+\s+)?(\w+)\s*=", txt))
    return out

def rhs_of(decl):
    """The right-hand side of a `localparam type X = <rhs>` declaration."""
    i = default_pos(decl)
    return decl[i+1:].strip().rstrip(";,").strip() if i >= 0 else decl

def drop_unsupported(entries, base_names, originals, added, providers):
    """Iterate until every entry resolves against what the wrapper declares."""
    entries = list(entries)
    while True:
        declared = set(base_names) | {param_names(e)[0] for e in entries
                                      if param_names(e)}
        changed = False
        for i, e in enumerate(entries):
            nm = param_names(e)
            if not nm or expr_resolves(rhs_of(e), declared):
                continue
            n = nm[0]
            if n in originals and e != originals[n]:
                entries[i] = originals[n]        # back to the module's default
                print(f"  reverted {n}: real value not expressible here")
            elif n in added:
                del entries[i]
                print(f"  dropped lifted {n}: not expressible here")
            else:
                continue                         # its own default; nothing better
            changed = True
            break
        if not changed:
            return entries

def order_by_dependency(entries):
    """Sort parameter entries so none is used before it is declared.

    The site's own order is not usable: the target lists its parameters in its
    own order, but the definitions we lift from ancestors reference each other
    (`dcache_rtrn_t` embeds `dcache_inval_t`), and slang rejects a forward
    reference inside a parameter list."""
    placed, names = [], [param_names(e)[0] for e in entries if param_names(e)]
    pending = list(entries)
    for _ in range(len(pending) + 1):
        if not pending:
            break
        progressed = False
        for e in list(pending):
            nm = param_names(e)
            n = nm[0] if nm else None
            deps = {t for t in IDENT.findall(rhs_of(e))
                    if t in names and t != n}
            if deps <= {param_names(p)[0] for p in placed if param_names(p)}:
                placed.append(e); pending.remove(e); progressed = True
        if not progressed:
            break                       # a cycle: keep the original order
    return placed + pending

IDENT = re.compile(r"\b[A-Za-z_]\w*\b")
SV_KEYWORDS = {"logic", "bit", "int", "unsigned", "signed", "struct", "packed",
               "union", "enum", "byte", "shortint", "longint", "type", "reg",
               "wire", "if", "else", "1", "0",
               # assignment-pattern and declaration keywords that appear inside
               # parameter defaults -- `'{default: 0}` read `default` as a name
               "default", "const", "automatic", "static", "real", "string",
               "void", "null", "time", "integer", "genvar", "localparam",
               "parameter"}

def expr_resolves(expr, known):
    """True when every identifier in `expr` is available in the wrapper.

    A site binding is only usable if the wrapper can actually name what the
    parent named; otherwise fall back to same-name binding or the default."""
    # Comments first: the lifted struct types carry the source's own inline
    # commentary (`logic vld; // invalidate only affected way`), and prose
    # words are not identifiers.
    mask = code_mask(expr)
    expr = "".join(c for i, c in enumerate(expr) if mask[i])
    # A package-qualified reference always resolves — drop the whole thing,
    # qualifier and name.  Stripping only the `pkg::` prefix left the member
    # behind (`fpnew_pkg::CONV` -> `CONV`), and enum members are not in any
    # name set we build, so good expressions looked unresolvable.
    # Assignment-pattern member labels name a field of the target type, not
    # something to declare: fpnew's `Implementation` literal is written
    # `'{PipeRegs: '{...}, UnitTypes: '{...}}`.  Only strip where a label can
    # legally appear — right after `{` or `,` — so a ternary's `:` keeps its
    # operands, which ARE references.
    expr = re.sub(r"(?<=[{,])\s*\b\w+\s*:(?!:)", "", expr)
    # System functions are not identifiers to declare: `$clog2(DEPTH)` was
    # tokenized as `clog2`, which nothing declares, so the whole value was
    # rejected and reverted to the module's default.
    expr = re.sub(r"\$\w+", "", expr)
    expr = re.sub(r"\b\w+\s*::\s*\w+", "", expr)
    # Likewise a member select: in `CVA6Cfg.BHTEntries` only CVA6Cfg has to be
    # declared — BHTEntries is a field of it.  Counting fields as identifiers
    # made real values (`.NR_ENTRIES(CVA6Cfg.BHTEntries)`) look unresolvable,
    # and they were silently reverted to the module's default.
    expr = re.sub(r"\.\s*\w+", "", expr)
    # And a struct body declares its members rather than referencing them:
    # in `struct packed { logic [CVA6Cfg.VLEN-1:0] pc; }` only CVA6Cfg must
    # exist, not `pc`.  Counting members as references reverted whole lifted
    # struct types back to `logic`, which is exactly the placeholder this
    # generator exists to replace.
    expr = re.sub(r"\b\w+\s*(?=[;,]\s*\})|\b\w+\s*(?=;)", "", expr)
    for tok in IDENT.findall(expr):
        if tok in SV_KEYWORDS or tok in known or tok.isdigit():
            continue
        if re.match(r"^\d", tok):        # 32'd7, 1'b0 fragments
            continue
        return False
    return True

def default_pos(entry):
    """Index of the `=` introducing a `#()` entry's default, or -1.

    Must ignore comments: entries carry the source's own commentary, and a
    `>=2` in a leading comment reads as the default's `=` — which made
    `rhs_of` return prose and every check built on it come out wrong.
    """
    depth, mask = 0, code_mask(entry)
    for i, c in enumerate(entry):
        if not mask[i]:
            continue
        if c in "({[": depth += 1
        elif c in ")}]": depth -= 1
        elif c == "=" and depth == 0 and entry[i:i+2] != "==" \
                and (i == 0 or entry[i-1] not in "<>!="):
            return i
    return -1

def retarget_entry(entry, expr):
    """Rewrite a `#()` entry's default to `expr`, keeping its declaration."""
    i = default_pos(entry)
    return (entry[:i].rstrip() if i >= 0 else entry.rstrip()) + " = " + expr

def parent_local_types(parent_file, values=False):
    """Top-level `localparam [type] NAME = ...;` declarations in a module body.

    With values=True this also captures VALUE localparams.  The whole hpdcache
    family hangs off one of those: `HPDcacheCfg` is bound from the subsystem's
    `localparam hpdcache_cfg_t HPDcacheCfg = hpdcacheBuildConfig(...)`, and
    matching only `localparam type` left every hpdcache module running on the
    `'0` default config — which is why they variously reported zero-width
    selects, unindexable scalars, and the design's own `$fatal`."""
    if not parent_file:
        return {}
    txt = open(parent_file, errors="ignore").read()
    mask = code_mask(txt)
    out = {}
    pat = (r"\blocalparam\s+(?:type\s+)?(?:[\w:]+\s+)*?(\w+)\s*="
           if values else r"\blocalparam\s+type\s+(\w+)\s*=")
    for m in re.finditer(pat, txt):
        if not mask[m.start()]:
            continue
        i = m.end(); depth = 0
        while i < len(txt):
            c = txt[i]
            if not mask[i]:
                i += 1; continue
            if c in "{([": depth += 1
            elif c in "})]":
                # A `localparam type` can live in a module's parameter LIST, in
                # which case its terminator is the list's `,` or the closing
                # `)` — never a `;`.  Scanning on for a `;` walked into the
                # module body and captured the whole port list.
                if depth == 0: break
                depth -= 1
            elif c in ";," and depth == 0: break
            i += 1
        out[m.group(1)] = txt[m.start():i].strip()
    return out

def split_param_entries(block):
    """Yield the target's #() entries, split on top-level commas.

    Keeps struct/array bodies intact (`parameter type x = struct packed {a; b;}`
    contains commas and semicolons inside braces)."""
    out, depth, cur = [], 0, []
    mask = code_mask(block)
    for i, c in enumerate(block):
        if not mask[i]:
            cur.append(c); continue
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
    # Nearest ancestor wins, so a pass-through parent cannot shadow the
    # grandparent that actually declares the type.
    ptypes = {}
    for anc in reversed(ancestor_files(target)):
        ptypes.update(parent_local_types(anc, values=True))
    # Inherit the target's OWN package imports, and its PARENT's.  A module
    # compiled inside its parent sees whatever that parent imported
    # (`instr_decoder` uses cvxif_instr_pkg's copro_issue_resp_t without
    # importing it), and the wrapper stands in for that parent.
    tgt_pkgs = []
    for src in (tgt_txt, *(open(f, errors="ignore").read()
                           for f in find_parent_files(target)[:1])):
        for pm in re.finditer(r"\bimport\s+([A-Za-z_]\w*)\s*::", src):
            if pm.group(1) not in tgt_pkgs:
                tgt_pkgs.append(pm.group(1))
    pkg_names = package_names(set(tgt_pkgs) | {"ariane_pkg"})

    providers = provider_types(os.path.dirname(out_path) or ".")
    need_includes, need_imports = set(), set()

    site, site_file = site_bindings(target)
    if site_file:
        print(f"  instantiation site: {os.path.relpath(site_file, CORE)} "
              f"({len(site)} bindings)")

    # Names the wrapper already declares before the target's own parameters.
    base_names = set(wrp_names) | pkg_names | set(providers)
    own, originals, added = [], {}, set()
    for entry in split_param_entries(tgt_params):
        nm = param_names(entry)
        if not nm or nm[0] in wrp_names:
            continue
        n = nm[0]
        originals[n] = entry
        # Prefer the value the module is really given over its default.  A
        # default exists to make the file standalone-parsable, not to describe
        # the design: `parameter type axi_req_t = logic` makes every field
        # access illegal, and `hpdcache_data_downsize`'s `DEPTH = 0` trips its
        # own `$fatal`.  The instantiation site has the real value.
        # The helper package wins where it applies: what the hierarchy walk
        # finds for these names is an ancestor localparam whose definition
        # calls functions that live in that ancestor's body
        # (`HPDcacheUserCfg = hpdcacheSetConfig()`), so inlining it just moves
        # the undeclared identifier into the wrapper.  The package carries the
        # function too.
        real = None
        if n in providers:
            pkg, inc, pimports = providers[n]
            need_imports.update(pimports)
            own.append(retarget_entry(entry, f"{pkg}::{n}"))
            need_includes.add(inc)
            print(f"  took helper-package value: {n} = {pkg}::{n}")
            wrp_names.add(n)
            continue
        real = resolve_param(target, n, wrp_names | pkg_names | set(providers))
        if real is not None:
            own.append(retarget_entry(entry, real))
            print(f"  took site value: {n} = {' '.join(real.split())[:48]}")
        elif re.search(r"\bparameter\s+type\b", entry) and n in ptypes:
            # `parameter type X = logic` + an ancestor's definition of X ->
            # declare X as that real type instead of the placeholder default.
            own.append(ptypes[n].replace("localparam", "parameter", 1))
            print(f"  bound parent-local type: {n}")
        else:
            own.append(entry)
        wrp_names.add(n)
    # cva6.sv's BODY localparams are emitted into the wrapper's body, i.e.
    # AFTER the port list.  When the ports — or a parameter we just took from
    # the instantiation site (tag_cmp's `.NR_PORTS(NumPorts + 1)`) — reference
    # one, slang reports "identifier 'NumPorts' used before its declaration".
    # Hoist just those, ahead of the entries that use them.
    hoist_body = []
    for stmt in [s for s in cva6_body_lp.split("\n") if s.strip()]:
        nm = param_names(stmt)
        if nm and re.search(r"\b" + re.escape(nm[0]) + r"\b",
                            tgt_ports + "\n" + "\n".join(own)):
            hoist_body.append(stmt.strip().rstrip(";"))
    if hoist_body:
        extras_pl += ("," if extras_pl else ",\n") + "\n" + ",\n".join(
            "  " + h for h in hoist_body)
        # drop them from the body so they are not declared twice
        for h in hoist_body:
            cva6_body_lp = cva6_body_lp.replace(h + ";", "")
        print(f"  hoisted cva6 body localparams used in ports: "
              f"{', '.join(param_names(h)[0] for h in hoist_body)}")

    # An inlined definition can also reference an ancestor's PARAMETERS
    # (cvxif_example_coprocessor's `registers_t` is sized by its own XLEN and
    # NrRgprPorts), which no localparam scan finds.  Declare those too, with
    # the value the ancestor is really given where we can resolve it.
    anc_params = {}
    for anc in reversed(ancestor_files(target)):
        try:
            blk, _ = extract_param_block(open(anc, errors="ignore").read(),
                                         module_name_of(anc))
        except SystemExit:
            continue
        for e in split_param_entries(blk):
            nm = param_names(e)
            if nm:
                anc_params[nm[0]] = (e, module_name_of(anc))
    # A value lifted here can itself reference further ancestor parameters
    # (fpnew's `Implementation` literal is written in terms of `LAT_COMP_FP32`
    # and friends), so keep going until nothing new is referenced -- a single
    # pass only sees what the target's own parameters mention.
    free = []
    for _ in range(8):
        own_txt = "\n".join(own + free)
        before = len(free)
        for n, (entry, mod) in anc_params.items():
            if n in wrp_names or n in pkg_names:
                continue
            if not re.search(r"\b" + re.escape(n) + r"\b", own_txt):
                continue
            if n in providers:
                # A value resolved through this name (`DEPTH =
                # HPDcacheCfg.u.flushFifoDepth`) needs the name itself
                # declared; skipping it because the package HAS it left the
                # reference dangling in the wrapper.
                pkg, inc, pimports = providers[n]
                need_imports.update(pimports)
                free.append(retarget_entry(entry, f"{pkg}::{n}"))
                need_includes.add(inc)
                added.add(n); wrp_names.add(n)
                continue
            known = wrp_names | pkg_names | set(providers)
            real = resolve_param(mod, n, known)
            if real is None and not expr_resolves(rhs_of(entry), known):
                # Its default is written in terms the wrapper cannot name — an
                # ancestor's generate-loop variable (`LANE = unsigned'(lane)`).
                # Emitting it anyway breaks wrappers that were fine without it.
                continue
            free.append(retarget_entry(entry, real) if real else entry)
            # NOTE deliberately no `originals` entry: if this declaration later
            # proves unsupportable it must be DROPPED, and everything derived
            # from it reverted to the target's own default.  Falling back to
            # the ancestor's default instead fabricates a third value that is
            # neither the real hierarchy's nor the module's own — fpnew's
            # `PipeConfig` became `Implementation.PipeConfig` off a
            # `DEFAULT_NOREGS` that the real design never uses.
            added.add(n)
            wrp_names.add(n)
        if len(free) == before:
            break
    if free:
        own += free
        print(f"  declared ancestor params used by lifted types: "
              f"{', '.join(param_names(f)[0] for f in free)}")

    # An inlined ancestor type drags in the ancestor types it embeds.
    dep = closure_types("\n".join(own), ptypes, wrp_names | pkg_names)
    # Drop anything we cannot actually declare here.  `parent_local_types`
    # sees the whole file, generate blocks included, so a name can resolve to a
    # localparam written in terms of a genvar (`LANE = unsigned'(lane)`).
    # Dropping one can invalidate another, so iterate to a fixpoint.
    while True:
        allowed = wrp_names | pkg_names | set(dep) | set(providers)
        bad = [n for n, d in dep.items()
               if n not in providers and not expr_resolves(rhs_of(d), allowed)]
        if not bad:
            break
        for n in bad:
            del dep[n]
    for n, d in dep.items():
        d = d.replace("localparam", "parameter", 1)
        if n in providers:
            # Keep the declaration but take its VALUE from the package: the
            # ancestor's own definition calls functions that live in that
            # ancestor's body (`HPDcacheUserCfg = hpdcacheSetConfig()`), so
            # inlining it just relocates the undeclared identifier.
            pkg, inc, pimports = providers[n]
            need_imports.update(pimports)
            d = retarget_entry(d, f"{pkg}::{n}")
            need_includes.add(inc)
        own.append(d)
        added.add(n)
    if dep:
        print(f"  pulled in referenced ancestor types: {', '.join(dep)}")
        wrp_names |= set(dep)

    # Self-containment: every entry must be expressible with what this wrapper
    # declares.  A value lifted from the hierarchy can depend on names that do
    # not survive the trip (an ancestor's genvar-indexed localparams), and
    # emitting it anyway breaks a wrapper that was fine on defaults.  So drop
    # what we added but cannot support, and revert any entry whose real value
    # depended on it — falling back to the module's own default, which is
    # exactly where this generator started.
    own = drop_unsupported(own, base_names, originals, added, providers)
    if own:
        own = order_by_dependency(own)
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
    pkgs = import_pkgs or (["ariane_pkg"] + [q for q in tgt_pkgs if q != "ariane_pkg"])
    pkgs = pkgs + [q for q in sorted(need_imports) if q not in pkgs]
    if tgt_pkgs:
        print(f"  inherited target imports: {', '.join(tgt_pkgs)}")
    imports = "\n".join(f"  import {p}::*;" for p in pkgs)
    helper_includes = "".join(f'`include "{i}"\n' for i in sorted(need_includes))
    wtop = f"{target}_equiv"
    out = f"""// AUTO-GENERATED per-module equivalence wrapper for {target}
// Parameter environment copied verbatim from cva6.sv (build_config-computed
// CVA6Cfg + shared type params) = the values used in the real hierarchy.
`include "rvfi_types.svh"
`include "cvxif_types.svh"
{helper_includes}
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
