#!/usr/bin/env python3
"""Pack LimeZu pixel art into the Deskmates office.

The LimeZu packs are licensed for use in our app but not for redistribution, so
nothing this script writes is committed. Run it locally after cloning:

    python ios/Tools/officeart/pack.py \
        --limezu "~/Documents/Aiden Technologies/Game/Game Assets/Modern Pixel Art packs"

It writes into ios/Targets/OfficeKit/Resources/OfficeArt/ (gitignored):
    office.json      manifest: sprites, floor plan, stations, walk paths, character catalog
    office_atlas.png props, animated objects, emotes, headset
    office_bg.png    floor, walls and wall decor
    ch_*.png         one strip per character layer (60 frames of 16x32)

`--preview out.png` also renders a still of the office with sample states.
"""

from __future__ import annotations

import argparse
import heapq
import json
import os
import re
import sys
from pathlib import Path

from PIL import Image, ImageSequence

sys.path.insert(0, str(Path(__file__).parent))
import art  # noqa: E402
import scene  # noqa: E402

REPO_OUT = Path(__file__).resolve().parents[2] / "Targets/OfficeKit/Resources/OfficeArt"

FRAME_W, FRAME_H = 16, 32
STRIP_FRAMES = sum(n for _, _, n in art.CHAR_ROWS)

OUTLINE = (58, 58, 80, 255)
HEADSET = (58, 61, 78, 255)
HEADSET_LIGHT = (125, 132, 150, 255)
MIC_LIVE = (116, 224, 176, 255)


class Sources:
    def __init__(self, root: Path):
        self.root = root
        self.cache: dict[str, Image.Image] = {}

    def image(self, rel: str) -> Image.Image:
        if rel not in self.cache:
            path = self.root / rel
            if not path.exists():
                sys.exit(f"Missing {path}. Is --limezu pointing at the folder with the LimeZu packs?")
            self.cache[rel] = Image.open(path).convert("RGBA")
        return self.cache[rel]

    def crop(self, rel: str, rect) -> Image.Image:
        x, y, w, h = rect
        return self.image(rel).crop((x, y, x + w, y + h))

    def gif_frames(self, rel: str) -> list[Image.Image]:
        return [f.convert("RGBA").copy() for f in ImageSequence.Iterator(Image.open(self.root / rel))]


def union_bbox(frames: list[Image.Image]):
    box = None
    for f in frames:
        b = f.getbbox()
        if not b:
            continue
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box or (0, 0, 1, 1)


class Atlas:
    """Shelf-packs equally sized frames per sprite into one sheet."""

    def __init__(self):
        self.sprites: dict[str, dict] = {}
        self.frames: dict[str, list[Image.Image]] = {}

    def add(self, name: str, frames: list[Image.Image], fps: float = 0, trim: bool = True, **extra):
        dx = dy = 0
        if trim:
            box = union_bbox(frames)
            dx, dy = box[0], box[1]
            frames = [f.crop(box) for f in frames]
        self.frames[name] = frames
        self.sprites[name] = {"w": frames[0].width, "h": frames[0].height, "dx": dx, "dy": dy, "fps": fps, **extra}

    def pack(self, width: int = 512) -> Image.Image:
        items = sorted(self.frames.items(), key=lambda kv: -kv[1][0].height)
        x = y = shelf_h = 0
        placed = []
        for name, frames in items:
            coords = []
            for f in frames:
                if x + f.width > width:
                    x, y, shelf_h = 0, y + shelf_h + 1, 0
                coords.append([x, y])
                placed.append((f, x, y))
                x += f.width + 1
                shelf_h = max(shelf_h, f.height)
            self.sprites[name]["frames"] = coords
        sheet = Image.new("RGBA", (width, y + shelf_h + 1))
        for f, fx, fy in placed:
            sheet.alpha_composite(f, (fx, fy))
        return sheet


# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------


def character_strip(src: Sources, rel: str) -> Image.Image:
    sheet = src.image(rel)
    strip = Image.new("RGBA", (STRIP_FRAMES * FRAME_W, FRAME_H))
    x = 0
    for _, row, count in art.CHAR_ROWS:
        for i in range(count):
            fr = sheet.crop((i * FRAME_W, row * FRAME_H, (i + 1) * FRAME_W, (row + 1) * FRAME_H))
            strip.alpha_composite(fr, (x, 0))
            x += FRAME_W
    return strip


