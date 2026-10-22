"""Toy street furniture for the map, as small GLBs (metres, Y up).

  python3 ios/tools/make_street_models.py

lamp_post / lamp_glow   black London-style post; the lantern glass is its own model so it can glow at night.
signal_body             pole + housing.
signal_red / _green     the lit lens only, so emissive strength applies to the light and not the housing.
The arm, housing and lenses face +X; the map rotates each instance towards the road.
"""

import math
import os

import numpy as np
import trimesh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Targets", "ExploreKit", "Resources", "Models")

POST = (0.17, 0.19, 0.20)
GLASS = (1.0, 0.93, 0.74)
HOUSING = (0.16, 0.19, 0.18)


def srgb(rgb):
    return np.array([*(np.clip(rgb, 0, 1) * 255), 255], dtype=np.uint8)


def paint(mesh, rgb):
    mesh.visual = trimesh.visual.ColorVisuals(mesh, vertex_colors=np.tile(srgb(rgb), (len(mesh.vertices), 1)))
    return mesh


def y_up(mesh):
    """trimesh primitives are Z-up; glTF is Y-up."""
    mesh.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, (1, 0, 0)))
    return mesh


def cyl(r, h, z0=0.0, sections=14):
    m = trimesh.creation.cylinder(radius=r, height=h, sections=sections)
    m.apply_translation((0, 0, z0 + h / 2))
    return m


def box(sx, sy, sz, at):
    m = trimesh.creation.box(extents=(sx, sy, sz))
    m.apply_translation(at)
    return m


def export(name, parts):
    """One vertex-coloured mesh per model: a single primitive keeps the map's draw calls down."""
    merged = trimesh.util.concatenate([paint(y_up(mesh), rgb) for mesh, rgb in parts])
    scene = trimesh.Scene()
    scene.add_geometry(merged, node_name=name)
    scene.export(os.path.join(OUT, f"{name}.glb"), include_normals=True)


def lamp():
    h = 4.0
    post = [
        (cyl(0.20, 0.35), POST),                     # plinth
        (cyl(0.13, 0.25, 0.35), POST),
        (cyl(0.075, h - 0.6, 0.6), POST),            # shaft
        (cyl(0.12, 0.08, h - 0.05), POST),           # collar
        (cyl(0.05, 0.25, h + 0.6), POST),            # finial
    ]
    cap = trimesh.creation.cone(radius=0.34, height=0.28, sections=16)
    cap.apply_translation((0, 0, h + 0.55))
    post.append((cap, POST))
    export("lamp_post", post)

    lantern = trimesh.creation.cone(radius=0.30, height=0.75, sections=16)
    lantern.apply_transform(trimesh.transformations.rotation_matrix(np.pi, (1, 0, 0)))
    lantern.apply_translation((0, 0, h + 0.62))   # inverted cone: wide under the cap, narrow at the collar
    export("lamp_glow", [(lantern, GLASS)])


def signal():
    pole_h = 3.0
    hx = 0.12                                       # housing sits slightly towards the road (+X)
    body = [
        (cyl(0.07, pole_h + 1.1), HOUSING),
        (box(0.30, 0.42, 1.15, (hx, 0, pole_h + 0.55)), HOUSING),
        (box(0.04, 0.56, 1.3, (hx - 0.16, 0, pole_h + 0.55)), HOUSING),   # backplate
    ]
    # visors over each lens
    for z in (pole_h + 0.9, pole_h + 0.55, pole_h + 0.2):
        body.append((box(0.18, 0.34, 0.04, (hx + 0.22, 0, z + 0.17)), HOUSING))
    export("signal_body", body)

    def lens(z, rgb, name):
        d = trimesh.creation.cylinder(radius=0.15, height=0.06, sections=18)
        d.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, (0, 1, 0)))
        d.apply_translation((hx + 0.16, 0, z))
        export(name, [(d, rgb)])

    lens(pole_h + 0.9, (1.0, 0.25, 0.20), "signal_red")
    lens(pole_h + 0.2, (0.25, 0.95, 0.45), "signal_green")


