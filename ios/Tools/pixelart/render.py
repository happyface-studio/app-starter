"""Reference renderer for the Deskmates office. The Swift and JS renderers mirror this file."""

from __future__ import annotations

import sys
from dataclasses import dataclass, field

from design import *  # noqa: F403

Buffer = list[list[str | None]]


@dataclass
class Look:
    skin: int = 0
    hair: int = 0
    hair_color: int = 0
    shirt: int = 0
    accessory: int = 0


@dataclass
class DeskState:
    name: str
    look: Look = field(default_factory=Look)
    has_line: bool = True
    activity: str = "idle"  # idle | ringing | listening | thinking | speaking | human


def new_buffer(w: int, h: int) -> Buffer:
    return [[None] * w for _ in range(h)]


def put(buf: Buffer, x: int, y: int, color: str | None) -> None:
    if color and 0 <= y < len(buf) and 0 <= x < len(buf[0]):
        buf[y][x] = color


def rect(buf: Buffer, x: int, y: int, w: int, h: int, color: str) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(buf, xx, yy, color)


def blit(buf: Buffer, sprite: list[str], x: int, y: int, palette: dict[str, str]) -> None:
    for dy, row in enumerate(sprite):
        for dx, ch in enumerate(row):
            if ch != ".":
                put(buf, x + dx, y + dy, palette.get(ch, "#FF00FF"))


def char_palette(look: Look) -> dict[str, str]:
    s, S = SKIN[look.skin % len(SKIN)]
    h, H = HAIR[look.hair_color % len(HAIR)]
    c, C = SHIRT[look.shirt % len(SHIRT)]
    return {**FIXED, "s": s, "S": S, "h": h, "H": H, "c": c, "C": C}


