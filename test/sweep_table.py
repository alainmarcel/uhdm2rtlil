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
        # A slang divergence is counted the way ours is.  A row where BOTH
        # netlists diverge from the RTL is a testbench artefact the miter
        # adjudicates (the uhdm column shows it as '⚠ shared div' or
        # '⚠ artefact (adjudicated)'), and a row whose RTL is inert under
        # Verilator has no oracle for either side; neither is a verdict on
        # slang.  Listing all 125 under one `read_slang` **diverge** column
        # while ours showed 12 made the two look incomparable: 34 are rows
        # where ours tracks the RTL and slang's netlist does not.
        if s.startswith('✅'): n['s_pass']+=1
        elif s.startswith('❌'): n['s_div' if (u.startswith('✅') or u.startswith('❌')) else 's_shared']+=1
        else: n['s_nc']+=1
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
 ('**fx68k**',['fx68k'],'[fx68k]('+W+'sweep-fx68k.yml)'),
 ('**Syntacore SCR1**',['scr1'],'[scr1]('+W+'sweep-scr1.yml)'),
 ('**RgGen**',['rggen'],'[rggen]('+W+'sweep-rggen.yml)'),
 ('**VeeR EH1**',['veer-eh1'],'[veer-eh1]('+W+'sweep-veer-eh1.yml)'),
 ('**TNoC**',['tnoc'],'[tnoc]('+W+'sweep-tnoc.yml)'),
 ('**VeeR EL2**',['veer-el2'],'[veer-el2]('+W+'sweep-veer-el2.yml)'),
 ('**VeeR EH2**',['veer-eh2'],'[veer-eh2]('+W+'sweep-veer-eh2.yml)'),
 ('**RSD**',['rsd'],'[rsd]('+W+'sweep-rsd.yml)'),
 ('**BlackParrot**',['black-parrot'],'[black-parrot]('+W+'sweep-black-parrot.yml)'),
 ('**OpenTitan** (upstream)',['opentitan'],'[opentitan]('+W+'sweep-opentitan.yml)'),
 ('**OpenTitan IP library** (upstream, the other 44 blocks)',['opentitan-ip'],'[ext]('+W+'sweep-ext.yml)'),
 ('**Pavona** (300 modules + 100 chip instances)',['acc','aes','csrng','edn','entropy_src','hmac','keymgr','kmac','pavona','periph','periph2','periph3','periph4','periph5','tlul','dragonfly','egret'],'[pavona]('+W+'sweep-pavona.yml)'),
 ('**Ariane CVA6** (142 modules + 138 core instantiations, the latter formal-only)',['cva6','cva6-chip'],'[cva6]('+W+'sweep-cva6.yml)'),
 ('**Ariane CVA6 flavours** (the three other sv-tests configurations: HPDcache, H-extension, RV32)',['cva6-hpdcache','cva6-hext','cva6-rv32'],'[cva6-flavours]('+W+'sweep-cva6-flavours.yml)'),
 ('**Caliptra**',['caliptra'],'[caliptra]('+W+'sweep-caliptra.yml)'),
 ('**XiangShan** (香山)',['xiangshan'],'[ext]('+W+'sweep-ext.yml)'),
 ('**XiangShan core** (香山)',['xiangshan-core-full'],'[xiangshan]('+W+'sweep-xiangshan.yml)'),
 ('**External IP** (the other 26 repos; the XiangShan library is the row above)',['axi','caliptra-ss','common_cells','cv32e40p','cve2','cvfpu','cvw','hdmi','verilog-ethernet','verilog-pcie','adams-bridge','aib-protocols','aib-phy-hardware','veerwolf','serv','litex','vexriscv','rocket-chip','biriscv','zipcpu','hazard3','nvdla','openc910','boom','gemmini','openpiton'],'[ext]('+W+'sweep-ext.yml)'),
 ('**chipsalliance/sv-tests**',['sv-tests'],'[sv-tests]('+W+'sweep-sv-tests.yml)'),
]
tot=collections.Counter(); seen=set()
hdrs=['Core','Rows','Formal proven','`read_slang` co-simulated','pass','**diverge**','artefact / no oracle','`read_uhdm` co-simulated','pass','**diverge**','artefact','Undriven']
print('| '+' | '.join(hdrs)+' |'); print('|---|'+'---:|'*(len(hdrs)-1))
def row(name,n,bold=False):
    # every co-sim block partitions the rows it ran on: ran = pass + diverge (+ artefact); Rows - ran = no co-sim
    assert n['s_pass']+n['s_div']+n['s_shared']+n['s_nc']==n['rows'], (name,'slang',dict(n))
    assert n['u_pass']+n['u_div']+n['u_adj']+n['u_nc']==n['rows'], (name,'uhdm',dict(n))
    s_ran=n['s_pass']+n['s_div']+n['s_shared']; u_ran=n['u_pass']+n['u_div']+n['u_adj']
    v=[n['rows'],n['proven'],s_ran,n['s_pass'],n['s_div'],n['s_shared'],u_ran,n['u_pass'],n['u_div'],n['u_adj'],n['undriven']]
    cells=[(f"**{x}**" if (bold or (i in (4,8) and x)) else str(x)) for i,x in enumerate(v)]
    print('| '+name+' | '+' | '.join(cells)+' |')
for name,fams,link in groups:
    n=collections.Counter()
    for f in fams:
        if f not in rep: print(f'MISSING {f}'); continue
        n.update(rep[f])
        if f not in seen: tot.update(rep[f]); seen.add(f)
    # A core whose first nightly has not finished has no report at all.  Print
    # nothing rather than a row of zeros, which reads as "swept, nothing
    # proven" -- the opposite of "not yet measured".  It joins when the nightly
    # lands, which is the same rule the README stats table has always had.
    if not n['rows'] and not any(f in rep for f in fams):
        continue
    row(name,n)
# the rows partition the reports, so every column sums to its total -- assert it
colsum=collections.Counter()
for name,fams,link in groups:
    # A family whose nightly has not finished yet has no report; it is reported
    # as MISSING above and must not break the column-sum assertion.
    for f in fams:
        if f in rep: colsum.update(rep[f])
for k in ('rows','proven','s_pass','s_div','s_shared','s_nc','u_pass','u_div','u_adj','u_nc','undriven'):
    assert colsum[k]==tot[k], (k, colsum[k], tot[k])
# Count the workflows actually MEASURED, not the ones that exist: a core
# whose first nightly is still running contributes no rows, and labelling
# the total with the larger number overstates what was measured.
# Distinct WORKFLOWS, not rows: Pavona's many families and the External-IP
# repos each share one workflow, so counting groups overstated it (17 for 12).
measured = len({link for _, fams, link in groups if any(f in rep for f in fams)})
row(f'**All sweeps** ({measured} workflows)',tot,bold=True)
print()
print('# per-report triples (Formal proven/rows, co-sim pass/comparable, opt-clean/opt-rows, differs, budget, err):')
for k in sorted(rep):
    n=rep[k]; print(f"{k:22s} formal {n['proven']}/{n['rows']}  cosim {n['u_pass']}/{n['u_pass']+n['u_div']}  opt {n['opt_clean']}/{n['opt_rows']}  differs {n['differs']} budget {n['f_budget']} err {n['f_err']} nc {n['f_nc']}  slang-div {n['s_div']} slang-shared {n['s_shared']} uhdm-div {n['u_div']} adj {n['u_adj']}")
