"""Cached wrapper around `lego maps geocode`. Every result is written to cache/<key>.json before returning."""
import hashlib, json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")
os.makedirs(CACHE, exist_ok=True)

def _key(q):
    slug = re.sub(r"[^A-Za-z0-9]+", "_", q).strip("_")[:60]
    return f"{slug}_{hashlib.sha1(q.encode()).hexdigest()[:10]}.json"

def geocode(q):
    """Returns (data, from_cache). data is the parsed JSON from lego (or {'ok':False,'error':...})."""
    path = os.path.join(CACHE, _key(q))
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f), True
    try:
        out = subprocess.run(["lego", "maps", "geocode", q, "--json"], capture_output=True, text=True, timeout=60)
        try:
            data = json.loads(out.stdout)
        except json.JSONDecodeError:
            data = {"ok": False, "error": "bad json", "stdout": out.stdout[-500:], "stderr": out.stderr[-500:]}
    except Exception as e:
        data = {"ok": False, "error": repr(e)}
    if "error" in data and "bad json" in str(data.get("error")) and not out.stdout.strip():
        # transient CLI failure: don't cache empty output
        return data, False
    data["_query"] = q
    with open(path, "w") as f:
        json.dump(data, f)
    return data, False

def geocode_many(queries, workers=4):
    with ThreadPoolExecutor(max_workers=workers) as ex:
        return list(ex.map(geocode, queries))

def count_calls():
    return len([f for f in os.listdir(CACHE) if f.endswith(".json")])
