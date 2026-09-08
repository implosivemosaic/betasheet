import json, sqlite3, sys, re
sys.path.insert(0, "/data/workspace/climb-ontario/priv/geo")
from geocode import geocode, count_calls
con = sqlite3.connect("file:/data/workspace/dot-files/knowledge/ontario-gyms/ontario-gyms.sqlite?mode=ro", uri=True)
rows = con.execute("select id,name,street_address,city,postal_code from gyms order by id").fetchall()
out, flagged = [], []
def norm(s): return re.sub(r"[^a-z]", "", (s or "").lower())
for gid, name, addr, city, pc in rows:
    q = f"{addr}, {city}, Ontario {pc or ''}".strip()
    data, _ = geocode(q)
    res = data.get("results") or []
    if not res:
        q = f"{name}, {city}, Ontario"
        data, _ = geocode(q)
        res = data.get("results") or []
    if not res:
        out.append({"gym_id": gid, "name": name, "query": q, "lat": None, "lng": None, "location_type": None,
                    "formatted_address": None, "partial_match": None, "flags": ["no_result"]})
        flagged.append((gid, name, "no_result")); continue
    r = res[0]
    rec = {"gym_id": gid, "name": name, "query": q, "lat": r["location"]["latitude"], "lng": r["location"]["longitude"],
           "location_type": r.get("location_type"), "formatted_address": r.get("address"), "partial_match": r.get("partial_match", False)}
    flags = []
    if rec["location_type"] not in ("ROOFTOP", "RANGE_INTERPOLATED"): flags.append(f"location_type={rec['location_type']}")
    if norm(city) not in norm(rec["formatted_address"]): flags.append(f"city_mismatch(gym={city})")
    if rec["partial_match"]: flags.append("partial_match")
    if flags: rec["flags"] = flags; flagged.append((gid, name, "; ".join(flags), rec["formatted_address"]))
    out.append(rec)
json.dump(out, open("/data/workspace/climb-ontario/priv/geo/gyms.json", "w"), indent=2, ensure_ascii=False)
print("gyms:", len(out), "flagged:", len(flagged), "cache files:", count_calls())
for f in flagged: print("  FLAG", f)
