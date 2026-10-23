"""Back gardens, courtyards and car parks for the map, from OSM.

  zsh ios/tools/fetch_osm_ground.sh      # osm/ground.json
  python3 ios/tools/bake_yards.py        # needs osm/streets.json, buildings.json; shapely

Without this, everything between streets and buildings is bare 'land' colour. Here:
  paved   residential and commercial blocks away from the street: a light paved yard
  garden  the same blocks, kept 2.6 m off the buildings (so a paved rim runs round each house),
          plus OSM gardens, allotments and grass: lawn with a hedge outline
  parking surface car parks: asphalt
  tree    a scatter of garden trees and bushes inside the gardens (model id in `m`)

The street side of each block (carriageway, pavement and a frontage strip) is cut away, so
gardens never reach the pavement, and so are pedestrian zones and squares.
Writes Resources/frankfurt_yards.geojson.
"""

import json
import math
import os
import random

from shapely.geometry import LineString, Point, Polygon, mapping
from shapely.ops import polygonize, transform, unary_union
from shapely.prepared import prep
from shapely.strtree import STRtree

HERE = os.path.dirname(os.path.abspath(__file__))
OSM = os.path.join(HERE, "osm")
RES = os.path.join(HERE, "..", "Targets", "ExploreKit", "Resources")
OUT = os.path.join(RES, "frankfurt_yards.geojson")

LAT0, LON0 = 50.112, 8.68
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))

# Street + pavement + frontage kept clear of gardens, from the centre line, in metres.
STREET_CLEAR = {"motorway": 12, "trunk": 10, "primary": 9, "secondary": 8.5, "tertiary": 8.5,
                "unclassified": 7, "residential": 7, "living_street": 6, "pedestrian": 5, "service": 4}

random.seed(21)


def xy(lat, lon):
    return ((lon - LON0) * M_LON, (lat - LAT0) * M_LAT)


def to_lonlat(x, y, z=None):
    return (LON0 + x / M_LON, LAT0 + y / M_LAT)


def way_polygon(geom):
    pts = [xy(p["lat"], p["lon"]) for p in geom]
    if len(pts) < 4 or pts[0] != pts[-1]:
        return None
    poly = Polygon(pts)
    return poly if poly.is_valid else poly.buffer(0)


def relation_polygon(e):
    outer, inner = [], []
    for m in e.get("members", []):
        if m.get("type") != "way" or not m.get("geometry"):
            continue
        line = LineString([xy(p["lat"], p["lon"]) for p in m["geometry"]])
        (inner if m.get("role") == "inner" else outer).append(line)
    if not outer:
        return None
    shell = unary_union(list(polygonize(unary_union(outer))))
    holes = unary_union(list(polygonize(unary_union(inner)))) if inner else None
    return shell.difference(holes) if holes is not None and not holes.is_empty else shell


def kind_of(tags):
    lu, le, am = tags.get("landuse"), tags.get("leisure"), tags.get("amenity")
    if tags.get("highway") in ("pedestrian", "footway") or tags.get("place") == "square" \
            or "area:highway" in tags or am == "marketplace":
        return "plaza"
    if am == "parking":
        return "parking"
    if lu in ("residential",):
        return "block"
    if lu in ("commercial", "retail"):
        return "court"
    if lu in ("allotments", "grass", "meadow", "village_green") or le in ("garden", "playground"):
        return "lawn"
    return None


