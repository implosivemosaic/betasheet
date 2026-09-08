import json, sys
sys.path.insert(0, "/data/workspace/climb-ontario/priv/geo")
from geocode import geocode_many, count_calls
names = json.load(open("raw/places_list.json"))
KEEP = {"locality", "sublocality", "neighborhood", "administrative_area_level_3", "political"}
def norm(n): return n.replace("–", "-").replace("—", "-")
queries = [f"{norm(n)}, Ontario, Canada" for n in names]
results = geocode_many(queries, workers=4)
seen, out, failed, rejected, non_on = {}, [], [], [], []
for n, (data, _) in zip(names, results):
    res = data.get("results") or []
    if not res: failed.append(n); continue
    r = next((r for r in res if KEEP & set(r.get("types", []))), None)
    if r is None: rejected.append((n, res[0].get("types"), res[0].get("address"))); continue
    if ", ON" not in r["address"] and "Ontario" not in r["address"]: non_on.append((n, r["address"]))
    key = norm(n).lower()
    if key in seen: continue
    seen[key] = 1
    out.append({"name": norm(n), "lat": r["location"]["latitude"], "lng": r["location"]["longitude"], "types": r.get("types", [])})
out.sort(key=lambda x: x["name"].lower())
json.dump(out, open("/data/workspace/climb-ontario/priv/geo/ontario_places.json", "w"), indent=1, ensure_ascii=False)
print("places input:", len(names), "output:", len(out), "no result:", failed, "rejected:", rejected, "non-ON:", non_on, "cache files:", count_calls())
