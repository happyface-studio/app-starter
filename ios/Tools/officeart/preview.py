#!/usr/bin/env python3
"""Build the single-file browser preview of the office from the packed art.

    python ios/Tools/officeart/preview.py [--art <OfficeArt folder>] [-o preview.html]

The page embeds the atlas and the character layers it needs, so it contains
licensed LimeZu art: keep it private, don't commit it.
"""

from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path

from pack import REPO_OUT

HERE = Path(__file__).parent

DESKS = [
    {"name": "Paula", "role": "Assistant",
     "look": {"skin": 1, "eyes": 0, "hair": 3, "hair_color": 2, "shirt": 4, "shirt_color": 1, "accessory": 0},
     "line": True, "lineLabel": "+49 69 2475 1180", "lineNote": "Studio number. Calls in and out.",
     "brief": "Books tables, appointments and deliveries for Simon. Always confirms the date twice."},
    {"name": "Otto", "role": "Front desk, Kiez Bikes",
     "look": {"skin": 4, "eyes": 1, "hair": 11, "hair_color": 0, "shirt": 9, "shirt_color": 0, "accessory": 1},
     "line": True, "lineLabel": "+1 415 555 0123", "lineNote": "LiveKit number. Takes calls only.",
     "brief": "Answers for a bike repair shop. Open Tuesday to Saturday, 10 to 7. Takes a message for anything about an order. Never quotes prices."},
    {"name": "Mia", "role": "Receptionist",
     "look": {"skin": 0, "eyes": 2, "hair": 19, "hair_color": 3, "shirt": 18, "shirt_color": 2, "accessory": 0},
     "line": True, "lineLabel": "+49 69 2475 1181", "lineNote": "Studio number. Calls in and out.",
     "brief": "Answers the studio line, screens sales calls, and passes real questions on."},
    None,
    {"name": "Kofi", "role": "Night shift",
     "look": {"skin": 6, "eyes": 0, "hair": 7, "hair_color": 0, "shirt": 25, "shirt_color": 0, "accessory": 14},
     "line": False, "lineLabel": None, "lineNote": "No phone yet. You can still talk to him in the app.",
     "brief": "Covers evenings once he has a number."},
    {"name": "Lena", "role": "Support",
     "look": {"skin": 2, "eyes": 3, "hair": 23, "hair_color": 5, "shirt": 13, "shirt_color": 1, "accessory": 0},
     "line": True, "lineLabel": "+49 69 2475 1182", "lineNote": "Studio number. Calls in and out.",
     "brief": "Handles order questions for the shop and books returns."},
]


# Visitors are drawn from this pool (the page only embeds the layers it needs).
GUEST_LOOKS = [
    {"skin": 3, "eyes": 2, "hair": 15, "hair_color": 1, "shirt": 28, "shirt_color": 2, "accessory": 0},
    {"skin": 5, "eyes": 4, "hair": 2, "hair_color": 4, "shirt": 21, "shirt_color": 0, "accessory": 2},
    {"skin": 0, "eyes": 1, "hair": 9, "hair_color": 3, "shirt": 7, "shirt_color": 1, "accessory": 0},
    {"skin": 7, "eyes": 5, "hair": 24, "hair_color": 0, "shirt": 30, "shirt_color": 3, "accessory": 9},
    {"skin": 2, "eyes": 0, "hair": 5, "hair_color": 6, "shirt": 12, "shirt_color": 2, "accessory": 0},
    {"skin": 8, "eyes": 3, "hair": 17, "hair_color": 2, "shirt": 3, "shirt_color": 0, "accessory": 12},
]


def layers_for(c: dict, look: dict) -> list[str]:
    def pick(options, i):
        return options[abs(i) % len(options)]

    names = [
        pick(c["bodies"], look["skin"]), pick(c["eyes"], look["eyes"]),
        pick(pick(c["outfits"], look["shirt"]), look["shirt_color"]),
        pick(pick(c["hairs"], look["hair"]), look["hair_color"]),
    ]
    if look["accessory"] > 0:
        names.append(pick(c["accessories"], look["accessory"] - 1)["file"])
    return names


def data_uri(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--art", default=str(REPO_OUT))
    ap.add_argument("-o", "--out", default=str(HERE / "preview.html"))
    args = ap.parse_args()
    art = Path(args.art)
    manifest = json.loads((art / "office.json").read_text())

    images = {manifest["atlas"]: data_uri(art / f"{manifest['atlas']}.png"),
              manifest["background"]: data_uri(art / f"{manifest['background']}.png")}
    for look in [d["look"] for d in DESKS if d] + GUEST_LOOKS:
        for name in layers_for(manifest["characters"], look):
            images[name] = data_uri(art / f"{name}.png")

    data = "\n".join([
        f"const OFFICE = {json.dumps(manifest, separators=(',', ':'))};",
        f"const IMAGES = {json.dumps(images)};",
        f"const DESKS = {json.dumps(DESKS)};",
        f"const GUEST_LOOKS = {json.dumps(GUEST_LOOKS)};",
    ])
    page = (HERE / "preview.template.html").read_text()
    page = page.replace("/*__DATA__*/", data)
    page = page.replace('<script src="preview.js"></script>', "<script>\n" + (HERE / "preview.js").read_text() + "</script>")
    Path(args.out).write_text(page)
    print(f"wrote {args.out} ({len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
