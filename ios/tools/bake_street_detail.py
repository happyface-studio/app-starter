"""Shopfronts, café tables, benches, bike parking and parked cars for the map, from OSM.

  zsh ios/tools/fetch_osm_detail.sh          # osm/detail.json (shops, cafés, benches, bikes)
  python3 ios/tools/bake_street_detail.py    # needs osm/streets.json, buildings.json, life.json too

Writes Resources/frankfurt_detail.geojson: points with
  kind  "shop" | "cafe" | "bench" | "bikes" | "dock" | "parked"
  m     model id (awning colour for shops, car colour for parked cars)
  r     model-rotation [0, 0, deg] turning the model's +X out to the street (shops, cafés, benches)
        or along the kerb (bikes, parked cars)
  s     1 for shops a Spots place sits in (the app may highlight these)

Shops: each shop or café is pinned to the nearest façade of its building, facing out.
Parked cars: rows along residential and tertiary streets, half up on the kerb as in Frankfurt,
kept clear of junctions, tram tracks, lamps and signals.
"""

import json
import math
import os
import random
from collections import defaultdict

from bake_street_furniture import Grid, heading, inside_building, latlon, load_buildings, xy

HERE = os.path.dirname(os.path.abspath(__file__))
OSM = os.path.join(HERE, "osm")
RES = os.path.join(HERE, "..", "Targets", "ExploreKit", "Resources")
OUT = os.path.join(RES, "frankfurt_detail.geojson")

# Half the carriageway width as Standard draws it around zoom 17 (it isn't to scale), in metres.
DRAWN_HALF = {"residential": 2.5, "unclassified": 2.5, "living_street": 2.3, "tertiary": 3.3,
              "secondary": 3.3, "primary": 3.6, "trunk": 3.9}
PARK_ON = {"residential", "unclassified", "tertiary"}
PARK_STEP = 5.6
CAR_MODELS = ["car_white"] * 3 + ["car_black"] * 3 + ["car_blue"] * 2 + ["car_red", "car_green", "car_yellow"]

AWNING = {
    "cafe": "awning_red", "ice_cream": "awning_red", "bakery": "awning_red", "pastry": "awning_red",
    "restaurant": "awning_green", "biergarten": "awning_green", "greengrocer": "awning_green", "florist": "awning_green",
    "bar": "awning_navy", "pub": "awning_navy", "bank": "awning_navy", "pharmacy": "awning_green",
}
OUTDOOR = {"cafe", "ice_cream", "restaurant", "biergarten", "bar", "pub"}

random.seed(11)


def load_edges():
    """Building outline edges in a 30 m grid, plus the polygons for inside tests."""
    edges = Grid(30)
    data = json.load(open(os.path.join(OSM, "buildings.json")))["elements"]
    for e in data:
        g = e.get("geometry")
        if not g or len(g) < 4:
            continue
        pts = [xy(p["lat"], p["lon"]) for p in g]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            L = math.hypot(bx - ax, by - ay)
            if L >= 3.4:
                edges.add((ax + bx) / 2, (ay + by) / 2, (ax, ay, bx, by, L))
    return edges


def road_segments(ways):
    segs = Grid(40)
    for w in ways:
        hwy = w.get("tags", {}).get("highway", "")
        if hwy.replace("_link", "") not in DRAWN_HALF:
            continue
        g = [xy(p["lat"], p["lon"]) for p in w["geometry"]]
        for (ax, ay), (bx, by) in zip(g, g[1:]):
            segs.add((ax + bx) / 2, (ay + by) / 2, (ax, ay, bx, by, DRAWN_HALF[hwy.replace("_link", "")]))
    return segs


def nearest_segment(segs, x, y, r=30):
    best = None
    for _, _, (ax, ay, bx, by, half) in segs.near(x, y, r):
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 < 0.01:
            continue
        t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / L2))
        d = math.hypot(x - ax - t * dx, y - ay - t * dy)
        if best is None or d < best[0]:
            best = (d, dx, dy, half)
    return best


