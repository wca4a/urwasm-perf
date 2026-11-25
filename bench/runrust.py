#!/usr/bin/env python3
"""Run the same call sequence in Node (reference) and on the ship; compare answers and time."""
import subprocess, re, sys, os, json, time
ROOT=os.path.expanduser('~/Projects/urwasm-perf'); LOG=ROOT+'/urbit-output'
SEQS={
 'rustmod': [('tick',50,[]),('put',50,'i'),('get',50,'i'),('fill',1,[20000]),('tick',50,[]),
             ('put',50,'i'),('scan',5,[]),('sort',1,[1000000]),('hash',1,[200000]),
             ('grow',1,[4096]),('tick',50,[]),('grow',1,[16384]),('tick',50,[])],
 'callall': [('nop',20,[]),('all',1,[1]),('all',20,[5]),('nop',20,[])],
}
def ud(n):
    s=str(n); return '.'.join([s[max(0,i-3):i] for i in range(len(s),0,-3)][::-1])
def main(mod, hint='gent'):
    steps=SEQS[mod]
    ref=json.loads(subprocess.run(['node',ROOT+'/bench/node-steps.mjs',f'{ROOT}/bench/{mod}.wasm',json.dumps(steps)],capture_output=True,text=True).stdout)
    hoon='~['+' '.join("['%s' %s %s]"%(f,ud(n),'~[%i]' if a=='i' else ('~' if not a else '~['+' '.join(ud(x) for x in a)+']')) for f,n,a in steps)+']'
    pos=os.path.getsize(LOG); t0=time.time()
    out=subprocess.run([ROOT+'/bench/lens.sh','d',f"+rust %{mod} %{hint} {hoon}"],capture_output=True,text=True).stdout.strip()
    wall=time.time()-t0; need=sum(n for _,n,_ in steps)
    # the ship's log is block-buffered: push 200 cheap calls through to flush ours out
    subprocess.run([ROOT+'/bench/lens.sh','d',"+bench %p1-f0 200 %gent 'nop' ~"],capture_output=True)
    time.sleep(1.5)
    txt=open(LOG,errors='replace').read()[pos:]
    rows=[dict((k,float(v)) for k,v in re.findall(r'(\w+)=([\d.]+)',l)) for l in txt.replace('\r','\n').splitlines() if 'UWT' in l]
    first=next((i for i,r in enumerate(rows) if r['hit']==0),0)
    rows=rows[first:first+need]
    got=[int(x.replace('.','')) for x in re.findall(r"\[0 \[[\d.]+ ([\d.]+) 0\] 0\]",out)]
    print(f"== {mod} ({hint})  ship wall time {wall:.1f}s, {len(rows)} timer lines, redo={sum(int(r.get('redo',0)) for r in rows)}")
    if len(got)!=len(steps): print('RAW OUTPUT:',out[:600])
    k=0; ok=True
    print(f"{'step':14s} {'calls':>5s} {'node ms':>9s} {'ship ms':>9s} {'(run':>9s} {'other)':>8s}  answer")
    for j,(f,n,a) in enumerate(steps):
        rs=rows[k:k+n]; k+=n
        if j==0: rs=rs[1:]
        av=lambda key:sum(r[key] for r in rs)/len(rs) if rs else float('nan')
        g=got[j] if j<len(got) else None; same=(g==ref[j][1]); ok&=same
        arg='' if a==[] else ('i' if a=='i' else ','.join(map(str,a)))
        print(f"{f+'('+arg+')':14s} {n:5d} {ref[j][2]:9.3f} {av('total'):9.3f} {av('run'):9.3f} {av('total')-av('run'):8.3f}  {'same' if same else 'DIFFERENT ship=%s node=%s'%(g,ref[j][1])}")
    print('ALL ANSWERS MATCH NODE' if ok else 'MISMATCH')
if __name__=='__main__': main(*sys.argv[1:])
