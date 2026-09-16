#!/usr/bin/env python3
"""eda_srcs.py <eda.yml> <outdir>: write srcs.txt (SV/Verilog sources, in order)
and incs.txt (include dirs) from a fusesoc --no-export EDA description."""
import sys, os, yaml
eda = yaml.safe_load(open(sys.argv[1]))
base = os.path.dirname(os.path.abspath(sys.argv[1]))
srcs, incs = [], []
for f in eda['files']:
    ft = f.get('file_type', '')
    if not (ft.startswith('systemVerilogSource') or ft.startswith('verilogSource')):
        continue
    p = os.path.normpath(os.path.join(base, f['name']))
    if f.get('is_include_file'):
        d = os.path.dirname(p)
        if f.get('include_path'):
            d = os.path.normpath(os.path.join(base, f['include_path']))
        if d not in incs: incs.append(d)
    else:
        srcs.append(p)
out = sys.argv[2]
open(f'{out}/srcs.txt', 'w').write('\n'.join(srcs) + '\n')
open(f'{out}/incs.txt', 'w').write('\n'.join(incs) + '\n')
print(len(srcs), 'sources', len(incs), 'include dirs')
