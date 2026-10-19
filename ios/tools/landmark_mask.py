"""Turns the app's top-down landmark snapshots into a footprint mask for the bake.

1. Run the app with `-landmarkMask YES`; it writes Documents/landmark_mask/ (tile_*.png + index.json):
   Mapbox Standard's hand-made landmark models only, over a flat magenta ground.
2. Copy that folder to ios/tools/landmark_mask/ and run:  python3 ios/tools/landmark_mask.py
3. Writes ios/tools/osm/landmark_mask.png (+ .json): 0.5 m/px, same local frame as bake_city.py.
   bake_city.py skips OSM buildings whose footprint is mostly covered by the mask.

Needs only numpy + pillow.
"""

import json
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "landmark_mask")
OUT = os.path.join(HERE, "osm", "landmark_mask.png")

ORIGIN = (50.1104, 8.6835)
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(ORIGIN[0]))
X0, X1, Y0, Y1 = -560.0, 560.0, -480.0, 480.0
RES = 0.5


def main():
    index = json.load(open(os.path.join(SRC, "index.json")))
    W = int((X1 - X0) / RES)
    H = int((Y1 - Y0) / RES)
    hits = np.zeros((H, W), dtype=np.uint16)
    seen = np.zeros((H, W), dtype=np.uint16)

    for t in index:
        img = np.asarray(Image.open(os.path.join(SRC, t["file"])).convert("RGB")).astype(np.float32)
        h, w, _ = img.shape
        r, g, b = img[..., 0], img[..., 1], img[..., 2]
        # magenta ground: red and blue high, green low. Landmark models are greys/beiges/greens.
        landmark = g > 0.6 * np.maximum(r, b) + 8

        lon_l, lat_t = t["tl"]
        lon_r, lat_b = t["br"]
        ys, xs = np.mgrid[0:h, 0:w]
        lon = lon_l + (xs + 0.5) / w * (lon_r - lon_l)
        lat = lat_t + (ys + 0.5) / h * (lat_b - lat_t)
        mx = (lon - ORIGIN[1]) * M_LON
        my = (lat - ORIGIN[0]) * M_LAT
        col = ((mx - X0) / RES).astype(int)
        row = ((Y1 - my) / RES).astype(int)
        ok = (col >= 0) & (col < W) & (row >= 0) & (row < H)
        np.add.at(seen, (row[ok], col[ok]), 1)
        np.add.at(hits, (row[ok & landmark], col[ok & landmark]), 1)

    mask = (hits > 0) & (hits * 2 >= seen)
    Image.fromarray((mask * 255).astype(np.uint8)).save(OUT)
    json.dump({"x0": X0, "x1": X1, "y0": Y0, "y1": Y1, "res": RES, "origin": ORIGIN},
              open(OUT.replace(".png", ".json"), "w"))
    print("mask px", int(mask.sum()), "of", W * H, "->", OUT)


if __name__ == "__main__":
    main()