def draw_character(buf: Buffer, look: Look, x: int, y: int, activity: str, t: int) -> None:
    pal = char_palette(look)
    bob = 1 if (t // 8) % 2 == 1 else 0
    if activity == "listening" and t % 16 in (8, 9, 10, 11):
        bob = 1
    y += bob
    blit(buf, BODY, x, y, pal)
    blink = t % 44 in (0, 1)
    blit(buf, FACE_BLINK if blink else FACE, x, y, pal)
    if activity == "speaking" and (t // 2) % 2 == 0:
        blit(buf, MOUTH_OPEN, x, y, pal)
    blit(buf, HAIR_STYLES[HAIR_ORDER[look.hair % len(HAIR_ORDER)]], x, y, pal)
    blit(buf, ACCESSORIES[ACCESSORY_ORDER[look.accessory % len(ACCESSORY_ORDER)]], x, y, pal)


def text_width(text: str) -> int:
    return max(0, len(text) * 4 - 1)


def draw_text(buf: Buffer, text: str, x: int, y: int, color: str) -> None:
    for i, ch in enumerate(text):
        glyph = FONT.get(FOLD.get(ch, ch), FONT["?"])
        for gy, row in enumerate(glyph):
            for gx, px in enumerate(row):
                if px == "#":
                    put(buf, x + i * 4 + gx, y + gy, color)


def plate_text(name: str) -> str:
    up = "".join(FOLD.get(c, c) for c in name.upper())
    up = "".join(c if c in FONT else "" for c in up).strip()
    return up[:NAME_MAX] if up else "?"


def draw_wall(buf: Buffer, sky: str, t: int, hour: float) -> None:
    import math

    rect(buf, 0, 0, SCENE_W, WALL_H, WALL)
    rect(buf, 0, WALL_H - 5, SCENE_W, 3, WALL_SHADE)
    rect(buf, 0, WALL_H - 2, SCENE_W, 2, BASEBOARD)
    a, b = SKY[sky]
    for wx in (7, 63):
        rect(buf, wx - 1, 2, 28, 16, FIXED["k"])
        rect(buf, wx, 3, 26, 14, FIXED["w"])
        rect(buf, wx + 1, 4, 24, 12, a)
        rect(buf, wx + 1, 4, 24, 4, b)
        rect(buf, wx + 12, 4, 1, 12, FIXED["w"])
        rect(buf, wx + 1, 9, 24, 1, FIXED["w"])
        if sky == "night":
            for sx, sy in ((3, 6), (17, 5), (8, 12), (21, 13)):
                if (t // 6 + sx) % 5:
                    put(buf, wx + sx, sy, "#F6F1E6")
        elif sky == "day":
            cx = wx + 2 + (t // 24) % 6
            rect(buf, cx, 6, 5, 2, "#FFFFFF")
            rect(buf, cx + 1, 5, 2, 1, "#FFFFFF")
    cx, cy = 48, 10
    for dx in range(-5, 6):
        for dy in range(-5, 6):
            d2 = dx * dx + dy * dy
            if d2 <= 25:
                put(buf, cx + dx, cy + dy, FIXED["k"] if d2 > 16 else FIXED["w"])
    for length, angle, color in (
        (2, (hour % 12) / 12 * 2 * math.pi, FIXED["k"]),
        (3, (hour % 1) * 2 * math.pi, FIXED["p"]),
    ):
        for step in range(1, length + 1):
            put(buf, cx + round(math.sin(angle) * step), cy - round(math.cos(angle) * step), color)
    put(buf, cx, cy, FIXED["k"])


def draw_carpet(buf: Buffer) -> None:
    rect(buf, 0, WALL_H, SCENE_W, SCENE_H - WALL_H, CARPET)
    for y in range(WALL_H, SCENE_H):
        for x in range(SCENE_W):
            if (y - WALL_H) % 4 == 1 and (x + ((y - WALL_H) // 4) * 2) % 4 == 0:
                put(buf, x, y, CARPET_DOT)
    rect(buf, 0, WALL_H, SCENE_W, 1, CARPET_DARK)


def draw_bubble(buf: Buffer, x: int, y: int) -> None:
    rect(buf, x + 1, y, 13, 9, FIXED["k"])
    rect(buf, x, y + 1, 15, 7, FIXED["k"])
    rect(buf, x + 1, y + 1, 13, 7, FIXED["w"])
    put(buf, x + 1, y + 9, FIXED["k"])
    put(buf, x, y + 10, FIXED["k"])


def draw_cell(buf: Buffer, ox: int, oy: int, desk: DeskState | None, t: int) -> None:
    pal = FIXED
    px, py, pw, ph = PARTITION
    rect(buf, ox + px, oy + py, pw, ph, pal["k"])
    rect(buf, ox + px + 1, oy + py + 1, pw - 2, ph - 1, pal["f"])
    rect(buf, ox + px + 1, oy + py + 1, pw - 2, 1, pal["T"])
    for sx in range(ox + px + 4, ox + px + pw - 2, 6):
        rect(buf, sx, oy + py + 3, 1, ph - 4, pal["F"])

    if desk is not None:
        blit(buf, CHAIR, ox + CHAIR_POS[0], oy + CHAIR_POS[1], pal)
        draw_character(buf, desk.look, ox + CHAR_POS[0], oy + CHAR_POS[1], desk.activity, t)

    dx, dy, dw, dh = DESK_TOP
    fx, fy, fw, fh = DESK_FRONT
    rect(buf, ox + dx - 1, oy + dy - 1, dw + 2, dh + fh + 2, pal["k"])
    rect(buf, ox + dx, oy + dy, dw, dh, pal["d"])
    rect(buf, ox + dx, oy + fy, dw, 1, pal["q"])
    rect(buf, ox + dx, oy + fy + 1, dw, fh - 1, pal["D"])
    rect(buf, ox + dx + 1, oy + fy + fh + 1, dw - 2, 2, CARPET_DARK)

    if desk is None:
        blit(buf, PLANT, ox + 30, oy + 18, pal)
        draw_plate(buf, ox, oy, "VACANT", dim=True)
        return

    blit(buf, MONITOR, ox + MONITOR_POS[0], oy + MONITOR_POS[1], pal)
    blit(buf, MUG, ox + MUG_POS[0], oy + MUG_POS[1], pal)
    blit(buf, STEAM[(t // 4) % 2], ox + MUG_POS[0], oy + MUG_POS[1] - 3, {"w": "#E8EEF2"})

    ringing = desk.activity == "ringing"
    jiggle = (-1 if t % 2 else 1) if ringing and t % 10 < 6 else 0
    phx, phy = ox + PHONE_POS[0] + jiggle, oy + PHONE_POS[1]
    blit(buf, PHONE if desk.has_line else PHONE_DEAD, phx, phy, pal)
    lamp = pal["o"]
    if desk.has_line:
        lamp = MINT
        if ringing:
            lamp = AMBER if t % 4 < 2 else pal["o"]
        elif desk.activity in ("listening", "thinking", "speaking", "human"):
            lamp = MINT if t % 8 < 5 else "#3E8C6A"
    put(buf, phx + PHONE_LAMP[0], phy + PHONE_LAMP[1], lamp)
    if ringing and t % 10 < 6:
        for rx, ry in ((-2, 0), (-3, 1), (-2, 2), (11, 0), (12, 1), (11, 2)):
            put(buf, ox + PHONE_POS[0] + rx, phy + ry, AMBER)

    draw_plate(buf, ox, oy, plate_text(desk.name), dim=False)

    bx, by = ox + BUBBLE_POS[0], oy + BUBBLE_POS[1]
    if desk.activity == "thinking":
        draw_bubble(buf, bx, by)
        for i in range((t // 3) % 3 + 1):
            rect(buf, bx + 3 + i * 4, by + 4, 2, 2, FIXED["k"])
    elif desk.activity == "speaking":
        draw_bubble(buf, bx, by)
        heights = [1, 3, 5, 3, 2, 4]
        for i in range(5):
            hgt = heights[(t + i * 2) % 6]
            rect(buf, bx + 3 + i * 2, by + 4 - hgt // 2, 1, max(1, hgt), FIXED["p"])
    elif desk.activity == "human":
        draw_bubble(buf, bx, by)
        draw_text(buf, "YOU", bx + 2, by + 2, FIXED["p"])


def draw_plate(buf: Buffer, ox: int, oy: int, text: str, dim: bool) -> None:
    tw = text_width(text)
    w = max(17, tw + 6)
    x = ox + CELL_W // 2 - w // 2
    y = oy + PLATE_Y
    rect(buf, x, y, w, PLATE_H, FIXED["k"])
    rect(buf, x + 1, y + 1, w - 2, PLATE_H - 2, FIXED["N"] if dim else FIXED["n"])
    if not dim:
        rect(buf, x + 1, y + 1, w - 2, 1, "#F2D98C")
    draw_text(buf, text, x + (w - tw) // 2, y + 2, FIXED["t"] if not dim else "#6E521C")


def draw_office(desks: list[DeskState | None], t: int, sky: str = "day", hour: float = 10.2) -> Buffer:
    buf = new_buffer(SCENE_W, SCENE_H)
    draw_wall(buf, sky, t, hour)
    draw_carpet(buf)
    for seat in range(ROWS * 2):
        col, row = seat % 2, seat // 2
        desk = desks[seat] if seat < len(desks) else None
        draw_cell(buf, col * CELL_W, WALL_H + row * CELL_H, desk, t)
    return buf


def to_image(buf: Buffer, scale: int):
    from PIL import Image

    h, w = len(buf), len(buf[0])
    img = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            c = buf[y][x]
            if c:
                rgb = tuple(int(c[i : i + 2], 16) for i in (1, 3, 5)) + (255,)
                for yy in range(scale):
                    for xx in range(scale):
                        px[x * scale + xx, y * scale + yy] = rgb
    return img


if __name__ == "__main__":
    desks = [
        DeskState("Paula", Look(skin=1, hair=1, hair_color=2, shirt=0, accessory=0), True, "speaking"),
        DeskState("Otto", Look(skin=3, hair=0, hair_color=0, shirt=1, accessory=1), True, "ringing"),
        DeskState("Mia", Look(skin=0, hair=2, hair_color=3, shirt=2, accessory=0), True, "thinking"),
        DeskState("Kofi", Look(skin=4, hair=3, hair_color=0, shirt=4, accessory=2), False, "idle"),
        DeskState("Lena", Look(skin=2, hair=5, hair_color=6, shirt=5, accessory=3), True, "human"),
        None,
    ]
    out = sys.argv[1] if len(sys.argv) > 1 else "office.png"
    to_image(draw_office(desks, t=int(sys.argv[2]) if len(sys.argv) > 2 else 2), 4).save(out)
    print("wrote", out)
