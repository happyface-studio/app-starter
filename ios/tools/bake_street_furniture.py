"""Street lamps and traffic lights for the map, from OSM (run fetch_osm_streets.sh first).

  python3 ios/tools/bake_street_furniture.py

Writes Resources/frankfurt_street.geojson: points with
  kind  "lamp" | "signal"
  r     model-rotation [0, 0, deg] turning the model's +X towards the road (lamps) / oncoming traffic (signals)
  lit   "red" | "green" for signals before the cycle starts
  g     signal group 1 | 2; the app turns one group green at a time (see TrafficSim)

Lamps: OSM street_lamp nodes where mapped; elsewhere one every ~30 m along the kerb, alternating sides,
skipping spots inside buildings or too close to another lamp or a signal.
Signals: one per approach to each OSM traffic_signals node, on the kerb to the right of travel.
Needs only numpy.
"""

import json
import math
import os
import random
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
OSM = os.path.join(HERE, "osm")
OUT = os.path.join(HERE, "..", "Targets", "ExploreKit", "Resources", "frankfurt_street.geojson")

LAT0 = 50.112
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))

HALF = {  # carriageway half-width in metres
    "motorway": 9, "trunk": 8, "primary": 7, "secondary": 6, "tertiary": 5,
    "unclassified": 4, "residential": 4, "living_street": 3, "pedestrian": 2.5,
}
LAMP_SPACING = 30.0
KERB = 1.3            # lamp/signal distance beyond the carriageway edge
NO_LAMPS = {"motorway", "motorway_link", "trunk_link"}

random.seed(7)


def xy(lat, lon):
    return ((lon - 8.68) * M_LON, (lat - LAT0) * M_LAT)


def latlon(x, y):
    return (LAT0 + y / M_LAT, 8.68 + x / M_LON)


def half_width(tags):
    base = HALF.get(tags.get("highway", "").replace("_link", ""), 4)
    try:
        lanes = float(tags.get("lanes", "").split(";")[0])
        base = max(base * 0.6, lanes * 3.2 / 2 + 0.3)
    except ValueError:
        pass
    return base


def heading(dx, dy):
    """Compass-style degrees, 0 = east (+X), counter-clockwise."""
    return math.degrees(math.atan2(dy, dx)) % 360


