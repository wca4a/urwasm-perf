#!/usr/bin/env python3
"""parse-app.py APP LABEL: after the ship has stopped, compare an app run (notes, sql) with Node and collect per-request times."""
import re, sys, os, json
ROOT=os.path.expanduser('~/Projects/urwasm-perf'); app,lab=sys.argv[1:3]
ref=json.load(open(ROOT+f'/bench/{app}-ref.json'))
out=open(f'{ROOT}/bench/{app}-out.{lab}.txt').read().replace('\\n','').replace('\n','')
got=[(int(a.replace('.','')),int(b.replace('.',''))) for a,b in re.findall(r'\[([\d.]+) ([\d.]+)\]',out)]
def ms(s):
    u,v=s.split('/'); assert u in ('µs','ms','s'), s; return int(v.replace('.',''))/1000  # digits are always down to microseconds
took=[ms(x) for x in re.findall(r'took (\S+)',open(ROOT+'/urbit-output',errors='replace').read())][-len(ref):]
bad=[i for i,(g,r) in enumerate(zip(got,ref)) if g!=(r[0],int(r[1]))]
print(f"{lab}: {len(got)} answers from the ship, {len(ref)} from Node, {len(bad)} different" + (f" first at request {bad[0]+1}" if bad else ""))
ops={}
for (n,h,nms,op,*_),t in zip(ref,took): ops.setdefault(op,[]).append((t,nms,n))
rows=[]
for op,v in ops.items():
    v2=sorted(t for t,_,_ in v)
    rows.append({'op':op,'n':len(v),'ship':sum(t for t,_,_ in v)/len(v),'med':v2[len(v2)//2],'max':v2[-1],'node':sum(m for _,m,_ in v)/len(v),'reply':sum(n for _,_,n in v)//len(v)})
    print(f"{op:22s} x{len(v):4d}  ship avg {rows[-1]['ship']:8.3f} ms  median {rows[-1]['med']:8.3f}  max {rows[-1]['max']:8.3f}   node avg {rows[-1]['node']:7.4f} ms")
print(f"all {len(took)} requests: {sum(took):.0f} ms on the ship, {sum(r[2] for r in ref):.0f} ms in Node")
json.dump({'rows':rows,'took':took,'different':len(bad)},open(f'{ROOT}/bench/{app}-times.{lab}.json','w'))
