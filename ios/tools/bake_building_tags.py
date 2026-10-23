"""Real roof shapes and façade/roof colours from OSM, keyed by OSM way id (= the Mapbox building
feature id), for `Basemap` to fold into Standard's procedural building layer.

  python3 ios/tools/bake_building_tags.py      # needs osm/buildings.json (fetch_osm_streets.sh)

Writes Resources/frankfurt_building_tags.json:
  {"roof":  {"gabled": [ids], "hipped": [...], ...},
   "wall":  {"#RRGGBB": [ids], ...},          colours snapped to a small toy palette
   "roofColour": {"#RRGGBB": [ids], ...}}
"""

import json
import os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "osm", "buildings.json")
OUT = os.path.join(HERE, "..", "Targets", "ExploreKit", "Resources", "frankfurt_building_tags.json")

# OSM roof:shape -> what Mapbox's building renderer can draw.
ROOF = {
    "gabled": "gabled", "gambrel": "gabled", "saltbox": "gabled", "double_saltbox": "gabled",
    "hipped": "hipped", "half-hipped": "hipped", "half_hipped": "hipped", "mansard": "hipped",
    "side_hipped": "hipped", "gabled_row": "gabled", "hipped-and-gabled": "hipped",
    "pyramidal": "pyramidal", "skillion": "skillion", "lean_to": "skillion",
    "flat": "flat", "dome": "flat", "onion": "flat", "round": "flat",
}

# Toy versions of real façade colours: soft, a little lighter than life.
WALL = {
    "white": "#F4F1EA", "cream": "#F2E6C8", "beige": "#E8D9BC", "yellow": "#EFD38C",
    "orange": "#E3A466", "red": "#C4705A", "brown": "#A57A5E", "pink": "#E8B9AE",
    "grey": "#CFCDC8", "darkgrey": "#8E8D90", "black": "#6E6E73", "blue": "#A9BCD3", "green": "#B9C9A4",
}
ROOF_COLOUR = {
    "red": "#B5634B", "brown": "#8E5E48", "orange": "#C77A52", "grey": "#7F8492", "darkgrey": "#555B6E",
    "black": "#454A5C", "green": "#7FA58E", "blue": "#5F688E", "white": "#D9DADC", "beige": "#C9B697",
}

ALIASES = {
    "gray": "grey", "lightgrey": "grey", "lightgray": "grey", "silver": "grey", "darkgray": "darkgrey",
    "anthracite": "darkgrey", "ivory": "cream", "tan": "beige", "sand": "beige", "khaki": "beige",
    "maroon": "red", "darkred": "red", "terracotta": "red", "brick": "red", "salmon": "pink",
    "gold": "yellow", "lightyellow": "yellow", "navy": "blue", "lightblue": "blue", "teal": "green",
    "olive": "green", "copper": "green", "chocolate": "brown", "sienna": "brown",
}


def rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def snap(value, palette):
    v = value.strip().lower().replace(" ", "").replace("_", "")
    v = ALIASES.get(v, v)
    if v in palette:
        return palette[v]
    if v.startswith("#") and len(v) in (4, 7):
        try:
            c = rgb(v)
        except ValueError:
            return None
        return min(palette.values(), key=lambda p: sum((a - b) ** 2 for a, b in zip(rgb(p), c)))
    return None


def main():
    roof, wall, roof_colour = defaultdict(list), defaultdict(list), defaultdict(list)
    for e in json.load(open(SRC))["elements"]:
        t = e.get("tags", {})
        i = e["id"]
        shape = ROOF.get(t.get("roof:shape", "").lower())
        if shape:
            roof[shape].append(i)
        c = snap(t["building:colour"], WALL) if "building:colour" in t else None
        if c:
            wall[c].append(i)
        c = snap(t["roof:colour"], ROOF_COLOUR) if "roof:colour" in t else None
        if c:
            roof_colour[c].append(i)
    out = {"roof": roof, "wall": wall, "roofColour": roof_colour}
    json.dump(out, open(OUT, "w"), separators=(",", ":"))
    print({k: {kk: len(vv) for kk, vv in v.items()} for k, v in out.items()})


if __name__ == "__main__":
    main()
