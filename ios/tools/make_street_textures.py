"""Seamless overlay textures for streets (alpha only: dark joints, light highlights).

  python3 ios/tools/make_street_textures.py

Drawn at @2x; the map tints nothing, it lays these over the palette colours.
  tex_cobbles  small rounded setts (2 pt) in offset rows, @3x (pedestrian zones, plazas)
  tex_slabs    running-bond paving slabs (footpaths, sidewalks)
  tex_grain    faint asphalt grain with a few pebbles (roads)
  tex_grass    mottled lawn with fine blades (parks, grass)
  tex_water    soft light mottling with sparse wave marks (rivers, lakes)
  clouds       soft cloud-shadow blobs, a seamless 512 px tile repeated 4x4 into one 2048 px image
               (map-anchored, drifted by CloudShadows; not a pattern)
"""

import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Targets", "ExploreKit", "Resources", "Textures")
JOINT = (92, 62, 48)
LIGHT = (255, 252, 244)

random.seed(11)


def tiled(size, draw_fn, blur=0.0):
    """Draw on a 3x3 canvas and crop the centre so shapes crossing the edge wrap seamlessly.
    Blur happens before the crop, so it wraps too."""
    w, h = size
    big = Image.new("RGBA", (w * 3, h * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for ox in (0, w, 2 * w):
        for oy in (0, h, 2 * h):
            random.seed(11)
            draw_fn(d, ox, oy)
    if blur:
        big = big.filter(ImageFilter.GaussianBlur(blur))
    return big.crop((w, h, 2 * w, 2 * h))


def cobbles():
    # @3x tile with 6 px setts = 2 pt on screen. Drawn 4x larger and downsampled so the
    # tiny stones and joints stay crisp instead of blurring into noise.
    k = 4
    w, h, sw, sh = 192 * k, 192 * k, 6 * k, 6 * k
    rows = h // sh
    j = 0.55 * k  # joint half-width

    def draw(d, ox, oy):
        for r in range(rows):
            shift = (sw // 2) if r % 2 else 0
            for c in range(w // sw + 1):
                x0 = ox + c * sw + shift + random.choice((-0.25, 0, 0.25)) * k
                y0 = oy + r * sh
                box = (x0 + j, y0 + j, x0 + sw - j, y0 + sh - j)
                d.rounded_rectangle((box[0] - j, box[1] - j, box[2] + j, box[3] + j), 2 * k, fill=(*JOINT, 72))
                d.rounded_rectangle(box, 1.6 * k, fill=(*LIGHT, random.randint(6, 26)))
                d.rounded_rectangle((box[0] + 0.7 * k, box[1] + 0.5 * k, box[2] - 1.4 * k, box[1] + 1.4 * k), 0.7 * k, fill=(*LIGHT, 32))

    img = tiled((w, h), draw, blur=0.3 * k).resize((192, 192), Image.LANCZOS)
    img.save(os.path.join(OUT, "tex_cobbles@3x.png"))


def slabs():
    w, h, sw, sh = 128, 64, 64, 32

    def draw(d, ox, oy):
        for r in range(h // sh):
            shift = (sw // 2) if r % 2 else 0
            for c in range(w // sw + 1):
                x0 = ox + c * sw + shift
                y0 = oy + r * sh
                d.rectangle((x0, y0, x0 + sw, y0 + sh), fill=(*LIGHT, random.randint(0, 22)))
                d.line((x0, y0, x0 + sw, y0), fill=(*JOINT, 85), width=2)
                d.line((x0, y0, x0, y0 + sh), fill=(*JOINT, 85), width=2)

    tiled((w, h), draw, blur=0.5).save(os.path.join(OUT, "tex_slabs@2x.png"))


def grain():
    w, h = 128, 64

    def draw(d, ox, oy):
        for _ in range(1300):
            x, y = ox + random.random() * w, oy + random.random() * h
            dark = random.random() < 0.6
            d.point((x, y), fill=(*(JOINT if dark else LIGHT), random.randint(30, 70)))
        for _ in range(14):
            x, y, r = ox + random.random() * w, oy + random.random() * h, random.uniform(0.8, 1.8)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(*JOINT, 55))

    tiled((w, h), draw).save(os.path.join(OUT, "tex_grain@2x.png"))


def mottle(d, ox, oy, w, h, n, rmin, rmax, colour, amin, amax):
    for _ in range(n):
        x, y, r = ox + random.random() * w, oy + random.random() * h, random.uniform(rmin, rmax)
        d.ellipse((x - r, y - r * 0.8, x + r, y + r * 0.8), fill=(*colour, random.randint(amin, amax)))


def grass():
    w = h = 256
    dark, light = (46, 70, 20), (236, 248, 190)

    def draw(d, ox, oy):
        mottle(d, ox, oy, w, h, 28, 14, 32, dark, 16, 30)
        mottle(d, ox, oy, w, h, 24, 12, 28, light, 12, 24)

    base = tiled((w, h), draw, blur=9)

    def blades(d, ox, oy):
        for _ in range(2600):
            x, y = ox + random.random() * w, oy + random.random() * h
            ln = random.uniform(1.5, 3.5)
            lean = random.uniform(-0.8, 0.8)
            is_dark = random.random() < 0.55
            d.line((x, y, x + lean, y - ln), fill=(*(dark if is_dark else light), random.randint(30, 60)), width=1)

    top = tiled((w, h), blades)
    base.alpha_composite(top)
    base.save(os.path.join(OUT, "tex_grass@2x.png"))


def water():
    w = h = 256
    light, deep = (235, 248, 255), (20, 60, 110)

    def draw(d, ox, oy):
        mottle(d, ox, oy, w, h, 18, 18, 40, light, 12, 24)
        mottle(d, ox, oy, w, h, 14, 18, 36, deep, 10, 18)

    base = tiled((w, h), draw, blur=12)

    def waves(d, ox, oy):
        for _ in range(22):
            x, y = ox + random.random() * w, oy + random.random() * h
            span = random.uniform(14, 26)
            d.arc((x - span, y - 2.5, x + span, y + 2.5), 195, 345, fill=(*light, random.randint(40, 70)), width=2)

    top = tiled((w, h), waves, blur=0.8)
    base.alpha_composite(top)
    base.save(os.path.join(OUT, "tex_water@2x.png"))


def clouds():
    w = h = 512
    shade = (24, 30, 58)

    def draw(d, ox, oy):
        for _ in range(7):   # cloud bodies: clusters of puffs, with clear sky between them
            cx, cy = ox + random.random() * w, oy + random.random() * h
            for _ in range(random.randint(6, 10)):
                r = random.uniform(16, 38)
                x, y = cx + random.uniform(-46, 46), cy + random.uniform(-26, 26)
                d.ellipse((x - r * 1.3, y - r, x + r * 1.3, y + r), fill=(*shade, 235))

    tile = tiled((w, h), draw, blur=11)
    big = Image.new("RGBA", (w * 4, h * 4))
    for x in range(0, w * 4, w):
        for y in range(0, h * 4, h):
            big.paste(tile, (x, y))
    big.save(os.path.join(OUT, "..", "clouds.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    cobbles()
    slabs()
    grain()
    grass()
    water()

    print("ok")