def main():
    streets = json.load(open(os.path.join(OSM, "streets.json")))["elements"]
    ways = [e for e in streets if e["type"] == "way" and e.get("geometry")]
    detail = json.load(open(os.path.join(OSM, "detail.json")))["elements"]
    life = json.load(open(os.path.join(OSM, "life.json")))["elements"]
    furniture = json.load(open(os.path.join(RES, "frankfurt_street.geojson")))["features"]

    buildings = load_buildings()
    edges = load_edges()
    segs = road_segments(ways)

    trams = Grid(30)
    for e in life:
        if e["type"] == "way" and e.get("tags", {}).get("railway") == "tram":
            g = [xy(p["lat"], p["lon"]) for p in e["geometry"]]
            for (ax, ay), (bx, by) in zip(g, g[1:]):
                n = max(1, int(math.hypot(bx - ax, by - ay) / 3))
                for i in range(n + 1):
                    trams.add(ax + (bx - ax) * i / n, ay + (by - ay) * i / n)

    taken = Grid(10)
    for f in furniture:
        lon, lat = f["geometry"]["coordinates"]
        taken.add(*xy(lat, lon), "furniture")

    def busy(x, y, r):
        return any(True for _ in taken.near(x, y, r))

    features = []

    def emit(x, y, kind, rot, **props):
        lat, lon = latlon(x, y)
        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [round(lon, 7), round(lat, 7)]},
            "properties": {"kind": kind, "r": [0, 0, round(-rot, 1)], **props},
        })
        taken.add(x, y, kind)

    counts = defaultdict(int)

    # --- shopfronts and café tables
    shops = []
    for e in detail:
        t = e.get("tags", {})
        if "shop" not in t and t.get("amenity") not in AWNING and t.get("amenity") not in OUTDOOR:
            continue
        lat, lon = (e["lat"], e["lon"]) if "lat" in e else (e["center"]["lat"], e["center"]["lon"])
        key = t.get("amenity") or t.get("shop")
        shops.append((xy(lat, lon), key))
    for (x, y), key in shops:
        best = None
        for _, _, (ax, ay, bx, by, L) in edges.near(x, y, 18):
            dx, dy = bx - ax, by - ay
            t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / (L * L)))
            d = math.hypot(x - ax - t * dx, y - ay - t * dy)
            if best is None or d < best[0]:
                best = (d, ax, ay, dx / L, dy / L, L, t * L)
        if best is None:
            continue
        _, ax, ay, ux, uy, L, s = best
        nx, ny = uy, -ux
        mx, my = ax + ux * L / 2, ay + uy * L / 2
        if inside_building(buildings, mx + nx * 0.6, my + ny * 0.6, pad=0):
            nx, ny = -nx, -ny
        placed = None
        for shift in (0, 3.4, -3.4, 6.8, -6.8):
            ss = s + shift
            if not 1.7 <= ss <= L - 1.7:
                continue
            px, py = ax + ux * ss + nx * 0.03, ay + uy * ss + ny * 0.03
            if inside_building(buildings, px + nx * 2.5, py + ny * 2.5, pad=0):
                break                                   # courtyard or party wall, not a street front
            if busy(px, py, 3.2):
                continue
            placed = (px, py)
            break
        if not placed:
            continue
        px, py = placed
        rot = heading(nx, ny)
        emit(px, py, "shop", rot, m=AWNING.get(key, random.choice(["awning_mustard", "awning_navy", "awning_red", "awning_green"])))
        counts["shop"] += 1
        if key in OUTDOOR:
            cx, cy = px + nx * 2.6, py + ny * 2.6
            road = nearest_segment(segs, cx, cy)
            clear = road is None or road[0] > road[3] + 1.3
            if clear and not inside_building(buildings, cx, cy, pad=0.8) and not busy(cx, cy, 2.4):
                emit(cx, cy, "cafe", rot + random.uniform(-8, 8))
                counts["cafe"] += 1

    # --- benches and bike parking
    for e in detail:
        t = e.get("tags", {})
        a = t.get("amenity")
        if e["type"] != "node" or a not in ("bench", "bicycle_parking", "bicycle_rental"):
            continue
        x, y = xy(e["lat"], e["lon"])
        if inside_building(buildings, x, y) or busy(x, y, 2.0):
            continue
        road = nearest_segment(segs, x, y, 25)
        if road and road[0] < road[3] + 0.8:
            continue                                    # would sit on the drawn carriageway
        along = heading(road[1], road[2]) if road else random.uniform(0, 360)
        if a == "bench":
            try:
                rot = 90 - float(t.get("direction", "x"))  # compass bearing -> our counter-clockwise from east
            except ValueError:
                rot = along + 90 if road else along
            emit(x, y, "bench", rot)
        else:
            emit(x, y, "dock" if a == "bicycle_rental" else "bikes", along)
        counts[a] += 1

    # --- parked cars
    degree = defaultdict(int)
    for w in ways:
        for nid in w.get("nodes", []):
            degree[nid] += 1
    for w in ways:
        tags = w.get("tags", {})
        hwy = tags.get("highway")
        if hwy not in PARK_ON or tags.get("tunnel") not in (None, "no") or tags.get("bridge") not in (None, "no"):
            continue
        if tags.get("parking:both") == "no" or tags.get("access") in ("no", "private"):
            continue
        ids, geom = w.get("nodes", []), [xy(p["lat"], p["lon"]) for p in w["geometry"]]
        junctions = [geom[k] for k, nid in enumerate(ids) if degree[nid] > 1 or k in (0, len(ids) - 1)]
        off = DRAWN_HALF[hwy] + 0.55
        for side in (1, -1):
            parked = random.random() < 0.4
            for (ax, ay), (bx, by) in zip(geom, geom[1:]):
                seg = math.hypot(bx - ax, by - ay)
                if seg < PARK_STEP:
                    continue
                ux, uy = (bx - ax) / seg, (by - ay) / seg
                rx, ry = uy * side, -ux * side
                t = PARK_STEP / 2
                while t < seg - PARK_STEP / 2:
                    parked = random.random() < (0.8 if parked else 0.3)
                    cx, cy = ax + ux * t, ay + uy * t
                    t += PARK_STEP
                    if not parked:
                        continue
                    if any(math.hypot(cx - jx, cy - jy) < 11 for jx, jy in junctions):
                        continue
                    x, y = cx + rx * off, cy + ry * off
                    if any(True for _ in trams.near(cx, cy, 5)) or busy(x, y, 2.6) or inside_building(buildings, x, y, pad=0.9):
                        continue
                    # Facing the direction of travel on that side (they drive on the right).
                    rot = heading(ux * side, uy * side) + random.uniform(-2, 2)
                    emit(x, y, "parked", rot, m=random.choice(CAR_MODELS))
                    counts["parked"] += 1

    json.dump({"type": "FeatureCollection", "features": features}, open(OUT, "w"), separators=(",", ":"))
    print(dict(counts), "->", OUT)


if __name__ == "__main__":
    main()
