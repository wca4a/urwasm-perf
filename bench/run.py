#!/usr/bin/env python3
import subprocess, re, sys, os
ROOT=os.path.expanduser('~/Projects/urwasm-perf')
LOG=ROOT+'/urbit-output'
def run(mod, n, hint, fn, args):
    pos=os.path.getsize(LOG)
    out=subprocess.run([ROOT+'/bench/lens.sh','d',f"+bench %{mod} {n} %{hint} '{fn}' {args}"],capture_output=True,text=True).stdout.strip()
    import time; time.sleep(1.0)
    txt=open(LOG,errors='replace').read()[pos:]
    rows=[dict((k,float(v)) for k,v in re.findall(r'(\w+)=([\d.]+)',l)) for l in txt.splitlines() if l.startswith('UWT')]
    took=re.findall(r'took (\S+)',txt)
    hits=[r for r in rows if r['hit']==1][1:]
    avg=lambda k:(sum(r[k] for r in hits)/len(hits)) if hits else float('nan')
    miss=[r for r in rows if r['hit']==0]
    print(f"{mod:12s} {hint:5s} {fn:5s} n={n:<4d} took={took[-1] if took else '?':>14s} | per-call ms: total={avg('total'):8.3f} setup={avg('setup'):6.3f} copy-in={avg('copy'):8.3f} compile={avg('compile'):8.3f} run={avg('run'):9.3f} save={avg('save'):8.3f} | first={miss[0]['total'] if miss else float('nan'):.2f} | {out[:40]}")
    sys.stdout.flush()
if __name__=='__main__':
    run('p1-f0', 50, 'gent', 'nop', '~')
    run('p16-f0', 50, 'gent', 'touch', '~[1.048.572]')
    run('p256-f0', 50, 'gent', 'touch', '~[16.777.212]')
    run('p1024-f0', 50, 'gent', 'touch', '~[67.108.860]')
    run('p1024-f0', 50, 'gent', 'nop', '~')
    run('p1-f1000', 50, 'gent', 'nop', '~')
    run('p1-f10000', 50, 'gent', 'nop', '~')
    run('p1-f0', 1, 'gent', 'spin', '~[100.000.000]')
