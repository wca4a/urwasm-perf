#!/usr/bin/env python3
"""mkwork.py: write notes-work.txt, one JSON request per line, for the notes app. Deterministic."""
import json, random
R = random.Random(20261125)
WORDS = ("ship pier galaxy planet star moon kernel vane agent desk mark noun atom cell hoon nock jet arvo clay gall "
         "ames eyre behn dill jael khan lick iris azimuth bridge sponsor ticket breach rekey network packet route peer "
         "message channel group notebook gallery chat thread reply reaction invite member admin role secret public "
         "wasm module memory page function import export table stack trap compile interpret snapshot replay event log "
         "garden orchard kitchen recipe bread butter coffee tea lemon pepper salt harvest winter summer river mountain "
         "budget invoice payment ledger balance quarter revenue margin forecast customer contract renewal meeting agenda "
         "café naïve jalapeño résumé über straße 東京 привет").split()
TAGS = "work home urbit ideas todo reading recipes money travel health".split()
def sent(n=None): return " ".join(R.choice(WORDS) for _ in range(n or R.randint(6, 18))).capitalize() + "."
def para(): return " ".join(sent() for _ in range(R.randint(2, 5)))
def body(paras=None):
    out = []
    for _ in range(paras or R.randint(2, 7)):
        k = R.random()
        if k < .15: out.append("#" * R.randint(1, 3) + " " + sent(4)[:-1])
        elif k < .30: out.append("\n".join(f"- {sent(5)}" for _ in range(R.randint(2, 6))))
        elif k < .38: out.append("\n".join(f"{i+1}. **{R.choice(WORDS)}** {sent(4)}" for i in range(R.randint(2, 5))))
        elif k < .46: out.append("```hoon\n|=  [a=@ b=@]\n^-  @\n(add a (mul b %d))\n```" % R.randint(1, 999))
        elif k < .52: out.append("| name | count |\n|---|---|\n" + "\n".join(f"| {R.choice(WORDS)} | {R.randint(1,99)} |" for _ in range(R.randint(2, 5))))
        elif k < .58: out.append(f"> {sent()} See [{R.choice(WORDS)}](https://example.com/{R.choice(WORDS)}) and *{R.choice(WORDS)}* ~~{R.choice(WORDS)}~~.")
        elif k < .62: out.append("- [x] " + sent(4) + "\n- [ ] " + sent(4))
        else: out.append(para())
    return "\n\n".join(out)
def add(paras=None): return {"op": "add", "title": sent(R.randint(2, 5))[:-1], "body": body(paras), "tags": R.sample(TAGS, R.randint(0, 3))}
reqs = []; live = []; nxt = 0
def push(r):
    global nxt
    if r["op"] == "add": nxt += 1; live.append(nxt)
    reqs.append(r)
for _ in range(200): push(add())
for i in range(600):
    k = R.random()
    if k < .45: push({"op": "search", "q": " ".join(R.sample(WORDS, R.choice([1, 1, 2, 2, 3]))), **({"limit": 5} if R.random() < .3 else {})})
    elif k < .60: push({"op": "get", "id": R.choice(live)})
    elif k < .75: push({"op": "render", "id": R.choice(live)})
    elif k < .85: push({"op": "edit", "id": R.choice(live), "body": body()})
    elif k < .93: push(add())
    elif k < .96: d = R.choice(live); live.remove(d); push({"op": "delete", "id": d})
    elif k < .98: push({"op": "tags"})
    else: push({"op": "stats"})
    if i == 300:  # one long document: about 100 KB of markdown
        push(add(900)); big = nxt
        push({"op": "render", "id": big}); push({"op": "search", "q": "kernel memory"}); push({"op": "get", "id": big})
# things a real client gets wrong
reqs += ['{"op":"add","title":"broken', '{"op":"launch"}', 'not json at all', {"op": "get", "id": 999999}, {"op": "search", "q": "   "}]
reqs += [{"op": "stats"}, {"op": "export"}, {"op": "delete", "id": big}, {"op": "export"}, {"op": "stats"}]
with open("notes-work.txt", "w") as f:
    for r in reqs: f.write((r if isinstance(r, str) else json.dumps(r, ensure_ascii=False)) + "\n")
ops = {}
for r in reqs: ops[r["op"] if isinstance(r, dict) else "bad"] = ops.get(r["op"] if isinstance(r, dict) else "bad", 0) + 1
print(len(reqs), "requests", ops)
