"""Generates the puffy tree models used by the map's custom 3D tree layer.

Each tree comes in four seasons: tree_a.glb (summer), tree_a_autumn.glb, tree_a_winter.glb
(bare branches) and tree_a_spring.glb. The app picks the season from the date.

Run: python3 ios/tools/make_trees.py  (needs trimesh + numpy)
Writes tree_*.glb into ios/Targets/ExploreKit/Resources/Models.
Models are glTF Y-up, metres, origin at the base of the trunk.
"""

import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = os.path.join(os.path.dirname(__file__), "..", "Targets", "ExploreKit", "Resources", "Models")

TRUNK = (0.47, 0.27, 0.18)


def material(rgb, roughness=0.9):
    return PBRMaterial(
        baseColorFactor=[*rgb, 1.0],
        metallicFactor=0.0,
        roughnessFactor=roughness,
        doubleSided=False,
    )


def puff(center, radius, rng, subdiv=3):
    sphere = trimesh.creation.icosphere(subdivisions=subdiv, radius=radius)
    v = sphere.vertices
    n = v / np.linalg.norm(v, axis=1, keepdims=True)
    # low-frequency lumps so each puff reads as soft foliage, not a ball
    k = rng.normal(size=(3, 3))
    bumps = np.sin(n @ k * 2.3).sum(axis=1) / 3.0
    sphere.vertices = v + n * (bumps[:, None] * radius * 0.07)
    sphere.vertices[:, 1] *= 0.92
    sphere.apply_translation(center)
    return sphere


def crown(rng, height, spread, count):
    parts = [puff((0, height, 0), spread * 0.62, rng)]
    for i in range(count):
        a = i / count * 2 * np.pi + rng.uniform(-0.3, 0.3)
        r = spread * rng.uniform(0.38, 0.55)
        y = height + rng.uniform(-0.45, 0.25) * spread
        parts.append(puff((np.cos(a) * r, y, np.sin(a) * r), spread * rng.uniform(0.42, 0.52), rng))
    parts.append(puff((rng.uniform(-0.2, 0.2) * spread, height + spread * 0.48, 0), spread * 0.45, rng))
    mesh = trimesh.util.concatenate(parts)
    mesh.merge_vertices()
    return mesh


def trunk(height, radius):
    t = trimesh.creation.cone(radius=radius, height=height * 1.6, sections=10)
    t.vertices[:, 2] = np.minimum(t.vertices[:, 2], height)
    t.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, (1, 0, 0)))
    return t


def shade_crown(mesh, green, y0, y1):
    """Vertex colours: darker, cooler underside to a sunlit top (the clay-foliage look)."""
    y = mesh.vertices[:, 1]
    t = np.clip((y - y0) / max(y1 - y0, 1e-3), 0, 1)
    t = t * t * (3 - 2 * t)
    # `green` is the sunlit top in sRGB; the underside goes to a deep olive like the reference trees.
    lo = np.array(green) * 0.5
    hi = np.minimum(np.array(green) * 1.06, 1.0)
    rgb = lo[None, :] * (1 - t[:, None]) + hi[None, :] * t[:, None]
    srgb = np.clip(rgb, 0, 1)
    rgba = np.column_stack([srgb * 255, np.full(len(y), 255)]).astype(np.uint8)
    mesh.visual = trimesh.visual.ColorVisuals(mesh, vertex_colors=rgba)


BARK = (0.42, 0.33, 0.27)


def branches(rng, trunk_h, height, spread):
    """Bare winter crown: a few chunky limbs fanning out of the trunk top, each with two twigs."""
    parts = []
    top = np.array([0, trunk_h * 0.92, 0])
    n = 6
    for i in range(n):
        a = i / n * 2 * np.pi + rng.uniform(-0.35, 0.35)
        out = spread * rng.uniform(0.45, 0.62)
        end = np.array([np.cos(a) * out, height + rng.uniform(-0.2, 0.6) * spread * 0.5, np.sin(a) * out])
        parts.append(trimesh.creation.cylinder(radius=0.09 * spread / 3, segment=[top, end], sections=6))
        for _ in range(2):
            tw = end + np.array([rng.uniform(-0.5, 0.5), rng.uniform(0.3, 0.8), rng.uniform(-0.5, 0.5)]) * spread * 0.35
            parts.append(trimesh.creation.cylinder(radius=0.045 * spread / 3, segment=[end, tw], sections=5))
    m = trimesh.util.concatenate(parts)
    rgba = np.tile(np.array([*(np.array(BARK) * 255), 255], dtype=np.uint8), (len(m.vertices), 1))
    m.visual = trimesh.visual.ColorVisuals(m, vertex_colors=rgba)
    return m


def tree(name, seed, green, height=4.2, spread=3.0, puffs=5, trunk_h=2.6, bare=False):
    rng = np.random.default_rng(seed)
    scene = trimesh.Scene()
    t = trunk(trunk_h, 0.32 * spread / 3.0)
    t.visual = trimesh.visual.TextureVisuals(material=material(TRUNK))
    scene.add_geometry(t, node_name="trunk")
    if bare:
        scene.add_geometry(branches(rng, trunk_h, height, spread), node_name="branches")
    else:
        c = crown(rng, height, spread, puffs)
        shade_crown(c, green, height - spread * 0.6, height + spread * 0.8)
        scene.add_geometry(c, node_name="crown")
    scene.export(os.path.join(OUT, f"{name}.glb"), include_normals=True)


def bush(name, seed, green, scale=1.0):
    rng = np.random.default_rng(seed)
    scene = trimesh.Scene()
    c = crown(rng, 0.9 * scale, 1.3 * scale, 4)
    shade_crown(c, green, 0.1, 2.0 * scale)
    scene.add_geometry(c, node_name="crown")
    scene.export(os.path.join(OUT, f"{name}.glb"), include_normals=True)


TREES = {  # name: (seed, shape kwargs)
    "tree_a": (1, {}),
    "tree_b": (7, dict(height=4.8, spread=3.4, puffs=6)),
    "tree_c": (13, dict(height=3.8, spread=2.6, puffs=4, trunk_h=2.2)),
}

SEASONS = {  # suffix: crown colour per model (sunlit top, sRGB); None = bare
    "": {"tree_a": (0.60, 0.65, 0.33), "tree_b": (0.52, 0.60, 0.29), "tree_c": (0.66, 0.68, 0.36), "bush_a": (0.56, 0.63, 0.30)},
    "_autumn": {"tree_a": (0.82, 0.56, 0.26), "tree_b": (0.84, 0.70, 0.32), "tree_c": (0.70, 0.36, 0.22), "bush_a": (0.64, 0.56, 0.28)},
    "_winter": {"tree_a": None, "tree_b": None, "tree_c": None, "bush_a": (0.46, 0.44, 0.33)},
    "_spring": {"tree_a": (0.70, 0.80, 0.40), "tree_b": (0.62, 0.76, 0.36), "tree_c": (0.97, 0.78, 0.83), "bush_a": (0.66, 0.76, 0.36)},
}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for suffix, colours in SEASONS.items():
        for name, (seed, kw) in TREES.items():
            tree(name + suffix, seed, colours[name] or (0, 0, 0), bare=colours[name] is None, **kw)
        bush("bush_a" + suffix, 21, colours["bush_a"], scale=0.85 if suffix == "_winter" else 1.0)
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)))
