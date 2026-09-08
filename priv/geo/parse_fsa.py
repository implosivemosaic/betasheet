import re, json
fsas = {}
for L in "KLMNP":
    txt = open(f"raw/fsa_{L}.txt").read()
    toks = [t.strip() for t in re.split(r"[\t\n]", txt)]
    toks = [t for t in toks if t]
    pat = re.compile(rf"^{L}\d[A-Z]$")
    for i, t in enumerate(toks):
        if not pat.match(t): continue
        desc = toks[i+1] if i+1 < len(toks) and not pat.match(toks[i+1]) else ""
        unused = bool(re.match(r"(not assigned|not in use|unassigned|reserved)", desc, re.I))
        prev = fsas.get(t)
        if prev is None or (prev["unused"] and not unused):
            fsas[t] = {"desc": desc, "unused": unused}
inuse = sorted(k for k, v in fsas.items() if not v["unused"])
unused = sorted(k for k, v in fsas.items() if v["unused"])
json.dump({"in_use": inuse, "unused": unused, "all": fsas}, open("raw/fsa_parsed.json", "w"), indent=1)
from collections import Counter
print("in use:", len(inuse), Counter(k[0] for k in inuse)); print("unused:", len(unused))
print("sample:", [(k, fsas[k]["desc"][:30]) for k in inuse[:8]])
print("empty-desc in-use:", [k for k in inuse if not fsas[k]["desc"]])
