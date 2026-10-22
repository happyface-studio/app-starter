"""Drivable road network for the traffic simulation (run fetch_osm_streets.sh first).

  python3 ios/tools/bake_road_graph.py

Writes Resources/frankfurt_roads.json:
  origin  [lat, lon] of the local metre frame
  lanes   directed lanes between graph nodes:
            a, b   node ids (start, end)
            p      polyline in local metres [[x, y], ...], centre line of the road
            v      cruise speed m/s
            o      offset to the right of the centre line in metres
            s      signal at the end: 0 none, 1 group A, 2 group B (same grouping as the
                   traffic-light models in bake_street_furniture.py)
            w      spawn weight (busier roads get more cars)
Graph nodes are junctions, way ends and traffic-signal nodes, so a signalled lane ends at its stop line.
Needs only the standard library.
"""

import json
import math
import os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
OSM = os.path.join(HERE, "osm", "streets.json")
OUT = os.path.join(HERE, "..", "Targets", "ExploreKit", "Resources", "frankfurt_roads.json")

LAT0, LON0 = 50.112, 8.68
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))

DRIVE = {  # class: (km/h, two-way lane offset m, spawn weight)
    "motorway": (80, 4.5, 3), "motorway_link": (50, 0, 1), "trunk": (60, 4.0, 3), "trunk_link": (40, 0, 1),
    "primary": (50, 3.2, 3), "primary_link": (40, 0, 1), "secondary": (50, 2.8, 2.5), "secondary_link": (40, 0, 1),
    "tertiary": (40, 2.4, 2), "tertiary_link": (30, 0, 1), "unclassified": (30, 2.0, 1),
    "residential": (30, 2.0, 0.6), "living_street": (15, 1.6, 0.2),
}


def xy(lat, lon):
    return (round((lon - LON0) * M_LON, 1), round((lat - LAT0) * M_LAT, 1))


def heading(dx, dy):
    return math.degrees(math.atan2(dy, dx)) % 360


def main():
    elements = json.load(open(OSM))["elements"]
    signals = {e["id"] for e in elements if e["type"] == "node" and e.get("tags", {}).get("highway") == "traffic_signals"}
    ways = []
    for e in elements:
        if e["type"] != "way" or not e.get("geometry"):
            continue
        t = e.get("tags", {})
        if t.get("highway") not in DRIVE or t.get("access") in ("no", "private") or t.get("area") == "yes":
            continue
        ways.append(e)

    use = defaultdict(int)
    for w in ways:
        for n in w["nodes"]:
            use[n] += 1

    node_ids = {}

    def nid(osm_id):
        if osm_id not in node_ids:
            node_ids[osm_id] = len(node_ids)
        return node_ids[osm_id]

    lanes = []
    for w in ways:
        t = w["tags"]
        kmh, off, weight = DRIVE[t["highway"]]
        try:
            kmh = float(t.get("maxspeed", "").split()[0])
        except (ValueError, IndexError):
            pass
        oneway = t.get("oneway") in ("yes", "1", "true") or t.get("junction") == "roundabout" or t["highway"] in ("motorway",)
        reverse = t.get("oneway") == "-1"
        ids = w["nodes"]
        pts = [xy(p["lat"], p["lon"]) for p in w["geometry"]]
        cut = [0] + [i for i in range(1, len(ids) - 1) if use[ids[i]] > 1 or ids[i] in signals] + [len(ids) - 1]
        for i0, i1 in zip(cut, cut[1:]):
            seg = pts[i0:i1 + 1]
            if len(seg) < 2:
                continue
            length = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(seg, seg[1:]))
            if length < 1:
                continue
            dirs = [(False,)] if oneway else [(False,), (True,)]
            if reverse:
                dirs = [(True,)]
            for (back,) in dirs:
                p = list(reversed(seg)) if back else seg
                a, b = (ids[i1], ids[i0]) if back else (ids[i0], ids[i1])
                s = 0
                if b in signals:
                    dx, dy = p[-1][0] - p[-2][0], p[-1][1] - p[-2][1]
                    s = 1 if (heading(dx, dy) % 180) < 90 else 2
                lanes.append({
                    "a": nid(a), "b": nid(b), "p": [list(q) for q in p],
                    "v": round(kmh / 3.6, 1), "o": 0 if oneway else off, "s": s, "w": weight,
                })

    json.dump({"origin": [LAT0, LON0], "lanes": lanes}, open(OUT, "w"), separators=(",", ":"))
    print(f"{len(lanes)} lanes, {len(node_ids)} nodes, {sum(1 for l in lanes if l['s'])} signalled -> {OUT}")


if __name__ == "__main__":
    main()
