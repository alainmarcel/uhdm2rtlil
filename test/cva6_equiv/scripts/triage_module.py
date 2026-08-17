#!/usr/bin/env python3
"""Robust cex triage for a module-equiv failure.
Usage: triage_module.py <module> [--time T]
Parses work_<mod>/miter.log's LAST counterexample table, finds the time step
where trigger=1, dumps gold/gate ILs (cached), evals both with the full input
vector, prints per-output diffs."""
import re, subprocess, sys, os

mod = sys.argv[1]
force_t = None
if '--time' in sys.argv: force_t = int(sys.argv[sys.argv.index('--time')+1])
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = f"{HERE}/work/{mod}"
# Paths are derived from this file's location so the script works from any
# checkout; override with UHDM2RTLIL_ROOT if the build lives elsewhere.
_ROOT  = os.environ.get("UHDM2RTLIL_ROOT", os.path.abspath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")))
YOSYS  = os.path.join(_ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(_ROOT, "build", "uhdm2rtlil.so")
FLIST = os.environ.get("CVA6_FLIST", f"{HERE}/work/cva6.f")
os.chdir(WORK)

txt = open('miter.log').read()
tail = txt[txt.rfind('model found: FAIL'):]
# rows: Time \name dec hex bin  (dec/hex may be '--')
rows = re.findall(r'^\s+(\d+) \\(\S+)\s+(\S+)\s+(\S+)\s+([01xz]+)\s*$', tail, re.M)
by_t = {}
for t, name, dec, hx, b in rows:
    by_t.setdefault(int(t), {})[name] = b
trig_ts = [t for t, d in sorted(by_t.items()) if d.get('trigger', '0').lstrip('0') == '1']
print("time steps:", sorted(by_t), " trigger=1 at:", trig_ts)
tt = force_t if force_t is not None else (trig_ts[0] if trig_ts else max(by_t))
d = by_t[tt]
print(f"using t={tt}")
for n, b in sorted(d.items()):
    if n.startswith('in_'):
        print(f"  {n[3:]:24s} = {hex(int(b,2)) if len(b)>1 else b}  ({len(b)}b)")

# dump ILs if missing
if not os.path.exists('gold.il') or os.path.getmtime('gold.il') < os.path.getmtime('slpp_all/surelog.uhdm'):
    ys = f"""read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {mod}_equiv
flatten; proc; opt -fast
write_rtlil gold.il
design -reset
read_slang -f {FLIST} ../wrapper_{mod}.sv --top {mod}_equiv
hierarchy -check -top {mod}_equiv
flatten; proc; opt -fast
write_rtlil gate.il"""
    open('d.ys','w').write(ys)
    subprocess.run([YOSYS,'-m',PLUGIN,'-q','d.ys'], capture_output=True, text=True)

sets = ' '.join(f"-set {n[3:]} {len(b)}'b{b}" for n, b in d.items() if n.startswith('in_'))
outs = [re.sub(r'.*output \d+ \\', '', l).strip() for l in open('gold.il') if re.match(r'\s+wire.*output', l)]
shows = ' '.join('-show ' + o for o in outs)
res = {}
for il in ('gold', 'gate'):
    r = subprocess.run([YOSYS, '-p', f"read_rtlil {il}.il; eval {sets} {shows}"],
                       capture_output=True, text=True)
    for l in r.stdout.split('\n'):
        m = re.search(r"Eval result: \\(\S+) = (\d+)'([01xzm]+)\.", l)
        if m: res.setdefault(m.group(1), {})[il] = m.group(3)
    if 'ERROR' in r.stdout:
        print(f"[{il}] " + [l for l in r.stdout.split('\n') if 'ERROR' in l][0])
ok = True
for k, v in sorted(res.items()):
    g, s = v.get('gold', '?'), v.get('gate', '?')
    if g != s:
        ok = False
        db = [i for i, (a, b) in enumerate(zip(g[::-1], s[::-1])) if a != b]
        print(f"DIFF {k}: bits {db}")
        print(f"  gold(UHDM)  = {hex(int(g,2)) if 'x' not in g else g}")
        print(f"  gate(slang) = {hex(int(s,2)) if 'x' not in s else s}")
if ok: print("no output diff at this time step (check other t or sequential state)")
