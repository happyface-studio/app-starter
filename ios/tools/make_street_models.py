"""Toy street furniture for the map, as small GLBs (metres, Y up).

  python3 ios/tools/make_street_models.py

lamp_post / lamp_glow   black London-style post; the lantern glass is its own model so it can glow at night.
signal_body             pole + housing.
signal_red / _green     the lit lens only, so emissive strength applies to the light and not the housing.
The arm, housing and lenses face +X; the map rotates each instance towards the road.
"""

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
    scene = trimesh.Scene()
    for i, (mesh, rgb) in enumerate(parts):
        scene.add_geometry(paint(y_up(mesh), rgb), node_name=f"{name}_{i}")
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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lamp()
    signal()
    vehicles()
    print("ok")
