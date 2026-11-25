#!/usr/bin/env python3
"""parse-rust.py LABEL: after the ship has stopped (log flushed), cut the rustmod run out of urbit-output."""
import re, sys, os, json
sys.path.insert(0, os.path.dirname(__file__)); import runrust
ROOT=os.path.expanduser('~/Projects/urwasm-perf')
steps=runrust.SEQS['rustmod']; need=sum(n for _,n,_ in steps)
rows=[dict((k,float(v)) for k,v in re.findall(r'(\w+)=([\d.]+)',l)) for l in open(ROOT+'/urbit-output',errors='replace').read().replace('\r','\n').splitlines() if 'UWT' in l]
first=next(i for i,r in enumerate(rows) if r['hit']==0); rows=rows[first:first+need]; assert len(rows)==need
out=[]; k=0
for j,(f,n,a) in enumerate(steps):
    rs=rows[k:k+n]; k+=n
    if j==0: rs=rs[1:]
    av=lambda key:sum(r[key] for r in rs)/len(rs)
    arg='' if a==[] else ('i' if a=='i' else ','.join(map(str,a)))
    out.append({'step':f'{f}({arg})','calls':n,'total':av('total'),'run':av('run'),'compile':av('compile'),'copy':av('copy'),'save':av('save'),'setup':av('setup')})
    print(f"{out[-1]['step']:14s} x{n:<3d} total={av('total'):9.3f} run={av('run'):9.3f} overhead={av('total')-av('run'):7.3f} (setup={av('setup'):.3f} copy={av('copy'):.3f} compile={av('compile'):.3f} save={av('save'):.3f})")
json.dump(out,open(f'{ROOT}/bench/rust-times.{sys.argv[1]}.json','w'))