def main():
    ground = json.load(open(os.path.join(OSM, "ground.json")))["elements"]
    streets = json.load(open(os.path.join(OSM, "streets.json")))["elements"]
    buildings = json.load(open(os.path.join(OSM, "buildings.json")))["elements"]
    trees_existing = json.load(open(os.path.join(RES, "frankfurt_trees.geojson")))["features"]

    areas = {"block": [], "court": [], "lawn": [], "parking": [], "plaza": []}
    for e in ground:
        k = kind_of(e.get("tags", {}))
        if not k:
            continue
        poly = way_polygon(e["geometry"]) if e["type"] == "way" and e.get("geometry") else \
            relation_polygon(e) if e["type"] == "relation" else None
        if poly is not None and not poly.is_empty and poly.area > 20:
            areas[k].append(poly)
    print({k: len(v) for k, v in areas.items()})

    road_buf = []
    for e in streets:
        if e["type"] != "way" or not e.get("geometry"):
            continue
        hw = e.get("tags", {}).get("highway", "").replace("_link", "")
        if hw in STREET_CLEAR and e.get("tags", {}).get("area") != "yes":
            road_buf.append(LineString([xy(p["lat"], p["lon"]) for p in e["geometry"]]).buffer(STREET_CLEAR[hw], 8))
    # Pedestrian zones, squares and footpaths stay paved (the Römerberg sits inside a residential block).
    life = json.load(open(os.path.join(OSM, "life.json")))["elements"]
    for e in streets + life:
        if e["type"] != "way" or not e.get("geometry"):
            continue
        t = e.get("tags", {})
        hw = t.get("highway")
        if hw in ("pedestrian", "footway", "living_street") or t.get("place") == "square":
            closed = e["geometry"][0] == e["geometry"][-1]
            if closed and (t.get("area") == "yes" or hw == "pedestrian" or t.get("place") == "square"):
                p = way_polygon(e["geometry"])
                if p is not None:
                    road_buf.append(p.buffer(1.5))
            elif hw in ("pedestrian", "living_street"):
                road_buf.append(LineString([xy(q["lat"], q["lon"]) for q in e["geometry"]]).buffer(5, 8))
    road_buf += [p.buffer(1.5) for p in areas["plaza"]]
    roads = unary_union(road_buf)
    print("roads buffered")

    bpolys = []
    for e in buildings:
        g = e.get("geometry")
        if g and len(g) >= 4:
            p = way_polygon(g)
            if p is not None and not p.is_empty:
                bpolys.append(p)
    houses = unary_union([p.buffer(2.6, 2) for p in bpolys])
    print("buildings buffered", len(bpolys))

    blocks = unary_union(areas["block"] + areas["court"]).difference(roads)
    parking = unary_union(areas["parking"]).difference(houses)
    gardens = unary_union([unary_union(areas["block"]).difference(roads).difference(houses),
                           unary_union(areas["lawn"]).difference(houses)]).difference(parking)
    paved = blocks.difference(parking)

    features = []

    def add(geom, kind, tol=0.6, min_area=12):
        geom = geom.simplify(tol)
        parts = getattr(geom, "geoms", [geom])
        for g in parts:
            if g.geom_type != "Polygon" or g.area < min_area:
                continue
            gj = mapping(transform(to_lonlat, g))
            gj["coordinates"] = [[[round(x, 7), round(y, 7)] for x, y in ring] for ring in gj["coordinates"]]
            features.append({"type": "Feature", "geometry": gj, "properties": {"k": kind}})

    add(paved, "paved")
    add(gardens, "garden", min_area=25)
    add(parking, "parking")
    # Soft lawn patches: the gardens shrunk and regrown with round joins, which drops slivers and
    # rounds every corner, so patches read as planted lawns rather than leftover shapes.
    soft = gardens.buffer(-1.5, 4).buffer(1.0, 8)
    add(soft, "lawn", tol=0.8, min_area=150)
    counts = {k: sum(1 for f in features if f["properties"]["k"] == k) for k in ("paved", "garden", "parking", "lawn")}

    # Garden trees in small clumps (2–5), the way back gardens grow, kept off walls and away from
    # mapped street trees. Single bushes dotted everywhere looked like litter.
    near = STRtree([Point(*xy(f["geometry"]["coordinates"][1], f["geometry"]["coordinates"][0])) for f in trees_existing])
    inner = gardens.buffer(-2.0)
    n = 0
    for g in getattr(inner, "geoms", [inner]):
        if g.is_empty or g.area < 60:
            continue
        pg = prep(g)
        minx, miny, maxx, maxy = g.bounds
        step = 15.0
        y = miny + random.uniform(0, step)
        while y < maxy:
            x = minx + random.uniform(0, step)
            while x < maxx:
                cx, cy = x + random.uniform(-6, 6), y + random.uniform(-6, 6)
                x += step
                if random.random() > 0.6 or not pg.contains(Point(cx, cy)) or len(near.query(Point(cx, cy).buffer(4))):
                    continue
                for _ in range(random.randint(2, 3)):
                    a_, d_ = random.uniform(0, 2 * math.pi), random.uniform(0, 4.5)
                    px, py = cx + math.cos(a_) * d_, cy + math.sin(a_) * d_
                    if not pg.contains(Point(px, py)):
                        continue
                    r = random.random()
                    m = "tree_a" if r < 0.4 else "tree_b" if r < 0.7 else "tree_c" if r < 0.9 else "bush_a"
                    lon, lat = to_lonlat(px, py)
                    features.append({"type": "Feature", "geometry": {"type": "Point", "coordinates": [round(lon, 7), round(lat, 7)]},
                                     "properties": {"k": "tree", "m": m}})
                    n += 1
            y += step
    counts["tree"] = n

    json.dump({"type": "FeatureCollection", "features": features}, open(OUT, "w"), separators=(",", ":"))
    print(counts, "->", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
