"""Per-category colour stats for look matching: median of lit (top 40% lightness) and shaded (bottom 30%) pixels.

  python3 ios/tools/look_stats.py <top>,<bottom> shot1.png shot2.png ...   (crop as fractions of height)
"""
import sys, numpy as np
from PIL import Image
CATS = {  # hue range (deg), min sat, lightness range
    "roof":  ((215, 250), .14, (.25, .80)),
    "road":  ((355, 18),  .22, (.40, .80)),
    "grass": ((65, 115),  .28, (.25, .75)),
    "sand":  ((24, 46),   .18, (.55, .93)),
    "water": ((190, 214), .35, (.35, .80)),
}
def hsl(X):
    mx = X.max(1); mn = X.min(1); l = (mx + mn) / 2; d = mx - mn
    s = np.where(d == 0, 0, d / (1 - abs(2 * l - 1) + 1e-9))
    r, g, b = X.T; h = np.zeros(len(X)); nz = d > 0
    m = nz & (mx == r); h[m] = (60 * ((g[m] - b[m]) / d[m])) % 360
    m = nz & (mx == g); h[m] = 60 * ((b[m] - r[m]) / d[m]) + 120
    m = nz & (mx == b); h[m] = 60 * ((r[m] - g[m]) / d[m]) + 240
    return h, s, l
crop = [float(v) for v in sys.argv[1].split(",")]
px = []
for f in sys.argv[2:]:
    im = Image.open(f).convert("RGB"); w, hh = im.size
    im = im.crop((0, int(hh * crop[0]), w, int(hh * crop[1]))).resize((300, int(300 * hh * (crop[1] - crop[0]) / w)))
    px.append(np.asarray(im).reshape(-1, 3))
X = np.concatenate(px).astype(float) / 255
H, S, L = hsl(X)
for name, ((h0, h1), smin, (l0, l1)) in CATS.items():
    hm = (H >= h0) & (H <= h1) if h0 < h1 else (H >= h0) | (H <= h1)
    m = hm & (S >= smin) & (L >= l0) & (L <= l1)
    if m.sum() < 50: print(f"{name:6s} n/a"); continue
    Lm = L[m]; P = X[m]
    lit = P[Lm >= np.percentile(Lm, 60)]; sh = P[Lm <= np.percentile(Lm, 30)]
    f = lambda a: "#%02X%02X%02X" % tuple((np.median(a, 0) * 255).astype(int))
    print(f"{name:6s} {100*m.mean():4.1f}%  lit {f(lit)}  shade {f(sh)}")