GLASS_DARK = (0.24, 0.27, 0.38)
TYRE = (0.12, 0.12, 0.13)


def rounded_box(sx, sy, sz, at, r=0.18):
    """Box with softened vertical edges (a 'toy' look), Z-up like the other primitives."""
    core = trimesh.creation.box(extents=(sx - 2 * r, sy, sz))
    side = trimesh.creation.box(extents=(sx, sy - 2 * r, sz))
    parts = [core, side]
    for cx in (-(sx / 2 - r), sx / 2 - r):
        for cy in (-(sy / 2 - r), sy / 2 - r):
            c = trimesh.creation.cylinder(radius=r, height=sz, sections=10)
            c.apply_translation((cx, cy, 0))
            parts.append(c)
    m = trimesh.util.concatenate(parts)
    m.apply_translation(at)
    return m


def wheels(length, width, r=0.34, inset=0.75):
    out = []
    for x in (length / 2 - inset, -(length / 2 - inset)):
        for y in (width / 2 - 0.12, -(width / 2 - 0.12)):
            w = trimesh.creation.cylinder(radius=r, height=0.24, sections=14)
            w.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, (1, 0, 0)))
            w.apply_translation((x, y, r))
            out.append((w, TYRE))
    return out


def car(name, paint_rgb, roof_sign=None):
    L, W = 4.2, 1.8
    parts = wheels(L, W)
    parts.append((rounded_box(L, W, 0.62, (0, 0, 0.62), r=0.32), paint_rgb))           # body
    parts.append((rounded_box(2.3, W - 0.18, 0.56, (-0.25, 0, 1.2), r=0.28), GLASS_DARK))  # glasshouse
    parts.append((rounded_box(2.1, W - 0.26, 0.08, (-0.25, 0, 1.5), r=0.24), paint_rgb))   # roof
    if roof_sign:
        parts.append((box(0.5, 0.28, 0.18, (-0.25, 0, 1.63)), roof_sign))
    export(name, parts)


def bus(name, body_rgb, band_rgb):
    L, W = 11.0, 2.5
    parts = wheels(L, W, r=0.48, inset=2.2)
    parts.append((rounded_box(L, W, 2.4, (0, 0, 1.75), r=0.4), body_rgb))
    parts.append((rounded_box(L - 0.3, W + 0.02, 0.85, (0, 0, 2.2), r=0.38), GLASS_DARK))  # window band
    parts.append((rounded_box(L - 0.1, W + 0.03, 0.22, (0, 0, 1.05), r=0.39), band_rgb))
    parts.append((box(0.06, W - 0.4, 1.0, (L / 2 + 0.01, 0, 2.15)), GLASS_DARK))            # windscreen
    export(name, parts)


def vehicles():
    for name, rgb in {
        "car_red": (0.78, 0.27, 0.23), "car_blue": (0.29, 0.43, 0.71), "car_white": (0.95, 0.94, 0.91),
        "car_yellow": (0.91, 0.76, 0.29), "car_green": (0.37, 0.60, 0.42), "car_black": (0.18, 0.18, 0.21),
    }.items():
        car(name, rgb)
    car("car_taxi", (0.94, 0.90, 0.78), roof_sign=(0.98, 0.84, 0.30))
    bus("bus", (0.96, 0.95, 0.92), (0.80, 0.18, 0.20))
    # Head and tail lights as their own models, so only they glow after dark.
    head, tail = (1.0, 0.95, 0.80), (1.0, 0.18, 0.15)
    for name, L, W, z in (("car_lights", 4.2, 1.8, 0.72), ("bus_lights", 11.0, 2.5, 1.0)):
        parts = []
        for y in (-(W / 2 - 0.3), W / 2 - 0.3):
            parts.append((box(0.06, 0.34, 0.16, (L / 2 + 0.02, y, z)), head))
            parts.append((box(0.06, 0.30, 0.14, (-L / 2 - 0.02, y, z)), tail))
        export(name, parts)


SKIN = (0.93, 0.76, 0.62)


def sphere(r, at, subdiv=2):
    m = trimesh.creation.icosphere(subdivisions=subdiv, radius=r)
    m.apply_translation(at)
    return m


