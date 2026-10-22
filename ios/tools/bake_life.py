"""Paths for the map's living layers (run fetch_osm_life.sh first).

  python3 ios/tools/bake_life.py

Writes, in the same lane format as bake_road_graph.py (a, b, p, v, o, s, w):
  Resources/frankfurt_walks.json   footpaths, pedestrian streets, park paths (both directions)
  Resources/frankfurt_trams.json   tram tracks; s=1 marks a lane ending at a tram stop
  Resources/frankfurt_river.json   the Main's centre line, both directions, for boats and ducks
  Resources/frankfurt_fountains.geojson   fountain points (sparkle layer)
Needs only the standard library.
"""

import json
import math
import os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "..", "Targets", "ExploreKit", "Resources")
LAT0, LON0 = 50.112, 8.68
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))


def xy(lat, lon):
    return (round((lon - LON0) * M_LON, 1), round((lat - LAT0) * M_LAT, 1))


def build(ways, speed, weight_of=lambda t: 1.0, oneway_of=lambda t: False, stops=frozenset()):
    use = defaultdict(int)
    for w in ways:
        for n in w["nodes"]:
            use[n] += 1
    ids = {}

    def nid(o):
        return ids.setdefault(o, len(ids))

    lanes = []
    for w in ways:
        t = w.get("tags", {})
        nodes = w["nodes"]
        pts = [xy(p["lat"], p["lon"]) for p in w["geometry"]]
        cut = [0] + [i for i in range(1, len(nodes) - 1) if use[nodes[i]] > 1 or nodes[i] in stops] + [len(nodes) - 1]
        for i0, i1 in zip(cut, cut[1:]):
            seg = pts[i0:i1 + 1]
            if len(seg) < 2 or sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(seg, seg[1:])) < 1:
                continue
            for back in ([False] if oneway_of(t) else [False, True]):
                p = list(reversed(seg)) if back else seg
                a, b = (nodes[i1], nodes[i0]) if back else (nodes[i0], nodes[i1])
                lanes.append({"a": nid(a), "b": nid(b), "p": [list(q) for q in p], "v": speed,
                              "o": 0, "s": 1 if b in stops else 0, "w": weight_of(t)})
    return lanes, len(ids)


def save(name, lanes):
    path = os.path.join(RES, name)
    json.dump({"origin": [LAT0, LON0], "lanes": lanes}, open(path, "w"), separators=(",", ":"))
    return path


def main():
    el = json.load(open(os.path.join(HERE, "osm", "life.json")))["elements"]
    ways = [e for e in el if e["type"] == "way" and e.get("geometry")]
    nodes = [e for e in el if e["type"] == "node"]

    walks = [w for w in ways if w.get("tags", {}).get("highway") in ("footway", "pedestrian", "path", "steps", "living_street")
             and w["tags"].get("access") not in ("no", "private")]
    busy = {"pedestrian": 3, "living_street": 1.5, "footway": 1, "steps": 0.4, "path": 0.6}
    lanes, n = build(walks, 1.3, weight_of=lambda t: busy.get(t.get("highway"), 1) * (1.6 if t.get("footway") == "sidewalk" else 1))
    print("walks", len(lanes), "lanes", n, "nodes ->", save("frankfurt_walks.json", lanes))

    trams = [w for w in ways if w.get("tags", {}).get("railway") == "tram" and w["tags"].get("service") not in ("yard", "siding")]
    stop_ids = {e["id"] for e in nodes if e.get("tags", {}).get("railway") == "tram_stop"
                or (e.get("tags", {}).get("public_transport") == "stop_position" and e["tags"].get("tram") == "yes")}
    lanes, n = build(trams, 9.0, oneway_of=lambda t: t.get("oneway") == "yes", stops=stop_ids)
    print("trams", len(lanes), "lanes", n, "nodes,", sum(l["s"] for l in lanes), "stop lanes ->", save("frankfurt_trams.json", lanes))

    river = [w for w in ways if w.get("tags", {}).get("waterway") == "river"]
    lanes, n = build(river, 3.2)
    print("river", len(lanes), "lanes ->", save("frankfurt_river.json", lanes))

    fountains = [{"type": "Feature", "geometry": {"type": "Point", "coordinates": [e["lon"], e["lat"]]}, "properties": {}}
                 for e in nodes if e.get("tags", {}).get("amenity") == "fountain"]
    path = os.path.join(RES, "frankfurt_fountains.geojson")
    json.dump({"type": "FeatureCollection", "features": fountains}, open(path, "w"), separators=(",", ":"))
    print("fountains", len(fountains), "->", path)


if __name__ == "__main__":
    main()
