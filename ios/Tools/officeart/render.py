"""Reference renderer for the office manifest. The Swift scene and the web preview
follow the same rules; this one renders stills for review.

Depth: everything is sorted by its bottom edge. A seated deskmate's feet sit
just behind the desk's back edge, so the desk top hides their legs.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

PLATE = (224, 188, 98, 255)
PLATE_DIM = (168, 133, 54, 255)
PLATE_HI = (242, 217, 140, 255)
INK = (74, 53, 24, 255)
INK_DIM = (110, 82, 28, 255)
OUTLINE = (58, 58, 80, 255)
AMBER = (244, 178, 62, 255)


class Art:
    def __init__(self, manifest: dict, folder: Path):
        self.m = manifest
        self.folder = Path(folder)
        self.atlas = Image.open(self.folder / f"{manifest['atlas']}.png").convert("RGBA")
        self.bg = Image.open(self.folder / f"{manifest['background']}.png").convert("RGBA")
        self.strips: dict[str, Image.Image] = {}

    def sprite(self, name: str, t: float = 0, frame: int | None = None):
        s = self.m["sprites"][name]
        frames = s["frames"]
        i = frame if frame is not None else (int(t * s["fps"]) % len(frames) if s["fps"] else 0)
        x, y = frames[i % len(frames)]
        return self.atlas.crop((x, y, x + s["w"], y + s["h"])), s["dx"], s["dy"]

    def layer(self, name: str) -> Image.Image:
        if name not in self.strips:
            self.strips[name] = Image.open(self.folder / f"{name}.png").convert("RGBA")
        return self.strips[name]

    def layers_for(self, look: dict) -> list[str]:
        c = self.m["characters"]

        def pick(options, i):
            return options[abs(i) % len(options)]

        names = [
            pick(c["bodies"], look.get("skin", 0)),
            pick(c["eyes"], look.get("eyes", 0)),
            pick(pick(c["outfits"], look.get("shirt", 0)), look.get("shirt_color", 0)),
            pick(pick(c["hairs"], look.get("hair", 0)), look.get("hair_color", 0)),
        ]
        acc = look.get("accessory", 0)
        if acc > 0 and c["accessories"]:
            names.append(pick(c["accessories"], acc - 1)["file"])
        return names

    def strip(self, look: dict) -> Image.Image:
        out = None
        for name in self.layers_for(look):
            img = self.layer(name)
            out = img.copy() if out is None else Image.alpha_composite(out, img)
        return out

    def char_frame(self, strip: Image.Image, anim: str, t: float, face: str = "down", fps: float = 6, frame=None):
        a = self.m["characters"]["anims"][anim]
        fw, fh = self.m["characters"]["frameW"], self.m["characters"]["frameH"]
        if "perDir" in a:
            i = frame if frame is not None else int(t * fps) % a["perDir"]
            idx = a["start"] + (a["dirs"].index(face) if face in a["dirs"] else 0) * a["perDir"] + i
        else:
            lo, hi = a["loop"]
            i = frame if frame is not None else lo + int(t * fps) % (hi - lo + 1)
            idx = a["start"] + i
        return strip.crop((idx * fw, 0, (idx + 1) * fw, fh)), i

    def plate(self, text: str, dim: bool) -> Image.Image:
        font, fold = self.m["font"], self.m["fold"]
        text = "".join(fold.get(ch, ch) for ch in text.upper())
        text = "".join(ch for ch in text if ch in font).strip()[:8] or "?"
        tw = len(text) * 4 - 1
        w = max(17, tw + 6)
        img = Image.new("RGBA", (w, 9), OUTLINE)
        px = img.load()
        for x in range(1, w - 1):
            for y in range(1, 8):
                px[x, y] = PLATE_DIM if dim else PLATE
            if not dim:
                px[x, 1] = PLATE_HI
        ox = (w - tw) // 2
        for i, ch in enumerate(text):
            for gy, row in enumerate(font[ch]):
                for gx, c in enumerate(row):
                    if c == "#":
                        px[ox + i * 4 + gx, 2 + gy] = INK_DIM if dim else INK
        return img


def compose(art: Art, desks: list, walkers: list, t: float) -> Image.Image:
    """desks: per seat None or {name, look, line, activity, away}.
    walkers: people away from their desk or visiting, {look, x, y, face, frame} while walking,
    or {look, place} once they've arrived at one of the manifest's `pois`."""
    m = art.m
    canvas = art.bg.copy()
    items = []  # (z, image, x, y)

    for p in m["props"]:
        img, dx, dy = art.sprite(p["sprite"], t)
        items.append((p["z"], img, p["x"] + dx, p["y"] + dy))

    desk_img, _, _ = art.sprite(m["desk"])
    chair_img, _, _ = art.sprite("chair")
    for st, desk in zip(m["stations"], desks):
        d, f = st["desk"], st["feet"]
        base = d["y"] + desk_img.height
        items.append((base, desk_img, d["x"], d["y"]))
        items.append((f["y"] - 2, chair_img, st["chair"]["x"], st["chair"]["y"]))
        if desk is None:
            plant, pdx, pdy = art.sprite("plant_small")
            items.append((base + 1, plant, d["x"] + 12 + pdx, d["y"] - 8 + pdy))
            items.append((base + 3, art.plate("VACANT", True), st["plate"]["cx"] - art.plate("VACANT", True).width // 2, st["plate"]["y"]))
            continue
        mon, _, _ = art.sprite("monitor_back")
        items.append((base + 1, mon, st["monitor"]["x"], st["monitor"]["y"]))
        it = st["item"]
        if it:
            img, dx, dy = art.sprite(it["name"], t)
            items.append((base + 1, img, it["x"] + dx, it["y"] + dy))
        act = desk.get("activity", "idle")
        if desk.get("line"):
            ph, _, _ = art.sprite("phone_rotary")
            jig = (1 if int(t * 12) % 2 else -1) if act == "ringing" and int(t * 10) % 10 < 6 else 0
            items.append((base + 2, ph, st["phone"]["x"] + jig, st["phone"]["y"]))
            if act == "ringing" and int(t * 10) % 10 < 6:
                ring = Image.new("RGBA", (22, 6))
                for rx, ry in [(0, 1), (1, 2), (0, 3), (21, 1), (20, 2), (21, 3)]:
                    ring.putpixel((rx, ry), AMBER)
                items.append((base + 3, ring, st["phone"]["x"] - 3, st["phone"]["y"] + 1))
        plate = art.plate(desk["name"], False)
        items.append((base + 3, plate, st["plate"]["cx"] - plate.width // 2, st["plate"]["y"]))

        if desk.get("away"):
            continue
        strip = art.strip(desk["look"])
        cx, cy = f["x"] - 8, f["y"] - 31
        if act == "dialing":
            fr, _ = art.char_frame(strip, "phone", t, fps=8)
            items.append((f["y"], fr, cx, cy))
        else:
            fr, i = art.char_frame(strip, "idle", t, "down", fps=5)
            items.append((f["y"], fr, cx, cy))
            if desk.get("line"):
                live = act in ("speaking", "listening", "thinking", "human")
                hs, _, _ = art.sprite("headset_live" if live else "headset", frame=i)
                items.append((f["y"] + 0.5, hs, cx, cy))
        emote = {"ringing": "emote_ring", "thinking": "emote_think", "speaking": "emote_speak", "human": "emote_boss"}.get(act)
        if emote:
            img, dx, dy = art.sprite(emote, t)
            b = st["bubble"]
            items.append((10_000, img, b["x"], b["y"] - img.height))

    for w in walkers:
        strip = art.strip(w["look"])
        if "place" in w:
            poi = m["pois"][w["place"]]
            pose = poi.get("pose", "idle")
            fps = 3 if pose == "read" else 5
            fr, _ = art.char_frame(strip, pose, t, poi["face"], fps=fps)
            x, y, z = poi["x"], poi["y"], poi.get("z", poi["y"])
        else:
            fr, _ = art.char_frame(strip, "walk", t, w["face"], fps=10, frame=w.get("frame"))
            x, y, z = w["x"], w["y"], w["y"]
        items.append((z, fr, x - 8, y - 31))

    items.sort(key=lambda it: it[0])
    for _, img, x, y in items:
        canvas.alpha_composite(img, (int(x), int(y)))
    return canvas


SAMPLE = [
    {"name": "Paula", "look": {"skin": 1, "hair": 3, "hair_color": 2, "shirt": 4, "shirt_color": 1, "accessory": 0}, "line": True, "activity": "speaking"},
    {"name": "Otto", "look": {"skin": 4, "hair": 11, "hair_color": 0, "shirt": 9, "shirt_color": 0, "accessory": 1}, "line": True, "activity": "ringing"},
    {"name": "Mia", "look": {"skin": 0, "hair": 19, "hair_color": 3, "shirt": 18, "shirt_color": 2, "accessory": 0}, "line": True, "activity": "thinking"},
    None,
    {"name": "Kofi", "look": {"skin": 6, "hair": 7, "hair_color": 0, "shirt": 25, "shirt_color": 0, "accessory": 14}, "line": True, "activity": "dialing"},
    {"name": "Lena", "look": {"skin": 2, "hair": 23, "hair_color": 5, "shirt": 13, "shirt_color": 1, "accessory": 0}, "line": False, "activity": "idle", "away": True},
]


GUEST_LOOKS = [
    {"skin": 3, "eyes": 2, "hair": 15, "hair_color": 1, "shirt": 28, "shirt_color": 2, "accessory": 0},
    {"skin": 5, "eyes": 4, "hair": 2, "hair_color": 4, "shirt": 21, "shirt_color": 0, "accessory": 2},
]


def still(manifest: dict, folder, path: str, scale: int = 3, t: float = 0.35):
    """A sample moment: calls at four desks, Lena on a coffee break, two visitors."""
    art = Art(manifest, Path(folder))
    walkers = [
        {"look": SAMPLE[5]["look"], "place": "table_left"},
        {"look": GUEST_LOOKS[0], "place": "wait_sofa_right"},
    ]
    arrive = manifest["guests"]["arrive"]
    (x0, y0), (x1, y1) = arrive[-2], arrive[-1]
    face = "left" if x1 < x0 else "right" if x1 > x0 else ("up" if y1 < y0 else "down")
    walkers.append({"look": GUEST_LOOKS[1], "x": (x0 + x1) // 2, "y": (y0 + y1) // 2, "face": face, "frame": 1})
    img = compose(art, SAMPLE, walkers, t)
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)