def character_catalog(src: Sources, out: Path | None):
    g = art.CHARS

    def files(folder: str, pattern: str):
        folder_path = src.root / g / folder / "16x16"
        return sorted(p.name for p in folder_path.glob(pattern))

    def emit(rel: str, name: str):
        if out is not None:
            character_strip(src, rel).save(out / f"{name}.png", optimize=True)
        return name

    bodies = [emit(f"{g}Bodies/16x16/{f}", f"ch_body_{i + 1:02d}") for i, f in enumerate(files("Bodies", "Body_*.png"))]
    eyes = [emit(f"{g}Eyes/16x16/{f}", f"ch_eyes_{i + 1:02d}") for i, f in enumerate(files("Eyes", "Eyes_*.png"))]

    def grouped(folder: str, prefix: str, tag: str):
        groups: dict[int, list[str]] = {}
        for f in files(folder, f"{prefix}_*.png"):
            m = re.match(rf"{prefix}_(\d+)_(\d+)\.png$", f)
            if m:
                groups.setdefault(int(m.group(1)), []).append(f)
        result = []
        for style in sorted(groups):
            result.append([
                emit(f"{g}{folder}/16x16/{f}", f"ch_{tag}_{style:02d}_{j + 1:02d}")
                for j, f in enumerate(sorted(groups[style]))
            ])
        return result

    outfits = grouped("Outfits", "Outfit", "outfit")
    hairs = grouped("Hairstyles", "Hairstyle", "hair")

    accessories = []
    for stem, label in art.ACCESSORIES:
        variants = files("Accessories", f"{stem}_[0-9]*.png")
        for j, f in enumerate(variants):
            num = re.search(r"_(\d+)_", stem).group(1)
            accessories.append({
                "label": label,
                "file": emit(f"{g}Accessories/16x16/{f}", f"ch_acc_{num}_{j + 1:02d}"),
            })

    anims = {}
    start = 0
    for name, _, count in art.CHAR_ROWS:
        if count == 24:
            anims[name] = {"start": start, "perDir": 6, "dirs": art.DIRS}
        else:
            anims[name] = {"start": start, "count": count, "loop": [3, 8]}
        start += count
    return {
        "frameW": FRAME_W,
        "frameH": FRAME_H,
        "anims": anims,
        "bodies": bodies,
        "eyes": eyes,
        "outfits": outfits,
        "hairs": hairs,
        "accessories": accessories,
    }


def headset_frames(src: Sources, live: bool) -> list[Image.Image]:
    """A call-centre headset drawn over the six idle-down frames (cups on both ears, mic on the left)."""
    body = src.image(f"{art.CHARS}Bodies/16x16/Body_01.png")
    idle_down = 18
    frames = []
    for i in range(6):
        fr = body.crop(((idle_down + i) * FRAME_W, FRAME_H, (idle_down + i + 1) * FRAME_W, 2 * FRAME_H))
        top = fr.getbbox()[1]
        dy = top - 10
        img = Image.new("RGBA", (FRAME_W, FRAME_H))
        px = img.load()
        for y in range(17, 22):
            px[0, y + dy] = OUTLINE
            px[1, y + dy] = HEADSET if y in (17, 21) else HEADSET_LIGHT
            px[15, y + dy] = OUTLINE
            px[14, y + dy] = HEADSET if y in (17, 21) else HEADSET_LIGHT
        for x, y in [(2, 22), (3, 23), (4, 23)]:
            px[x, y + dy] = OUTLINE
        px[5, 23 + dy] = MIC_LIVE if live else HEADSET_LIGHT
        frames.append(img)
    return frames


# ---------------------------------------------------------------------------
# Floor plan
# ---------------------------------------------------------------------------