def person(name, shirt, trousers):
    """Chunky toy pedestrian, 1.75 m, facing +X."""
    parts = []
    for y in (-0.11, 0.11):
        parts.append((rounded_box(0.2, 0.17, 0.85, (0, y, 0.43), r=0.07), trousers))
    parts.append((rounded_box(0.32, 0.5, 0.62, (0, 0, 1.15), r=0.14), shirt))
    parts.append((sphere(0.17, (0, 0, 1.62)), SKIN))
    export(name, parts)


def people():
    for name, shirt, trousers in [
        ("person_red", (0.82, 0.30, 0.26), (0.22, 0.25, 0.36)), ("person_blue", (0.30, 0.47, 0.74), (0.30, 0.30, 0.32)),
        ("person_mustard", (0.88, 0.70, 0.28), (0.24, 0.26, 0.38)), ("person_green", (0.36, 0.58, 0.40), (0.70, 0.62, 0.48)),
        ("person_white", (0.94, 0.93, 0.90), (0.24, 0.26, 0.38)), ("person_lilac", (0.62, 0.52, 0.78), (0.22, 0.22, 0.24)),
    ]:
        person(name, shirt, trousers)


TRAM_RED, TRAM_CREAM = (0.80, 0.17, 0.18), (0.95, 0.93, 0.88)


def tram():
    """Frankfurt-style tram, built as 10 m sections so it can bend round curves."""
    L, W = 10.0, 2.4
    def section(name, cab):
        parts = [(rounded_box(L - 0.3, W, 1.0, (0, 0, 0.85), r=0.3), TRAM_RED),
                 (rounded_box(L - 0.4, W + 0.02, 1.15, (0, 0, 1.95), r=0.3), GLASS_DARK),
                 (rounded_box(L - 0.3, W, 0.45, (0, 0, 2.75), r=0.3), TRAM_CREAM),
                 (box(2.6, 1.2, 0.25, (0, 0, 3.1)), (0.55, 0.57, 0.60))]          # roof gear
        if cab:
            parts.append((rounded_box(1.2, W - 0.1, 1.9, (L / 2 - 0.5, 0, 1.6), r=0.55), TRAM_RED))
            parts.append((box(0.06, W - 0.5, 1.0, (L / 2 + 0.11, 0, 1.95)), GLASS_DARK))
        export(name, parts)
    section("tram_cab", True)
    section("tram_mid", False)


def boats():
    hull_white, navy, red, wood = (0.96, 0.95, 0.92), (0.20, 0.27, 0.45), (0.80, 0.22, 0.20), (0.62, 0.42, 0.26)
    L, W = 32.0, 6.4
    parts = [(rounded_box(L, W, 1.6, (0, 0, 0.3), r=2.4), hull_white),
             (rounded_box(L - 0.2, W + 0.02, 0.3, (0, 0, 0.9), r=2.4), navy),
             (rounded_box(L - 8, W - 1.2, 2.2, (-1.5, 0, 2.2), r=1.2), hull_white),
             (rounded_box(L - 8.4, W - 1.1, 1.0, (-1.5, 0, 2.4), r=1.2), GLASS_DARK),
             (rounded_box(L - 9, W - 1.4, 0.25, (-1.5, 0, 3.4), r=1.1), red),
             (box(1.6, 1.6, 1.4, (L / 2 - 9, 0, 4.1)), hull_white)]                # wheelhouse
    export("boat_excursion", parts)
    export("boat_rowing", [(rounded_box(6, 1.3, 0.5, (0, 0, 0.1), r=0.6), wood),
                           (box(0.4, 0.4, 0.7, (0.6, 0, 0.6)), (0.30, 0.47, 0.74)),
                           (box(0.4, 0.4, 0.7, (-1.2, 0, 0.6)), (0.82, 0.30, 0.26)),
                           (box(0.1, 3.2, 0.05, (0.6, 0, 0.45)), wood)])
    export("duck", [(sphere(0.2, (0, 0, 0.12)), (0.55, 0.45, 0.35)),
                    (sphere(0.09, (0.16, 0, 0.3)), (0.20, 0.45, 0.30)),
                    (box(0.08, 0.05, 0.03, (0.26, 0, 0.29)), (0.95, 0.65, 0.20))])


