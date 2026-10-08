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
        if line.startswith('| slang co-sim'): hdr=1; continue
        if hdr is None or not line.startswith('| ') or line.startswith('|---'): continue
        c=[x.strip() for x in line.strip().strip('|').split('|')]
        if len(c)<5: continue
        s,mod,formal,opt,u=c[:5]; n['rows']+=1
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
groups=[
 ('Ibex',['ibex'],'[ibex](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml)'),
 ('rp32 (R5P)',['rp32'],'[rp32](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml)'),
 ('Syntacore SCR1',['scr1'],'[scr1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml)'),
 ('VeeR EH1',['veer-eh1'],'[veer-eh1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml)'),
 ('RSD',['rsd'],'[rsd](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml)'),
 ('OpenTitan OTBN',['opentitan'],'[opentitan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml)'),
 ('Pavona (modules)',['acc','aes','csrng','edn','entropy_src','hmac','keymgr','kmac','pavona','periph','periph2','periph3','periph4','periph5','tlul'],'[pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml)'),
 ('Pavona chips (instances)',['dragonfly','egret'],'[pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml)'),
 ('Ariane CVA6 (modules)',['cva6'],'[cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml)'),
 ('Ariane CVA6 (core instantiations)',['cva6-chip'],'[cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml)'),
 ('Caliptra (instances)',['caliptra'],'[caliptra](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml)'),
 ('XiangShan core',['xiangshan-core-full'],'[xiangshan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml)'),
 ('External IP (11 repos)',['axi','caliptra-ss','common_cells','cv32e40p','cve2','cvfpu','cvw','hdmi','verilog-ethernet','verilog-pcie','xiangshan'],'[ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml)'),
 ('chipsalliance/sv-tests',['sv-tests'],'[sv-tests](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml)'),
]
tot=collections.Counter()
print('| Core | Rows | Formal proven | `read_slang` co-sim: pass / **diverge** | `read_uhdm` co-sim: pass / **diverge** (adjudicated) | Undriven | Sweep |')
print('|---|---:|---:|---:|---:|---:|---|')
for name,fams,link in groups:
    n=collections.Counter()
    for f in fams:
        if f not in rep: print(f'MISSING {f}'); continue
        n.update(rep[f])
    tot.update(n)
    sdiv=f"**{n['s_div']}**" if n['s_div'] else '0'
    udiv=f"**{n['u_div']}**" if n['u_div'] else '0'
    print(f"| {name} | {n['rows']} | {n['proven']} | {n['s_pass']} / {sdiv} | {n['u_pass']} / {udiv} ({n['u_adj']}) | {n['undriven']} | {link} |")
n=tot
print(f"| **All sweeps** | **{n['rows']}** | **{n['proven']}** | **{n['s_pass']} / {n['s_div']}** | **{n['u_pass']} / {n['u_div']}** ({n['u_adj']}) | {n['undriven']} | 12 workflows |")
print()
print('# per-report triples (Formal proven/rows, co-sim pass/comparable, opt-clean/opt-rows, differs, budget, err):')
for k in sorted(rep):
    n=rep[k]; print(f"{k:22s} formal {n['proven']}/{n['rows']}  cosim {n['u_pass']}/{n['u_pass']+n['u_div']}  opt {n['opt_clean']}/{n['opt_rows']}  differs {n['differs']} budget {n['f_budget']} err {n['f_err']} nc {n['f_nc']}  slang-div {n['s_div']} uhdm-div {n['u_div']} adj {n['u_adj']}")
