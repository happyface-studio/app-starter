"""Painted bike lanes from OSM, for the road markings layer (`RoadMarkings`).

  python3 ios/tools/bake_markings.py      # needs osm/streets.json (fetch_osm_streets.sh)

Writes Resources/frankfurt_markings.geojson: lines along the road centre line with
  s      1 = lane on the right of the way's direction, -1 = on the left
  class  the Streets v8 road class, so the app can offset by the drawn road width
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "osm", "streets.json")
OUT = os.path.join(HERE, "..", "Targets", "ExploreKit", "Resources", "frankfurt_markings.geojson")

CLASS = {"primary": "primary", "primary_link": "primary_link", "secondary": "secondary", "secondary_link": "secondary_link",
         "tertiary": "tertiary", "tertiary_link": "tertiary_link", "residential": "street", "unclassified": "street",
         "living_street": "street", "trunk": "trunk"}
LANE = {"lane", "opposite_lane"}


def main():
    feats, n = [], 0
    for e in json.load(open(SRC))["elements"]:
        if e["type"] != "way" or not e.get("geometry"):
            continue
        t = e.get("tags", {})
        cls = CLASS.get(t.get("highway"))
        if not cls or t.get("tunnel") not in (None, "no"):
            continue
        both = t.get("cycleway:both") in LANE or t.get("cycleway") in LANE
        sides = set()
        if both:
            sides = {1, -1}
        if t.get("cycleway:right") in LANE:
            sides.add(1)
        if t.get("cycleway:left") in LANE:
            sides.add(-1)
        if t.get("oneway") in ("yes", "1") and t.get("cycleway") in LANE and not t.get("cycleway:both"):
            sides = {1}
        coords = [[round(p["lon"], 7), round(p["lat"], 7)] for p in e["geometry"]]
        for s in sides:
            feats.append({"type": "Feature", "geometry": {"type": "LineString", "coordinates": coords},
                          "properties": {"s": s, "class": cls}})
            n += 1
    json.dump({"type": "FeatureCollection", "features": feats}, open(OUT, "w"), separators=(",", ":"))
    print(n, "bike lane sides ->", OUT)


if __name__ == "__main__":
    main()