def plane():
    white, blue = (0.97, 0.97, 0.98), (0.22, 0.32, 0.62)
    parts = [(rounded_box(36, 3.8, 3.8, (0, 0, 0), r=1.8), white),
             (rounded_box(3.0, 2.0, 1.2, (17.5, 0, 0.6), r=0.9), GLASS_DARK),
             (box(9, 34, 0.5, (-1, 0, -0.6)), white),                 # wings
             (box(5, 11, 0.4, (-15.5, 0, 0.8)), white),               # tailplane
             (box(5, 0.5, 6, (-15.5, 0, 3.5)), blue),                 # fin
             (rounded_box(4, 1.6, 1.6, (1.5, 6.5, -1.6), r=0.7), blue),
             (rounded_box(4, 1.6, 1.6, (1.5, -6.5, -1.6), r=0.7), blue)]
    export("plane", parts)


AWNINGS = {"awning_red": (0.80, 0.24, 0.22), "awning_green": (0.24, 0.48, 0.36),
           "awning_navy": (0.22, 0.28, 0.48), "awning_mustard": (0.88, 0.68, 0.24)}
STRIPE_WHITE = (0.97, 0.95, 0.90)
WOOD = (0.55, 0.38, 0.24)
IRON = (0.16, 0.18, 0.19)


def slab(x0, x1, y0, y1, z0, z1, t=0.05):
    """Thin sloped panel from (x0, z0) at the wall to (x1, z1) at the front, spanning y0..y1."""
    L = math.hypot(x1 - x0, z1 - z0)
    m = trimesh.creation.box(extents=(L, y1 - y0, t))
    m.apply_transform(trimesh.transformations.rotation_matrix(math.atan2(z0 - z1, x1 - x0), (0, 1, 0)))
    m.apply_translation(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    return m


def shopfronts():
    """Ground-floor shopfront: the origin is the wall at street level and +X points out to the street.
    awning_*      a striped canopy 3.2 m wide, sloping from 3.4 m at the wall to 2.75 m, 1.4 m out.
    shop_glow     the shop window only, so it can glow warm at night."""
    W, n = 3.2, 8
    for name, rgb in AWNINGS.items():
        parts = []
        for i in range(n):
            y0 = -W / 2 + i * W / n
            col = rgb if i % 2 == 0 else STRIPE_WHITE
            parts.append((slab(0.02, 1.4, y0, y0 + W / n, 3.4, 2.75), col))
            parts.append((box(0.04, W / n, 0.28, (1.4, y0 + W / (2 * n), 2.62)), col))     # valance
        for y in (-W / 2 + 0.03, W / 2 - 0.03):                                           # side arms
            parts.append((slab(0.02, 1.38, y - 0.02, y + 0.02, 3.3, 2.78, t=0.04), IRON))
        parts.append((box(0.06, W + 0.3, 0.5, (0.03, 0, 3.75)), rgb))                        # fascia board
        export(name, parts)
    export("shop_glow", [(box(0.04, 2.8, 2.1, (0.05, 0, 1.35)), (1.0, 0.86, 0.60))])


def cafe_set():
    """Two bistro tables with chairs under a cream parasol, about 2.4 m across."""
    parts = []
    for y in (-0.8, 0.8):
        top = cyl(0.36, 0.04, 0.72, 18); top.apply_translation((0, y, 0)); parts.append((top, (0.93, 0.92, 0.88)))
        leg = cyl(0.03, 0.72); leg.apply_translation((0, y, 0)); parts.append((leg, IRON))
        for dx in (-0.5, 0.5):
            seat = box(0.36, 0.36, 0.05, (dx, y, 0.45)); parts.append((seat, WOOD))
            back = box(0.05, 0.36, 0.42, (dx + (0.18 if dx > 0 else -0.18), y, 0.68)); parts.append((back, WOOD))
            for lx in (-0.14, 0.14):
                for ly in (-0.14, 0.14):
                    parts.append((box(0.04, 0.04, 0.45, (dx + lx, y + ly, 0.22)), IRON))
    pole = cyl(0.03, 2.3); parts.append((pole, (0.85, 0.83, 0.78)))
    canopy = trimesh.creation.cone(radius=1.5, height=0.5, sections=10)
    canopy.apply_translation((0, 0, 2.05)); parts.append((canopy, (0.96, 0.93, 0.84)))
    export("cafe_set", parts)


def bench():
    """Park bench 1.8 m long, seat facing +X."""
    parts = []
    for i in range(3):
        parts.append((box(0.12, 1.8, 0.05, (0.15 - i * 0.15, 0, 0.45)), WOOD))
    for i in range(2):
        parts.append((box(0.04, 1.8, 0.11, (-0.26, 0, 0.62 + i * 0.16)), WOOD))
    for y in (-0.75, 0.75):
        parts.append((box(0.5, 0.06, 0.45, (0, y, 0.22)), IRON))
        parts.append((box(0.05, 0.06, 0.45, (-0.26, y, 0.66)), IRON))
    export("bench", parts)


def bicycle(y, frame_rgb, x=0.0):
    """A toy bike 1.7 m long along X, at lateral offset y."""
    parts = []
    for wx in (-0.55, 0.55):
        ring = trimesh.creation.annulus(r_min=0.27, r_max=0.33, height=0.05, sections=18)
        ring.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, (1, 0, 0)))
        ring.apply_translation((x + wx, y, 0.33))
        parts.append((ring, TYRE))
    parts.append((box(1.1, 0.05, 0.05, (x, y, 0.62)), frame_rgb))
    parts.append((slab(x - 0.55, x + 0.05, y - 0.025, y + 0.025, 0.33, 0.62, t=0.05), frame_rgb))
    parts.append((box(0.05, 0.05, 0.35, (x - 0.15, y, 0.78)), frame_rgb))
    parts.append((box(0.22, 0.12, 0.05, (x - 0.15, y, 0.95)), (0.15, 0.15, 0.15)))       # saddle
    parts.append((box(0.05, 0.05, 0.4, (x + 0.5, y, 0.82)), frame_rgb))
    parts.append((box(0.06, 0.5, 0.04, (x + 0.5, y, 1.02)), (0.15, 0.15, 0.15)))         # handlebar
    return parts


