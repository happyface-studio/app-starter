"""Side-by-side look comparison from simulator screenshots.
python3 ios/tools/compare.py out.png "Left title" left_a.png left_b.png "Right title" right_a.png right_b.png
"""
import sys
from PIL import Image, ImageDraw, ImageFont

out, lt, la, lb, rt, ra, rb = sys.argv[1:8]
W = 600
def prep(p):
    im = Image.open(p).convert("RGB")
    w, h = im.size
    im = im.crop((0, int(h * 0.06), w, int(h * 0.62)))  # drop status bar and the sheet area
    return im.resize((W, int(im.height * W / im.width)))
cols = [(lt, prep(la), prep(lb)), (rt, prep(ra), prep(rb))]
H = cols[0][1].height
pad, head = 24, 70
canvas = Image.new("RGB", (pad * 3 + W * 2, head + H * 2 + pad * 3), (246, 241, 233))
d = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", 34)
except OSError:
    font = ImageFont.load_default()
for i, (title, a, b) in enumerate(cols):
    x = pad + i * (W + pad)
    d.text((x, 20), title, fill=(47, 52, 99), font=font)
    canvas.paste(a, (x, head))
    canvas.paste(b, (x, head + H + pad))
canvas.save(out)
print("saved", out, canvas.size)
