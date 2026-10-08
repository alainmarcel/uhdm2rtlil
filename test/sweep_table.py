#!/usr/bin/env python3
"""README tables from the downloaded nightly sweep reports.

Usage: gh run download <run> -p "*-sweep-report" -D build/sweeps/<run>   (one per sweep workflow)
       python3 test/sweep_table.py [build/sweeps]
Prints the per-core co-sim table (slang vs uhdm pass/diverge, formal, undriven) and per-report triples."""
import re, glob, os, collections
import sys
root = sys.argv[1] if len(sys.argv) > 1 else 'build/sweeps'
def count(f):
    hdr=None; n=collections.Counter()
    for line in open(f):
        if line.startswith('| slang co-sim'):
            # Columns by NAME: sv-tests carries two extra ones (driver
            # conflicts, unresolved reads), so a fixed position read its
            # opt-check column as the co-sim column (526 "passing" co-sims).
            names=[x.strip() for x in line.strip().strip('|').split('|')]
            hdr={k:i for i,k in enumerate(names)}
            continue
        if hdr is None or not line.startswith('| ') or line.startswith('|---'): continue
        c=[x.strip() for x in line.strip().strip('|').split('|')]
        if len(c)<len(hdr): continue
        s=c[hdr['slang co-sim vs RTL']]; mod=c[hdr['module']]; formal=c[hdr['formal vs slang']]
        opt=c[hdr['opt check (undriven)']]; u=c[hdr['co-sim vs RTL']]
        n['rows']+=1
        n['s_pass' if s.startswith('✅') else 's_div' if s.startswith('❌') else 's_nc']+=1
        n['u_pass' if u.startswith('✅') else 'u_div' if u.startswith('❌') else 'u_adj' if u.startswith('⚠') else 'u_nc']+=1
        if '✅ equivalent' in formal: n['proven']+=1
        elif 'differs' in formal: n['differs']+=1
        elif formal=='error' or formal.startswith('❌'): n['f_err']+=1
        elif re.search(r'timeout|budget|memory', formal): n['f_budget']+=1
        else: n['f_nc']+=1
        if '0 undriven' in opt: n['opt_clean']+=1
        m=re.search(r'(\d+) undriven',opt)
        if m: n['undriven']+=int(m.group(1))
        if opt.startswith('✅') or opt.startswith('❌') or 'undriven' in opt: n['opt_rows']+=1
    return n
rep={}
for f in glob.glob(os.path.join(root,'*','*-sweep-report','*.md')):
    rep[os.path.basename(f).replace('-sweep.md','')]=count(f)
W='https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/'
# One row per row of README's "Supported Core IP" table, same names, same order.
groups=[
 ('**Ibex**',['ibex'],'[ibex]('+W+'sweep-ibex.yml)'),
 ('**rp32 (R5P)**',['rp32'],'[rp32]('+W+'sweep-rp32.yml)'),
 ('**Syntacore SCR1**',['scr1'],'[scr1]('+W+'sweep-scr1.yml)'),
 ('**VeeR EH1**',['veer-eh1'],'[veer-eh1]('+W+'sweep-veer-eh1.yml)'),
 ('**RSD**',['rsd'],'[rsd]('+W+'sweep-rsd.yml)'),
 ('**OpenTitan** (upstream)',['opentitan'],'[opentitan]('+W+'sweep-opentitan.yml)'),
 ('**Pavona** (300 modules + 100 chip instances)',['acc','aes','csrng','edn','entropy_src','hmac','keymgr','kmac','pavona','periph','periph2','periph3','periph4','periph5','tlul','dragonfly','egret'],'[pavona]('+W+'sweep-pavona.yml)'),
 ('**Ariane CVA6** (142 modules + 138 core instantiations, the latter formal-only)',['cva6','cva6-chip'],'[cva6]('+W+'sweep-cva6.yml)'),
 ('**Caliptra**',['caliptra'],'[caliptra]('+W+'sweep-caliptra.yml)'),
 ('**XiangShan** (香山)',['xiangshan'],'[ext]('+W+'sweep-ext.yml)'),
 ('**XiangShan core** (香山)',['xiangshan-core-full'],'[xiangshan]('+W+'sweep-xiangshan.yml)'),
 ('**External IP** (the other 10 repos; the XiangShan library is the row above)',['axi','caliptra-ss','common_cells','cv32e40p','cve2','cvfpu','cvw','hdmi','verilog-ethernet','verilog-pcie'],'[ext]('+W+'sweep-ext.yml)'),
 ('**chipsalliance/sv-tests**',['sv-tests'],'[sv-tests]('+W+'sweep-sv-tests.yml)'),
]
tot=collections.Counter(); seen=set()
hdrs=['Core','Rows','Formal proven','`read_slang` co-simulated','pass','**diverge**','`read_uhdm` co-simulated','pass','**diverge**','artefact','Undriven']
print('| '+' | '.join(hdrs)+' |'); print('|---|'+'---:|'*(len(hdrs)-1))
def row(name,n,bold=False):
    # every co-sim block partitions the rows it ran on: ran = pass + diverge (+ artefact); Rows - ran = no co-sim
    assert n['s_pass']+n['s_div']+n['s_nc']==n['rows'], (name,'slang',dict(n))
    assert n['u_pass']+n['u_div']+n['u_adj']+n['u_nc']==n['rows'], (name,'uhdm',dict(n))
    s_ran=n['s_pass']+n['s_div']; u_ran=n['u_pass']+n['u_div']+n['u_adj']
    v=[n['rows'],n['proven'],s_ran,n['s_pass'],n['s_div'],u_ran,n['u_pass'],n['u_div'],n['u_adj'],n['undriven']]
    cells=[(f"**{x}**" if (bold or (i in (4,7) and x)) else str(x)) for i,x in enumerate(v)]
    print('| '+name+' | '+' | '.join(cells)+' |')
for name,fams,link in groups:
    n=collections.Counter()
    for f in fams:
        if f not in rep: print(f'MISSING {f}'); continue
        n.update(rep[f])
        if f not in seen: tot.update(rep[f]); seen.add(f)
    row(name,n)
# the rows partition the reports, so every column sums to its total -- assert it
colsum=collections.Counter()
for name,fams,link in groups:
    for f in fams: colsum.update(rep[f])
for k in ('rows','proven','s_pass','s_div','s_nc','u_pass','u_div','u_adj','u_nc','undriven'):
    assert colsum[k]==tot[k], (k, colsum[k], tot[k])
row('**All sweeps** (12 workflows)',tot,bold=True)
print()
print('# per-report triples (Formal proven/rows, co-sim pass/comparable, opt-clean/opt-rows, differs, budget, err):')
for k in sorted(rep):
    n=rep[k]; print(f"{k:22s} formal {n['proven']}/{n['rows']}  cosim {n['u_pass']}/{n['u_pass']+n['u_div']}  opt {n['opt_clean']}/{n['opt_rows']}  differs {n['differs']} budget {n['f_budget']} err {n['f_err']} nc {n['f_nc']}  slang-div {n['s_div']} uhdm-div {n['u_div']} adj {n['u_adj']}")
