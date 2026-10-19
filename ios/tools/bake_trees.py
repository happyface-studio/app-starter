import json, math, random

random.seed(4)
trees = json.load(open("trees.json"))["elements"]
green = json.load(open("green.json"))["elements"]

pts = [(e["lat"], e["lon"]) for e in trees if e["type"] == "node"]

def pip(lat, lon, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        yi, xi = poly[i]; yj, xj = poly[j]
        if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi:
            inside = not inside
        j = i
    return inside

M_LAT = 1 / 111320.0
M_LON = 1 / (111320.0 * math.cos(math.radians(50.11)))
spacing = 16.0
park_pts = []
for e in green:
    g = e.get("geometry")
    if not g or len(g) < 4:
        continue
    poly = [(p["lat"], p["lon"]) for p in g]
    tags = e.get("tags", {})
    dense = tags.get("landuse") == "forest" or tags.get("natural") == "wood"
    sp = spacing * (0.7 if dense else 1.0)
    lats = [p[0] for p in poly]; lons = [p[1] for p in poly]
    lat = min(lats)
    while lat < max(lats):
        lon = min(lons)
        while lon < max(lons):
            jl = lat + random.uniform(-0.4, 0.4) * sp * M_LAT
            jo = lon + random.uniform(-0.4, 0.4) * sp * M_LON
            if pip(jl, jo, poly) and random.random() < (0.85 if dense else 0.55):
                park_pts.append((jl, jo))
            lon += sp * M_LON
        lat += sp * M_LAT

# grid-dedupe so mapped trees and sampled park trees don't stack
seen = set()
out = []
for lat, lon in pts + park_pts:
    key = (round(lat / (5 * M_LAT)), round(lon / (5 * M_LON)))
    if key in seen:
        continue
    seen.add(key)
    m = random.choices(["tree_a", "tree_b", "tree_c", "bush_a"], [4, 3, 3, 1])[0]
    out.append({"type": "Feature",
                "geometry": {"type": "Point", "coordinates": [round(lon, 6), round(lat, 6)]},
                "properties": {"m": m, "s": round(random.uniform(0.8, 1.3), 2), "r": random.randint(0, 359)}})

json.dump({"type": "FeatureCollection", "features": out}, open("frankfurt_trees.geojson", "w"), separators=(",", ":"))
print("mapped", len(pts), "park", len(park_pts), "total", len(out))
