import json, sys, re
sys.path.insert(0, "/data/workspace/climb-ontario/priv/geo")
from geocode import geocode_many, count_calls
fsas = json.load(open("raw/fsa_parsed.json"))["in_use"]
queries = [f"{f}, Ontario, Canada" for f in fsas]
results = geocode_many(queries, workers=4)
out, failed, rejected = {}, [], []
for f, (data, _) in zip(fsas, results):
    res = data.get("results") or []
    if not res: failed.append(f); continue
    r = next((r for r in res if {"postal_code_prefix", "postal_code"} & set(r.get("types", []))), None)
    if r is None: rejected.append((f, res[0].get("types"), res[0].get("address"))); continue
    addr = r["address"]
    # address like "Aurora, ON L4G, Canada" or "L4G, Aurora, ON, Canada" -> locality
    parts = [p.strip() for p in addr.split(",")]
    name = None
    for p in parts:
        p2 = re.sub(r"\b[KLMNP]\d[A-Z]\b", "", p).replace(" ON", "").strip()
        if p2 and p2 not in ("Canada", "ON", "Ontario") and not re.fullmatch(r"[KLMNP]\d[A-Z]", p2):
            name = p2; break
    if not (-90 < r["location"]["latitude"] < 90): failed.append(f); continue
    out[f] = {"lat": r["location"]["latitude"], "lng": r["location"]["longitude"], "name": name}
json.dump(out, open("/data/workspace/climb-ontario/priv/geo/ontario_fsa.json", "w"), indent=1, ensure_ascii=False)
print("FSAs found:", len(fsas), "geocoded ok:", len(out), "no result:", failed, "rejected types:", rejected[:20], "n_rejected:", len(rejected), "cache files:", count_calls())
import collections
print("name samples:", [(k, out[k]["name"]) for k in list(out)[:6]], "... none-names:", [k for k in out if not out[k]["name"]])
print("non-ON addresses:", [(f, r) for f, r in [(f, next(iter(x[0].get('results') or [{}])).get('address')) for f, x in zip(fsas, results)] if r and ", ON" not in r][:10])