def stations():
    result = []
    for seat in range(len(scene.ROWS) * len(scene.COLUMNS)):
        cx = scene.COLUMNS[seat % 2]
        dy = scene.ROWS[seat // 2]
        dx = cx - scene.DESK_W // 2
        item = scene.DESK_ITEMS[seat]
        result.append({
            "seat": seat,
            "desk": {"x": dx, "y": dy},
            "chair": {"x": cx - 8, "y": dy - 12},
            "feet": {"x": cx, "y": dy + 3},
            "monitor": {"x": dx, "y": dy - 1},
            "phone": {"x": dx + 26, "y": dy + 1},
            "item": {"name": item, "x": dx + 14, "y": dy - 14} if item else None,
            "plate": {"cx": cx, "y": dy + scene.DESK_H + 2},
            "bubble": {"x": cx + 6, "y": dy - 9},
            "tap": {"x": cx - 44, "y": dy - 26, "w": 88, "h": 60},
            "exit": {"x": cx + 28 if seat % 2 == 0 else cx - 28, "y": dy + 3},
        })
    return result


def footprints(atlas: Atlas):
    boxes = []
    for name, x, y in scene.PROPS:
        s = atlas.sprites[name]
        w, h = s["w"], s["h"]
        x, y = x + s["dx"], y + s["dy"]
        depth = min(h, 10)
        boxes.append((x, y + h - depth, w, depth))
    for st in stations():
        dx, dy, cx = st["desk"]["x"], st["desk"]["y"], st["feet"]["x"]
        boxes.append((dx, dy + 8, scene.DESK_W, scene.DESK_H - 8))   # desk
        boxes.append((cx - 9, dy - 4, 18, 9))                        # chair and whoever sits in it
        boxes.append((cx - 12, dy + scene.DESK_H + 2, 24, 9))        # nameplate
    return boxes + list(scene.BLOCKED)


def find_path(blocked_boxes, start, goal, step=2):
    """A* on a 2px grid for a 16px-wide walker's feet, preferring few turns."""
    pad_x, pad_up, pad_down = 6, 3, 1
    cols, rows = scene.W // step + 1, scene.H // step + 1

    def free(cx, cy):
        x, y = cx * step, cy * step
        if not (0 <= cx < cols and 0 <= cy < rows):
            return False
        for bx, by, bw, bh in blocked_boxes:
            if bx - pad_x <= x < bx + bw + pad_x and by - pad_down <= y < by + bh + pad_up:
                return False
        return True

    s = (round(start[0] / step), round(start[1] / step))
    g = (round(goal[0] / step), round(goal[1] / step))
    for p, label in ((s, "start"), (g, "goal")):
        if not free(*p):
            raise SystemExit(f"Path {label} {p[0] * step},{p[1] * step} is inside furniture; move it in scene.py.")
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    heap = [(0, 0, s, -1)]
    best = {(s, -1): 0}
    came = {}
    while heap:
        _, cost, cur, d = heapq.heappop(heap)
        if cur == g:
            break
        for nd, (ddx, ddy) in enumerate(dirs):
            nxt = (cur[0] + ddx, cur[1] + ddy)
            if not free(*nxt):
                continue
            nc = cost + 1 + (6 if d not in (-1, nd) else 0)
            key = (nxt, nd)
            if nc < best.get(key, 1e9):
                best[key] = nc
                came[key] = (cur, d)
                h = abs(nxt[0] - g[0]) + abs(nxt[1] - g[1])
                heapq.heappush(heap, (nc + h, nc, nxt, nd))
    else:
        raise SystemExit(f"No path from {start} to {goal}")
    key = (cur, d)
    pts = [cur]
    while key in came:
        key = came[key]
        pts.append(key[0])
    pts.reverse()
    corners = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        if (b[0] - a[0], b[1] - a[1]) != (c[0] - b[0], c[1] - b[1]):
            corners.append(b)
    corners.append(pts[-1])
    return [[p[0] * step, p[1] * step] for p in corners]


def background(src: Sources, statics: dict[str, Image.Image]) -> Image.Image:
    bg = Image.new("RGBA", (scene.W, scene.H), (0, 0, 0, 0))
    floor = src.crop(*art.FLOOR)
    for y in range(scene.FLOOR_TOP, scene.H, floor.height):
        for x in range(0, scene.W, floor.width):
            bg.alpha_composite(floor, (x, y))
    # The room-builder wall block is 32px; stretch its face so windows fit.
    sheet, (wx, wy, _, _) = art.WALL
    block = src.crop(sheet, (wx + 16, wy, 16, 32))
    cap, face, base = block.crop((0, 0, 16, 6)), block.crop((0, 10, 16, 11)), block.crop((0, 27, 16, 32))
    for x in range(0, scene.W, 16):
        bg.alpha_composite(cap, (x, 0))
        for y in range(6, scene.WALL_H - 5):
            bg.alpha_composite(face, (x, y))
        bg.alpha_composite(base, (x, scene.WALL_H - 5))
    bg.alpha_composite(Image.new("RGBA", (scene.W, 3), (20, 30, 40, 46)), (0, scene.FLOOR_TOP))
    for name, x, y in scene.WALL_DECOR + scene.FLOOR_DECOR:
        bg.alpha_composite(statics[name], (x, y))
    draw_border(bg)
    return bg


def draw_border(img: Image.Image):
    """LimeZu-style room outline: a white band with dark edges on the sides and bottom."""
    px = img.load()
    W, H, b = scene.W, scene.H, scene.BORDER
    for y in range(H):
        for x in range(W):
            d = min(x, W - 1 - x, H - 1 - y)
            if y < 6 and d >= b:
                continue
            if d < b:
                px[x, y] = OUTLINE if d in (0, b - 1) else (248, 248, 248, 255)
    for x in range(W):
        px[x, 0] = OUTLINE


# ---------------------------------------------------------------------------


def build(src: Sources, out: Path | None):
    atlas = Atlas()
    statics = {}
    for name, (sheet, rect) in art.STATIC.items():
        img = src.crop(sheet, rect)
        statics[name] = img
        atlas.add(name, [img], trim=False)
    for name, (sheet, fw, fh, count, fps) in art.ANIMATED.items():
        im = src.image(sheet)
        frames = [im.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(count)]
        atlas.add(name, frames, fps=fps)
    for name, (spec, fps) in art.EMOTES.items():
        frames = src.gif_frames(spec) if isinstance(spec, str) else [src.crop(s, r) for s, r in spec]
        atlas.add("emote_" + name, frames, fps=fps)
    atlas.add("headset", headset_frames(src, live=False), trim=False)
    atlas.add("headset_live", headset_frames(src, live=True), trim=False)

    blocked = footprints(atlas)
    st = stations()
    for s in st:
        s["paths"] = {}
        for poi_name, poi in scene.POIS.items():
            path = find_path(blocked, (s["exit"]["x"], s["exit"]["y"]), (poi["x"], poi["y"]))
            s["paths"][poi_name] = [[s["feet"]["x"], s["feet"]["y"]]] + path

    sheet = atlas.pack()
    bg = background(src, statics)

    props = []
    for name, x, y in scene.PROPS:
        sp = atlas.sprites[name]
        props.append({"sprite": name, "x": x, "y": y, "z": y + sp["dy"] + sp["h"]})

    manifest = {
        "version": 1,
        "scene": {"w": scene.W, "h": scene.H, "floorTop": scene.FLOOR_TOP},
        "atlas": "office_atlas",
        "background": "office_bg",
        "sprites": atlas.sprites,
        "props": props,
        "desk": scene.DESK,
        "stations": st,
        "pois": scene.POIS,
        "font": art.FONT,
        "fold": art.FOLD,
        "characters": character_catalog(src, out),
    }
    if out is not None:
        out.mkdir(parents=True, exist_ok=True)
        sheet.save(out / "office_atlas.png", optimize=True)
        bg.save(out / "office_bg.png", optimize=True)
        (out / "office.json").write_text(json.dumps(manifest, separators=(",", ":")))
    return manifest, sheet, bg


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--limezu", required=True, help="folder containing Modern_Office_Revamped and Modern_Interiors_v41.3.4")
    ap.add_argument("--out", default=str(REPO_OUT))
    ap.add_argument("--preview", help="also write a still of the office to this PNG")
    ap.add_argument("--scale", type=int, default=3)
    args = ap.parse_args()
    src = Sources(Path(os.path.expanduser(args.limezu)))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    manifest, sheet, bg = build(src, out)
    n = len(list(out.glob("ch_*.png")))
    print(f"wrote {out}: atlas {sheet.width}x{sheet.height}, {len(manifest['sprites'])} sprites, {n} character layers")
    if args.preview:
        import render
        render.still(manifest, out, args.preview, args.scale)
        print(f"preview {args.preview}")


if __name__ == "__main__":
    main()
