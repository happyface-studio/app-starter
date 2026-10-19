"""Generates the puffy tree models used by the map's custom 3D tree layer.

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
    lo = np.array(green) * 0.55
    hi = np.minimum(np.array(green) * 1.15, 1.0)
    rgb = lo[None, :] * (1 - t[:, None]) + hi[None, :] * t[:, None]
    srgb = np.clip(rgb ** (1 / 2.2), 0, 1)
    rgba = np.column_stack([srgb * 255, np.full(len(y), 255)]).astype(np.uint8)
    mesh.visual = trimesh.visual.ColorVisuals(mesh, vertex_colors=rgba)


def tree(name, seed, green, height=4.2, spread=3.0, puffs=5, trunk_h=2.6):
    rng = np.random.default_rng(seed)
    scene = trimesh.Scene()
    c = crown(rng, height, spread, puffs)
    shade_crown(c, green, height - spread * 0.6, height + spread * 0.8)
    t = trunk(trunk_h, 0.32 * spread / 3.0)
    t.visual = trimesh.visual.TextureVisuals(material=material(TRUNK))
    scene.add_geometry(t, node_name="trunk")
    scene.add_geometry(c, node_name="crown")
    scene.export(os.path.join(OUT, f"{name}.glb"), include_normals=True)


def bush(name, seed, green):
    rng = np.random.default_rng(seed)
    scene = trimesh.Scene()
    c = crown(rng, 0.9, 1.3, 4)
    shade_crown(c, green, 0.1, 2.0)
    scene.add_geometry(c, node_name="crown")
    scene.export(os.path.join(OUT, f"{name}.glb"), include_normals=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    tree("tree_a", 1, (0.56, 0.60, 0.31))
    tree("tree_b", 7, (0.45, 0.55, 0.26), height=4.8, spread=3.4, puffs=6)
    tree("tree_c", 13, (0.62, 0.66, 0.36), height=3.8, spread=2.6, puffs=4, trunk_h=2.2)
    bush("bush_a", 21, (0.50, 0.58, 0.30))
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)))