class Grid:
    def __init__(self, cell):
        self.cell, self.items = cell, defaultdict(list)

    def key(self, x, y):
        return (int(x // self.cell), int(y // self.cell))

    def add(self, x, y, v=None):
        self.items[self.key(x, y)].append((x, y, v))

    def near(self, x, y, r):
        kx, ky = self.key(x, y)
        n = int(math.ceil(r / self.cell))
        for i in range(kx - n, kx + n + 1):
            for j in range(ky - n, ky + n + 1):
                for item in self.items.get((i, j), ()):
                    if (item[0] - x) ** 2 + (item[1] - y) ** 2 <= r * r:
                        yield item


def load_buildings():
    grid = defaultdict(list)
    data = json.load(open(os.path.join(OSM, "buildings.json")))["elements"]
    for e in data:
        g = e.get("geometry")
        if not g or len(g) < 4:
            continue
        pts = [xy(p["lat"], p["lon"]) for p in g]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        bb = (min(xs), min(ys), max(xs), max(ys))
        for i in range(int(bb[0] // 50), int(bb[2] // 50) + 1):
            for j in range(int(bb[1] // 50), int(bb[3] // 50) + 1):
                grid[(i, j)].append((bb, pts))
    return grid


def inside_building(grid, x, y, pad=0.6):
    for bb, pts in grid.get((int(x // 50), int(y // 50)), ()):
        if not (bb[0] - pad <= x <= bb[2] + pad and bb[1] - pad <= y <= bb[3] + pad):
            continue
        inside, j = False, len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]; xj, yj = pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
                inside = not inside
            j = i
        if inside:
            return True
    return False


def main():
    elements = json.load(open(os.path.join(OSM, "streets.json")))["elements"]
    ways = [e for e in elements if e["type"] == "way" and e.get("geometry")]
    nodes = {e["id"]: e for e in elements if e["type"] == "node"}
    signal_ids = {i for i, e in nodes.items() if e.get("tags", {}).get("highway") == "traffic_signals"}
    buildings = load_buildings()

    features = []
    taken = Grid(20)

    def emit(x, y, kind, rot, **props):
        lat, lon = latlon(x, y)
        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [round(lon, 7), round(lat, 7)]},
            # Mapbox model-rotation turns clockwise, our headings counter-clockwise.
            "properties": {"kind": kind, "r": [0, 0, round(-rot, 1)], **props},
        })
        taken.add(x, y, kind)

    # --- signals: one per approach, on the right kerb, facing oncoming traffic
    for w in ways:
        tags = w.get("tags", {})
        if tags.get("highway") in ("pedestrian", "living_street"):
            continue
        ids, geom = w.get("nodes", []), [xy(p["lat"], p["lon"]) for p in w["geometry"]]
        oneway = tags.get("oneway") in ("yes", "1") or tags.get("junction") == "roundabout"
        hw = half_width(tags)
        for k, nid in enumerate(ids):
            if nid not in signal_ids:
                continue
            approaches = []
            if k > 0:
                approaches.append(geom[k - 1])            # travelling forwards into the node
            if k < len(ids) - 1 and not oneway:
                approaches.append(geom[k + 1])            # travelling backwards into the node
            for (px, py) in approaches:
                nx, ny = geom[k]
                dx, dy = nx - px, ny - py
                d = math.hypot(dx, dy)
                if d < 1:
                    continue
                ux, uy = dx / d, dy / d
                rx, ry = uy, -ux                          # right of travel
                back = min(3.0, d * 0.5)
                x = nx - ux * back + rx * (hw + KERB)
                y = ny - uy * back + ry * (hw + KERB)
                if any(True for _ in taken.near(x, y, 3.0)) or inside_building(buildings, x, y):
                    continue
                rot = heading(-ux, -uy)                   # lenses (+X) look back at the traffic
                group = 1 if (heading(ux, uy) % 180) < 90 else 2   # same grouping as bake_road_graph.py
                emit(x, y, "signal", rot, lit="green" if group == 1 else "red", g=group)
    n_signals = len(features)

    # road centre-line segments, for nudging mapped lamps out of the carriageway
    segs = Grid(40)
    for w in ways:
        g = [xy(p["lat"], p["lon"]) for p in w["geometry"]]
        hw = half_width(w.get("tags", {}))
        for (ax, ay), (bx, by) in zip(g, g[1:]):
            segs.add((ax + bx) / 2, (ay + by) / 2, (ax, ay, bx, by, hw))

    def onto_kerb(x, y):
        best = None
        for _, _, (ax, ay, bx, by, hw) in segs.near(x, y, 60):
            dx, dy = bx - ax, by - ay
            L2 = dx * dx + dy * dy
            if L2 < 0.01:
                continue
            t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / L2))
            px, py = ax + t * dx, ay + t * dy
            d = math.hypot(x - px, y - py)
            if d < hw + 0.5 and (best is None or d < best[0]):
                best = (d, px, py, dx, dy, hw)
        if best is None:
            return x, y
        _, px, py, dx, dy, hw = best
        L = math.hypot(dx, dy)
        nx, ny = dy / L, -dx / L
        if (x - px) * nx + (y - py) * ny < 0:
            nx, ny = -nx, -ny
        return px + nx * (hw + KERB), py + ny * (hw + KERB)

    # --- lamps mapped in OSM
    lamp_osm = 0
    for e in nodes.values():
        if e.get("tags", {}).get("highway") != "street_lamp":
            continue
        x, y = onto_kerb(*xy(e["lat"], e["lon"]))
        if any(True for _ in taken.near(x, y, 4.0)):
            continue
        emit(x, y, "lamp", random.uniform(0, 360))
        lamp_osm += 1

    # --- generated lamps along kerbs
    for w in ways:
        tags = w.get("tags", {})
        hwy = tags.get("highway", "")
        if hwy in NO_LAMPS or tags.get("tunnel") not in (None, "no") or tags.get("area") == "yes":
            continue
        geom = [xy(p["lat"], p["lon"]) for p in w["geometry"]]
        hw = half_width(tags)
        offset = hw + KERB if hwy != "pedestrian" else hw
        both = hw >= 6
        side = 1 if w["id"] % 2 else -1
        carry = random.uniform(0, LAMP_SPACING)
        for (ax, ay), (bx, by) in zip(geom, geom[1:]):
            seg = math.hypot(bx - ax, by - ay)
            if seg < 0.1:
                continue
            ux, uy = (bx - ax) / seg, (by - ay) / seg
            rx, ry = uy, -ux
            t = carry
            while t < seg:
                sides = (side, -side) if both else (side,)
                for i, sd in enumerate(sides):
                    tt = t + (LAMP_SPACING / 2 if i else 0)
                    if tt >= seg:
                        continue
                    x = ax + ux * tt + rx * offset * sd
                    y = ay + uy * tt + ry * offset * sd
                    if any(True for _ in taken.near(x, y, 14.0)) or inside_building(buildings, x, y):
                        continue
                    emit(x, y, "lamp", heading(-rx * sd, -ry * sd))
                side = -side
                t += LAMP_SPACING
            carry = t - seg

    json.dump({"type": "FeatureCollection", "features": features}, open(OUT, "w"), separators=(",", ":"))
    print(f"signals {n_signals}, osm lamps {lamp_osm}, generated lamps {len(features) - n_signals - lamp_osm} -> {OUT}")


if __name__ == "__main__":
    main()
