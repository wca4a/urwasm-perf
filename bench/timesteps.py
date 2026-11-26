#!/usr/bin/env python3
"""timesteps.py N MODE...: wall time per call of `+steps %notes N %gent MODE` (after a warm-up run)."""
import subprocess, sys, time, os
R=os.path.expanduser('~/Projects/urwasm-perf')
def run(n, mode):
    t=time.time(); out=subprocess.run([R+'/bench/lens.sh','d',f"+steps %notes {n:,}".replace(',','.')+f" %gent %{mode}"],capture_output=True,text=True).stdout
    return time.time()-t, out.strip()[:50]
n=int(sys.argv[1])
for mode in sys.argv[2:]:
    run(50, mode); a,_=run(200, mode); b,o=run(200+n, mode)
    print(f"{mode:4s} {(b-a)/n*1000:7.3f} ms per call   {o}")
