#!/usr/bin/env python3
# Print the dependency-closure .sv file list for an ACC top module, packages
# first (topologically), so read_slang / surelog get exactly what they need.
#
# Search roots: the ACC-local rtl/acc + rtl/pkg, PLUS the shared prim library
# and base packages already vendored for the TL-UL campaign
# (../pavona_tlul_equiv/rtl/{prim,pkg}) — no need to duplicate 199 prim files.
import re, glob, os, sys
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TLUL = os.path.normpath(os.path.join(HERE, '..', 'pavona_tlul_equiv'))
ROOTS = [f'{HERE}/rtl/acc', f'{HERE}/rtl/pkg',
         f'{TLUL}/rtl/prim', f'{TLUL}/rtl/tlul', f'{TLUL}/rtl/pkg']
defs = {}
files = {}
macro_bodies = {}   # `define NAME ... (with \-continuations)  ->  full body text
for d in ROOTS:
    for f in sorted(glob.glob(f'{d}/*.sv')):
        t = open(f, errors='replace').read()
        is_pkg = False
        for m in re.findall(r'^\s*module\s+(\w+)', t, re.M): defs.setdefault(m, f)
        for p in re.findall(r'^\s*package\s+(\w+)', t, re.M):
            defs.setdefault(p, f); is_pkg = True
        files.setdefault(f, is_pkg)
        # Collect `define macro bodies (backslash-continued): a module may be
        # instantiated ONLY inside a macro (prim_sparse_fsm_flop via
        # PRIM_FLOP_SPARSE_FSM in prim_flop_macros.sv), invisible to the token
        # scan below.  Keep the body so refs() can pull those modules in.
        lines = t.split('\n')
        i = 0
        while i < len(lines):
            m = re.match(r'\s*`define\s+(\w+)', lines[i])
            if m:
                name = m.group(1); body = [lines[i]]
                while lines[i].rstrip().endswith('\\') and i + 1 < len(lines):
                    i += 1; body.append(lines[i])
                macro_bodies[name] = '\n'.join(body)
            i += 1
# Defs (modules/pkgs) referenced from inside a macro body, transitively through
# nested macro references — precomputed per macro name.
_macro_defs_cache = {}
def macro_def_refs(mname, seen=None):
    if mname in _macro_defs_cache: return _macro_defs_cache[mname]
    if seen is None: seen = set()
    if mname in seen: return set()
    seen.add(mname)
    toks = set(re.findall(r'[A-Za-z_]\w*', macro_bodies.get(mname, '')))
    r = toks & set(defs.keys())
    for sub in toks & set(macro_bodies.keys()):
        r |= macro_def_refs(sub, seen)
    _macro_defs_cache[mname] = r
    return r
_tok_cache = {}
def refs(f):
    if f in _tok_cache: return _tok_cache[f]
    txt = re.sub(r'//[^\n]*', '', open(f, errors='replace').read())
    txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)
    toks = set(re.findall(r'[A-Za-z_]\w*', txt))
    r = toks & set(defs.keys())
    for mname in toks & set(macro_bodies.keys()):
        r |= macro_def_refs(mname)
    _tok_cache[f] = r
    return r
def closure(target):
    seen = set(); st = [target]
    while st:
        n = st.pop()
        if n in seen or n not in defs: continue
        seen.add(n)
        for r in refs(defs[n]):
            if r in defs and r not in seen: st.append(r)
    return {defs[n] for n in seen}
cl = closure(sys.argv[1])
pkgs = [f for f in cl if files.get(f)]
mods = [f for f in cl if not files.get(f)]
def dep_order(ps):
    name_of = {}
    for f in ps:
        for p in re.findall(r'^\s*package\s+(\w+)',
                            open(f, errors='replace').read(), re.M):
            name_of[p] = f
    ordered = []; placed = set()
    def visit(f):
        if f in placed: return
        for r in refs(f):
            if r in name_of and name_of[r] != f: visit(name_of[r])
        placed.add(f); ordered.append(f)
    for f in ps: visit(f)
    return ordered
print(' '.join(dep_order(pkgs) + sorted(mods)))
