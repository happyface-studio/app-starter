"""Per-building pastel colours for the Altstadt, for the "pastel blocks" look comparison.

  python3 ios/tools/pastel_blocks.py ios/tools/osm/altstadt.json ios/Targets/ExploreKit/Resources/altstadt_pastel.geojson

Colour source per building, in order:
  1. OSM building:colour (named or hex), pulled towards cream so it stays pastel
  2. OSM building:material (sandstone, brick, timber framing ...)
  3. a believable guess by building type, varied per building id
Skips buildings Mapbox already models as landmarks (osm/landmark_mask.png).
"""

import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image, ImageColor
from shapely import contains_xy
from shapely.geometry import mapping

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bake_city as bc  # noqa: E402

CREAM = (247, 238, 222)

MATERIAL = {
    "sandstone": (205, 120, 105),
    "stone": (214, 200, 178),
    "brick": (196, 110, 86),
    "timber_framing": (238, 226, 205),
    "plaster": (240, 222, 190),
    "glass": (150, 185, 215),
    "concrete": (205, 205, 200),
}

# pastels a Frankfurt street plausibly has: sand, butter, peach, pale terracotta, sage, grey-blue, rose
GUESS = {
    "residential": [(240, 214, 170), (244, 228, 176), (240, 196, 168), (222, 160, 140), (206, 214, 180), (196, 208, 222), (232, 196, 196), (236, 226, 206)],
    "commercial": [(226, 222, 214), (206, 214, 224), (236, 224, 200), (214, 206, 196)],
    "church": [(210, 140, 124)],
}
KIND = {
    "apartments": "residential", "residential": "residential", "house": "residential", "yes": "residential",
    "retail": "commercial", "office": "commercial", "commercial": "commercial", "government": "commercial",
    "public": "commercial", "civic": "commercial", "hospital": "commercial", "parking": "commercial",
    "church": "church", "cathedral": "church", "monastery": "church",
}


def pastel(rgb, amount=0.45):
    """Mix towards cream, then cap saturation so every colour sits in the same soft family."""
    r, g, b = [c * (1 - amount) + k * amount for c, k in zip(rgb, CREAM)]
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    l = min(max(l, 0.70), 0.90)
    s = min(s, 0.55)
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


def osm_colour(value):
    try:
        return ImageColor.getrgb(value.strip().replace(" ", ""))
    except (ValueError, AttributeError):
        return None


def main(src, out):
    ways, rels, _ = bc.load(src)
    items = []
    for w in ways:
        t = w.get("tags", {})
        if "building" in t and t["building"] not in ("roof", "bridge", "construction"):
            p = bc.way_polygon(w)
            if p is not None:
                items.append((w["id"], p, t))
    for r in rels:
        t = r.get("tags", {})
        if "building" in t:
            g = bc.relation_polygon(r)
            for p in bc.polys(g):
                items.append((r["id"], p, t))

    mask_png = os.path.join(os.path.dirname(os.path.abspath(src)), "landmark_mask.png")
    m = np.asarray(Image.open(mask_png).convert("L")) > 127
    mj = json.load(open(mask_png.replace(".png", ".json")))

    def cover(poly):
        minx, miny, maxx, maxy = poly.bounds
        xs = np.arange(minx, maxx, mj["res"]) + mj["res"] / 2
        ys = np.arange(miny, maxy, mj["res"]) + mj["res"] / 2
        if not len(xs) or not len(ys):
            return 0.0
        gx, gy = np.meshgrid(xs, ys)
        inside = contains_xy(poly, gx, gy)
        col = ((gx - mj["x0"]) / mj["res"]).astype(int)
        row = ((mj["y1"] - gy) / mj["res"]).astype(int)
        ok = inside & (col >= 0) & (col < m.shape[1]) & (row >= 0) & (row < m.shape[0])
        return float(m[row[ok], col[ok]].sum()) / max(int(inside.sum()), 1)

    feats, stats = [], {"osm_colour": 0, "material": 0, "guess": 0, "landmark_skipped": 0}
    for oid, poly, t in items:
        if not bc.CLIP.intersects(poly) or poly.area < 12:
            continue
        if cover(poly) > 0.4:
            stats["landmark_skipped"] += 1
            continue
        rgb = osm_colour(t.get("building:colour"))
        if rgb:
            stats["osm_colour"] += 1
            colour = pastel(rgb, 0.35)
        elif t.get("building:material") in MATERIAL:
            stats["material"] += 1
            colour = pastel(MATERIAL[t["building:material"]], 0.3)
        else:
            stats["guess"] += 1
            options = GUESS[KIND.get(t.get("building"), "residential")]
            colour = pastel(options[oid % len(options)], 0.15)
        try:
            levels = float(t.get("building:levels", "0").split(";")[0])
        except ValueError:
            levels = 0
        height = float(t["height"]) if t.get("height", "").replace(".", "", 1).isdigit() else (levels * 3.3 + 1 if levels else 15)
        ring = [[round(bc.ORIGIN[1] + x / bc.M_LON, 7), round(bc.ORIGIN[0] + y / bc.M_LAT, 7)] for x, y in poly.exterior.coords]
        holes = [[[round(bc.ORIGIN[1] + x / bc.M_LON, 7), round(bc.ORIGIN[0] + y / bc.M_LAT, 7)] for x, y in h.coords] for h in poly.interiors]
        feats.append({"type": "Feature", "id": oid,
                      "geometry": {"type": "Polygon", "coordinates": [ring] + holes},
                      "properties": {"color": colour, "height": round(min(height, 60), 1)}})
    json.dump({"type": "FeatureCollection", "features": feats}, open(out, "w"), separators=(",", ":"))
    print(len(feats), "buildings", stats)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