def bikes():
    """bike_rack: Sheffield stands with two parked bikes. bike_dock: a rental station with four blue bikes.
    Both run along X (the map turns them along the kerb)."""
    rack = []
    for x in (-1.2, 0, 1.2):
        rack.append((box(0.05, 0.05, 0.8, (x, -0.35, 0.4)), IRON))
        rack.append((box(0.05, 0.05, 0.8, (x, 0.35, 0.4)), IRON))
        rack.append((box(0.05, 0.75, 0.05, (x, 0, 0.8)), IRON))
    for x, rgb in ((-0.6, (0.80, 0.24, 0.22)), (0.6, (0.25, 0.45, 0.70))):
        for m, c in bicycle(0, rgb):
            m.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, (0, 0, 1)))
            m.apply_translation((x, 0, 0))
            rack.append((m, c))
    export("bike_rack", rack)
    blue = (0.20, 0.45, 0.80)
    dock = [(box(0.3, 0.3, 1.9, (0, -2.6, 0.95)), blue), (box(0.08, 0.7, 0.9, (0.12, -2.6, 1.3)), (0.95, 0.95, 0.95)),
            (box(0.2, 4.6, 0.12, (0, -0.3, 0.06)), (0.40, 0.42, 0.45))]
    for i in range(4):
        y = -1.6 + i * 1.0
        for m, c in bicycle(0, blue):
            m.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, (0, 0, 1)))
            m.apply_translation((0.0, y, 0))
            dock.append((m, c))
    export("bike_dock", dock)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lamp()
    signal()
    vehicles()
    people()
    tram()
    boats()
    plane()
    shopfronts()
    cafe_set()
    bench()
    bikes()
    print("ok")
