#!/usr/bin/env python3
# Print the dependency-closure .sv file list for a TL-UL top module, packages
# first (topologically), so read_slang / surelog get exactly what they need.
import re, glob, os, sys
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
defs = {}
files = {}
for d in ('rtl/prim','rtl/tlul','rtl/pkg'):
    for f in sorted(glob.glob(f'{HERE}/{d}/*.sv')):
        t = open(f, errors='replace').read()
        is_pkg = False
        for m in re.findall(r'^\s*module\s+(\w+)', t, re.M): defs.setdefault(m, f)
        for p in re.findall(r'^\s*package\s+(\w+)', t, re.M):
            defs.setdefault(p, f); is_pkg = True
        files[f] = is_pkg
_tok_cache = {}
def refs(f):
    if f in _tok_cache: return _tok_cache[f]
    txt = re.sub(r'//[^\n]*','', open(f, errors='replace').read())
    txt = re.sub(r'/\*.*?\*/','', txt, flags=re.S)
    toks = set(re.findall(r'[A-Za-z_]\w*', txt))
    r = toks & set(defs.keys())
    _tok_cache[f] = r
    return r
def closure(target):
    seen=set(); st=[target]
    while st:
        n=st.pop()
        if n in seen or n not in defs: continue
        seen.add(n)
        for r in refs(defs[n]):
            if r in defs and r not in seen: st.append(r)
    return {defs[n] for n in seen}
cl = closure(sys.argv[1])
# order: packages first (by dependency), then modules
pkgs = [f for f in cl if files.get(f)]
mods = [f for f in cl if not files.get(f)]
# topo-sort packages by their inter-package refs
def dep_order(ps):
    name_of = {}
    for f in ps:
        for p in re.findall(r'^\s*package\s+(\w+)', open(f,errors='replace').read(), re.M):
            name_of[p]=f
    ordered=[]; placed=set()
    def visit(f):
        if f in placed: return
        for r in refs(f):
            if r in name_of and name_of[r]!=f: visit(name_of[r])
        placed.add(f); ordered.append(f)
    for f in ps: visit(f)
    return ordered
print(' '.join(dep_order(pkgs) + sorted(mods)))
