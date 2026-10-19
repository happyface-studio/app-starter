"""Bakes an OSM extract into a stylised toy-city scene (GLB + JSON instance data).

Look target: cream/ochre walls with window rows, slate-blue mansard roofs, terracotta
chimneys, mauve roads with pale raised sidewalks, bright lawns, blue water, puffy trees.

  python3 ios/tools/bake_city.py ios/tools/osm/altstadt.json out_dir

Coordinates: metres, glTF Y-up, +X east, -Z north, origin at ORIGIN.
"""

import json
import math
import os
import random
import sys

import numpy as np
import trimesh
from PIL import Image, ImageDraw
from shapely import affinity
from shapely.geometry import LineString, MultiPolygon, Point, Polygon, box
from shapely.ops import unary_union
from trimesh.visual.material import PBRMaterial

ORIGIN = (50.1104, 8.6835)
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(ORIGIN[0]))
CLIP = box(-560, -480, 560, 480)  # x west..east, y south..north (planar, before Y-up swap)

rng = random.Random(7)
STATS = {'mansard': 0, 'flat': 0}


def to_xy(lat, lon):
    return ((lon - ORIGIN[1]) * M_LON, (lat - ORIGIN[0]) * M_LAT)


# ---------------------------------------------------------------- OSM parsing

def load(path):
    els = json.load(open(path))["elements"]
    ways, rels, nodes = [], [], []
    for e in els:
        if e["type"] == "way" and "geometry" in e:
            ways.append(e)
        elif e["type"] == "relation":
            rels.append(e)
        elif e["type"] == "node":
            nodes.append(e)
    return ways, rels, nodes


def way_coords(w):
    return [to_xy(p["lat"], p["lon"]) for p in w["geometry"] if p]


def way_polygon(w):
    c = way_coords(w)
    if len(c) < 4 or c[0] != c[-1]:
        if len(c) >= 3 and math.dist(c[0], c[-1]) < 0.5:
            c = c[:-1] + [c[0]]
        else:
            return None
    p = Polygon(c)
    if not p.is_valid:
        p = p.buffer(0)
    return p if not p.is_empty else None


def relation_polygon(r):
    outers, inners = [], []
    for m in r.get("members", []):
        if m.get("type") != "way" or "geometry" not in m:
            continue
        pts = [to_xy(p["lat"], p["lon"]) for p in m["geometry"] if p]
        (inners if m.get("role") == "inner" else outers).append(pts)
    # stitch open outer segments into rings
    rings = []
    segs = [s for s in outers if len(s) >= 2]
    while segs:
        ring = segs.pop(0)
        changed = True
        while changed and math.dist(ring[0], ring[-1]) > 0.5:
            changed = False
            for i, s in enumerate(segs):
                if math.dist(ring[-1], s[0]) < 0.5:
                    ring += s[1:]
                elif math.dist(ring[-1], s[-1]) < 0.5:
                    ring += s[::-1][1:]
                elif math.dist(ring[0], s[-1]) < 0.5:
                    ring = s[:-1] + ring
                elif math.dist(ring[0], s[0]) < 0.5:
                    ring = s[::-1][:-1] + ring
                else:
                    continue
                segs.pop(i)
                changed = True
                break
        if len(ring) >= 4:
            rings.append(Polygon(ring).buffer(0))
    if not rings:
        return None
    shape = unary_union(rings)
    for pts in inners:
        if len(pts) >= 4:
            shape = shape.difference(Polygon(pts).buffer(0))
    return shape


def polys(geom):
    if geom is None or geom.is_empty:
        return []
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    return [g for g in getattr(geom, "geoms", []) if isinstance(g, Polygon)]


# ---------------------------------------------------------------- mesh helpers

def to_yup(v2, y):
    return [v2[0], y, -v2[1]]


def flat_mesh(geom, y):
    """Triangulated horizontal surface (normal up) for a polygon / multipolygon."""
    parts = []
    for p in polys(geom):
        if p.area < 0.05:
            continue
        try:
            v, f = trimesh.creation.triangulate_polygon(p, engine="earcut")
        except Exception:
            continue
        v3 = np.column_stack([v[:, 0], np.full(len(v), y), -v[:, 1]])
        # earcut gives CCW in XY; after flipping Y->-Z the winding must face +Y
        m = trimesh.Trimesh(v3, f, process=False)
        parts.append(m)
    return trimesh.util.concatenate(parts) if parts else None


def slab_mesh(geom, y0, y1):
    """Extruded slab: top face plus side walls (for kerbs, lawns, cornices)."""
    parts = []
    top = flat_mesh(geom, y1)
    if top is not None:
        parts.append(top)
    for p in polys(geom):
        for ring in [p.exterior, *p.interiors]:
            parts.append(ring_walls(list(ring.coords), y0, y1, outward=ring is p.exterior)[0])
    parts = [p for p in parts if p is not None]
    return trimesh.util.concatenate(parts) if parts else None


def ring_walls(coords, y0, y1, outward=True, u_scale=1.0, v_scale=1.0):
    """Vertical quads along a ring. Returns (mesh, uv)."""
    ring = LineString(coords)
    pts = list(coords)
    if pts[0] != pts[-1]:
        pts.append(pts[0])
    ccw = Polygon(pts).exterior.is_ccw if len(pts) >= 4 else True
    if outward != ccw:
        pass
    verts, faces, uvs = [], [], []
    u = 0.0
    for a, b in zip(pts[:-1], pts[1:]):
        L = math.dist(a, b)
        if L < 0.05:
            continue
        i = len(verts)
        verts += [to_yup(a, y0), to_yup(b, y0), to_yup(b, y1), to_yup(a, y1)]
        uvs += [[u * u_scale, y0 * v_scale], [(u + L) * u_scale, y0 * v_scale],
                [(u + L) * u_scale, y1 * v_scale], [u * u_scale, y1 * v_scale]]
        # exterior rings from shapely are CCW (in XY); with Z=-Y that flips, so wind accordingly
        if (ccw and outward) or (not ccw and not outward):
            faces += [[i, i + 2, i + 1], [i, i + 3, i + 2]]
        else:
            faces += [[i, i + 1, i + 2], [i, i + 2, i + 3]]
        u += L
    if not faces:
        return None, None
    m = trimesh.Trimesh(np.array(verts), np.array(faces), process=False)
    return m, np.array(uvs)


def miter_inset(coords, d):
    """Offsets a closed CCW ring inward by d using mitred vertices (same vertex count)."""
    pts = np.array(coords[:-1] if coords[0] == coords[-1] else coords)
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e1 = p1 - p0
        e2 = p2 - p1
        if np.linalg.norm(e1) < 1e-6 or np.linalg.norm(e2) < 1e-6:
            out.append(p1)
            continue
        n1 = np.array([-e1[1], e1[0]]) / np.linalg.norm(e1)
        n2 = np.array([-e2[1], e2[0]]) / np.linalg.norm(e2)
        bis = n1 + n2
        bl = np.linalg.norm(bis)
        if bl < 1e-6:
            out.append(p1 + n1 * d)
            continue
        bis /= bl
        cos = max(np.dot(bis, n1), 0.35)
        out.append(p1 + bis * (d / cos))
    return [tuple(p) for p in out]


# ---------------------------------------------------------------- textures

def facade_texture(path, wall, trim, window, glass, brick=False):
    W = H = 128
    img = Image.new("RGB", (W, H), wall)
    d = ImageDraw.Draw(img)
    if brick:
        for y in range(0, H, 8):
            d.line([(0, y), (W, y)], fill=tuple(int(c * 0.92) for c in wall))
    # floor band
    d.rectangle([0, H - 10, W, H - 1], fill=trim)
    # window with frame, sill and lintel; one window per tile (tile = 3.2m x 3.2m)
    x0, x1, y0, y1 = 40, 88, 24, 96
    d.rectangle([x0 - 6, y0 - 6, x1 + 6, y0 - 1], fill=trim)
    d.rectangle([x0 - 4, y1, x1 + 4, y1 + 6], fill=trim)
    d.rectangle([x0, y0, x1, y1], fill=window)
    d.rectangle([x0 + 5, y0 + 5, x1 - 5, y1 - 5], fill=glass)
    d.line([((x0 + x1) // 2, y0 + 5), ((x0 + x1) // 2, y1 - 5)], fill=window, width=4)
    d.line([(x0 + 5, (y0 + y1) // 2 - 6), (x1 - 5, (y0 + y1) // 2 - 6)], fill=window, width=4)
    # soft highlight on glass
    d.polygon([(x0 + 8, y1 - 8), (x0 + 8, y0 + 30), (x0 + 22, y0 + 10)], fill=tuple(min(255, c + 45) for c in glass))
    img = img.transpose(Image.FLIP_TOP_BOTTOM)
    img.save(path)
    return img


def tex_material(img, name):
    return PBRMaterial(name=name, baseColorTexture=img, metallicFactor=0.0, roughnessFactor=0.92)


def srgb_to_linear(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color_material(rgb, name, rough=0.9):
    # glTF baseColorFactor is linear; the palette is authored in sRGB
    return PBRMaterial(name=name, baseColorFactor=[*(srgb_to_linear(c) for c in rgb), 1.0], metallicFactor=0.0, roughnessFactor=rough)


# ---------------------------------------------------------------- palette

PAL = {
    "land": (236, 220, 204),
    "plaza": (233, 207, 196),
    "road": (191, 138, 150),
    "road_major": (178, 124, 138),
    "kerb": (242, 230, 212),
    "path": (222, 196, 160),
    "grass": (124, 190, 70),
    "grass_edge": (232, 214, 182),
    "flower": (214, 54, 60),
    "water": (82, 168, 230),
    "bank": (210, 196, 172),
    "roof": (78, 92, 178),
    "roof_top": (128, 138, 200),
    "roof_flat": (128, 138, 200),
    "cornice": (248, 238, 220),
    "chimney": (204, 120, 84),
    "chimney_cap": (150, 90, 70),
    "bridge": (226, 214, 198),
}

WALLS = [
    ("wall_cream", (243, 224, 186), (252, 244, 228), (70, 86, 150), (104, 132, 196), False, 5),
    ("wall_sand", (232, 200, 152), (248, 234, 210), (70, 86, 150), (104, 132, 196), False, 4),
    ("wall_pale", (246, 236, 218), (255, 250, 240), (70, 86, 150), (110, 140, 200), False, 3),
    ("wall_brick", (196, 116, 92), (240, 222, 200), (64, 78, 140), (104, 132, 196), True, 1),
    ("wall_stone", (212, 130, 110), (236, 210, 190), (64, 78, 140), (104, 132, 196), False, 0),
]


def main(src, out):
    os.makedirs(out, exist_ok=True)
    ways, rels, nodes = load(src)

    groups = {k: [] for k in ["grass", "park", "water", "flower", "plaza", "construction"]}
    roads_by_w = []
    paths = []
    buildings = []
    tree_pts, lamp_pts, tree_lines = [], [], []

    for w in ways:
        t = w.get("tags", {})
        if "building" in t and t["building"] not in ("roof", "bridge", "construction"):
            p = way_polygon(w)
            if p is not None:
                buildings.append((p, t))
            continue
        if "highway" in t and t.get("area") != "yes":
            hw = t["highway"]
            line = LineString(way_coords(w))
            if t.get("tunnel") == "yes" or t.get("layer", "0").startswith("-"):
                continue
            widths = {"primary": 9, "secondary": 8, "tertiary": 6.5, "residential": 5.5, "living_street": 4.5,
                      "service": 3.6, "unclassified": 5, "primary_link": 6, "secondary_link": 6, "busway": 6}
            if hw in widths:
                roads_by_w.append((line, widths[hw], hw in ("primary", "secondary")))
            elif hw in ("pedestrian",):
                groups["plaza"].append(line.buffer(4.5, cap_style=2))
            elif hw in ("footway", "path", "cycleway", "steps"):
                paths.append(line.buffer(1.1 if hw != "cycleway" else 1.4, cap_style=1))
            continue
        p = way_polygon(w)
        if t.get("natural") == "tree_row":
            tree_lines.append(LineString(way_coords(w)))
            continue
        if p is None:
            continue
        if t.get("landuse") in ("grass", "meadow", "village_green", "cemetery") or t.get("leisure") in ("garden",):
            groups["grass"].append(p)
        elif t.get("leisure") == "park":
            groups["park"].append(p)
        elif t.get("landuse") == "flowerbed":
            groups["flower"].append(p)
        elif t.get("natural") == "water" or t.get("waterway") == "riverbank":
            groups["water"].append(p)
        elif t.get("place") == "square" or t.get("area:highway") or (t.get("highway") == "pedestrian"):
            groups["plaza"].append(p)
        elif t.get("amenity") == "fountain":
            groups["water"].append(p)
        elif t.get("landuse") == "construction":
            groups["construction"].append(p)
        elif t.get("natural") == "scrub":
            groups["grass"].append(p)

    for r in rels:
        t = r.get("tags", {})
        geom = None
        if "building" in t or t.get("natural") == "water" or t.get("waterway") == "riverbank":
            geom = relation_polygon(r)
        if geom is None:
            continue
        if "building" in t:
            for p in polys(geom):
                buildings.append((p, t))
        else:
            groups["water"].append(geom)

    for n in nodes:
        t = n.get("tags", {})
        xy = to_xy(n["lat"], n["lon"])
        if not CLIP.contains(Point(xy)):
            continue
        if t.get("natural") == "tree":
            tree_pts.append(xy)
        elif t.get("highway") == "street_lamp":
            lamp_pts.append(xy)

    clip = CLIP
    water = unary_union(groups["water"]).intersection(clip) if groups["water"] else None
    road_major = unary_union([l.buffer(w / 2, cap_style=2, join_style=2) for l, w, m in roads_by_w if m]).intersection(clip)
    road_minor = unary_union([l.buffer(w / 2, cap_style=2, join_style=2) for l, w, m in roads_by_w if not m]).intersection(clip)
    roads = unary_union([road_major, road_minor])
    if water is not None:
        roads = roads.difference(water.buffer(-0.5))  # bridges stay on top below
    kerbs = unary_union([l.buffer(w / 2 + 2.6, cap_style=2, join_style=2) for l, w, m in roads_by_w]).intersection(clip)
    plaza = unary_union(groups["plaza"]).intersection(clip) if groups["plaza"] else None
    grass = unary_union(groups["grass"] + groups["park"]).intersection(clip)
    path = unary_union(paths).intersection(clip) if paths else None
    bfoot = unary_union([b for b, _ in buildings]).buffer(0.2)

    scene = trimesh.Scene()

    def add(name, mesh, mat):
        if mesh is None or len(mesh.faces) == 0:
            return
        mesh.visual = trimesh.visual.TextureVisuals(material=mat)
        scene.add_geometry(mesh, node_name=name, geom_name=name)

    # ground layers, bottom to top
    land = clip.buffer(260)
    if groups["water"]:
        land = land.difference(unary_union(groups["water"]))
    add("land", flat_mesh(land, -0.02), color_material(PAL["land"], "land"))
    if water is not None:
        full_water = unary_union(groups["water"]).intersection(clip.buffer(260))
        bank = full_water.buffer(2.5).difference(full_water)
        add("water_bank", slab_mesh(bank, -1.2, 0.0), color_material(PAL["bank"], "bank"))
        add("water", flat_mesh(full_water, -0.9), color_material(PAL["water"], "water", 0.35))
    if plaza is not None:
        add("plaza", flat_mesh(plaza.difference(bfoot), 0.01), color_material(PAL["plaza"], "plaza"))
    lawn = grass.difference(roads.buffer(0.5)).difference(bfoot)
    if water is not None:
        lawn = lawn.difference(water)
    lawn_edge = lawn.buffer(0.0).difference(lawn.buffer(-1.2))
    add("lawn_edge", slab_mesh(lawn_edge, 0.0, 0.16), color_material(PAL["grass_edge"], "lawn_edge"))
    add("lawn", slab_mesh(lawn.buffer(-1.2), 0.0, 0.22), color_material(PAL["grass"], "grass"))
    if path is not None:
        add("paths", flat_mesh(path.intersection(lawn), 0.235), color_material(PAL["path"], "path"))
    if groups["flower"]:
        flowers = unary_union(groups["flower"]).intersection(lawn)
        add("flowers", slab_mesh(flowers.buffer(-0.4), 0.2, 0.42), color_material(PAL["flower"], "flower"))
    kerb_area = kerbs.difference(roads).difference(bfoot)
    if water is not None:
        kerb_area = kerb_area.difference(water)
    add("kerbs", slab_mesh(kerb_area, 0.0, 0.14), color_material(PAL["kerb"], "kerb"))
    road_surface = road_minor.difference(road_major)
    add("roads", flat_mesh(road_surface, 0.03), color_material(PAL["road"], "road"))
    add("roads_major", flat_mesh(road_major, 0.035), color_material(PAL["road_major"], "road_major"))

    # centre-line dashes on major roads
    dashes = []
    for l, w, m in roads_by_w:
        if not m or l.length < 8:
            continue
        s = 0.0
        while s < l.length - 3:
            seg = LineString([l.interpolate(s), l.interpolate(s + 2.2)])
            dashes.append(seg.buffer(0.18, cap_style=2))
            s += 6.0
    if dashes:
        dash = unary_union(dashes).intersection(road_major)
        add("road_dashes", flat_mesh(dash, 0.05), color_material((246, 232, 236), "dash"))

    # ------------------------------------------------------------ buildings
    wall_imgs = {}
    for name, wall, trim, win, glass, brick, _ in WALLS:
        wall_imgs[name] = facade_texture(os.path.join(out, f"{name}.png"), wall, trim, win, glass, brick)
    wall_names = [w[0] for w in WALLS]
    wall_weights = [w[6] for w in WALLS]

    wall_parts = {n: ([], []) for n in wall_names}
    roofs, roof_tops, roof_flat, cornices, chimneys, caps = [], [], [], [], [], []
    labels_out = []
    FLOOR = 3.2

    for p, t in buildings:
        if not clip.intersects(p) or p.area < 12:
            continue
        p = p.intersection(clip)
        for poly in polys(p):
            poly = poly.simplify(0.25)
            if poly.area < 12 or not isinstance(poly, Polygon):
                continue
            try:
                levels = float(t.get("building:levels", "0").split(";")[0])
            except ValueError:
                levels = 0
            kind = t.get("building")
            if levels <= 0:
                levels = {"church": 6, "cathedral": 8, "garages": 1, "service": 1, "hut": 1}.get(kind, rng.choice([4, 4, 5, 5, 6]))
            h = float(t["height"]) if t.get("height", "").replace(".", "", 1).isdigit() else levels * FLOOR + 0.6
            h = min(h, 40)
            if kind in ("church", "cathedral", "monastery"):
                wall = "wall_stone"
            else:
                wall = rng.choices(wall_names[:4], wall_weights[:4])[0]
            ext = list(poly.exterior.coords)
            if not Polygon(ext).exterior.is_ccw:
                ext = ext[::-1]
            m, uv = ring_walls(ext, 0.0, h, outward=True, u_scale=1 / FLOOR, v_scale=1 / FLOOR)
            if m is not None:
                wall_parts[wall][0].append(m)
                wall_parts[wall][1].append(uv)
            for hole in poly.interiors:
                m, uv = ring_walls(list(hole.coords), 0.0, h, outward=False, u_scale=1 / FLOOR, v_scale=1 / FLOOR)
                if m is not None:
                    wall_parts[wall][0].append(m)
                    wall_parts[wall][1].append(uv)

            # cornice band
            corn = poly.buffer(0.35, join_style=2).difference(poly.buffer(-0.3, join_style=2))
            cm = slab_mesh(corn, h - 0.45, h + 0.05)
            if cm is not None:
                cornices.append(cm)

            # mansard roof: sloped skirt from the eave to a mitred inset ring, flat top
            flat = t.get("roof:shape") == "flat" and poly.area > 900
            depth = min(3.4, math.sqrt(poly.area) * 0.2)
            rise = depth * 1.35
            inner = miter_inset(ext, depth)
            inner_poly = Polygon(inner) if inner and len(inner) >= 3 else None
            ok = (not flat and inner_poly is not None and inner_poly.is_valid and inner_poly.area > 4
                  and inner_poly.exterior.is_ccw and poly.buffer(-depth * 0.6).contains(inner_poly.representative_point()))
            top_y = h + 0.05
            STATS['mansard' if ok else 'flat'] += 1
            if ok:
                outer = ext[:-1] if ext[0] == ext[-1] else ext
                verts, faces = [], []
                n = len(outer)
                for i in range(n):
                    verts.append(to_yup(outer[i], top_y))
                for i in range(n):
                    verts.append(to_yup(inner[i], top_y + rise))
                for i in range(n):
                    j = (i + 1) % n
                    faces += [[i, n + j, j], [i, n + i, n + j]]
                skirt = trimesh.Trimesh(np.array(verts), np.array(faces), process=False)
                roofs.append(skirt)
                top_area = inner_poly
                for hole in poly.interiors:
                    hp = Polygon(hole)
                    top_area = top_area.difference(hp.buffer(depth * 0.5, join_style=2))
                    # courtyard edge: flat cap ring from the eave to the slope top
                    ring = hp.buffer(depth * 0.5, join_style=2).difference(hp).intersection(poly)
                    rc = slab_mesh(ring, top_y - 0.1, top_y + rise)
                    if rc is not None:
                        roofs.append(rc)
                cap = flat_mesh(top_area, top_y + rise)
                if cap is not None:
                    roof_tops.append(cap)
                roof_top = top_area if isinstance(top_area, Polygon) else inner_poly
                roof_y = top_y + rise
            elif not flat and poly.buffer(-depth, join_style=2).area > 4:
                # concave footprints: stepped mansard (two slabs) reads as a roof without a straight skeleton
                lower = poly.buffer(-0.2, join_style=2)
                upper = poly.buffer(-depth, join_style=2)
                for geom_, y0_, y1_, bucket in ((lower, top_y - 0.1, top_y + rise * 0.55, roofs), (upper, top_y, top_y + rise, roofs)):
                    sm = slab_mesh(geom_, y0_, y1_)
                    if sm is not None:
                        bucket.append(sm)
                tc = flat_mesh(upper, top_y + rise + 0.01)
                if tc is not None:
                    roof_tops.append(tc)
                roof_top = upper if isinstance(upper, Polygon) else None
                roof_y = top_y + rise
            else:
                cap = slab_mesh(poly.buffer(-0.3, join_style=2), top_y - 0.1, top_y + 0.35)
                if cap is not None:
                    roof_flat.append(cap)
                roof_top = poly.buffer(-1.0)
                roof_y = top_y + 0.35

            # chimneys
            if roof_top is not None and not roof_top.is_empty and roof_top.area > 6:
                count = 1 + int(roof_top.area // 60)
                count = min(count, 4)
                minx, miny, maxx, maxy = roof_top.bounds
                tries = 0
                while count > 0 and tries < 20:
                    tries += 1
                    c = Point(rng.uniform(minx, maxx), rng.uniform(miny, maxy))
                    if not roof_top.contains(c):
                        continue
                    count -= 1
                    s = rng.uniform(0.7, 1.0)
                    hh = rng.uniform(1.2, 2.0)
                    ch = trimesh.creation.box(extents=[s, hh, s * 0.8])
                    ch.apply_translation([c.x, roof_y + hh / 2 - 0.1, -c.y])
                    chimneys.append(ch)
                    cp = trimesh.creation.box(extents=[s + 0.25, 0.22, s * 0.8 + 0.25])
                    cp.apply_translation([c.x, roof_y + hh - 0.05, -c.y])
                    caps.append(cp)

    for name, (meshes, uvs) in wall_parts.items():
        if not meshes:
            continue
        m = trimesh.util.concatenate(meshes)
        m.visual = trimesh.visual.TextureVisuals(uv=np.vstack(uvs), material=tex_material(wall_imgs[name], name))
        scene.add_geometry(m, node_name=name, geom_name=name)
    add("cornice", trimesh.util.concatenate(cornices) if cornices else None, color_material(PAL["cornice"], "cornice"))
    add("roofs", trimesh.util.concatenate(roofs) if roofs else None, color_material(PAL["roof"], "roof", 0.7))
    add("roof_tops", trimesh.util.concatenate(roof_tops) if roof_tops else None, color_material(PAL["roof_top"], "roof_top", 0.8))
    add("roofs_flat", trimesh.util.concatenate(roof_flat) if roof_flat else None, color_material(PAL["roof_flat"], "roof_flat"))
    add("chimneys", trimesh.util.concatenate(chimneys) if chimneys else None, color_material(PAL["chimney"], "chimney"))
    add("chimney_caps", trimesh.util.concatenate(caps) if caps else None, color_material(PAL["chimney_cap"], "chimney_cap"))

    scene.export(os.path.join(out, "city.glb"))

    # ------------------------------------------------------------ instances
    trees = list(tree_pts)
    for l in tree_lines:
        s = 0.0
        while s < l.length:
            pt = l.interpolate(s)
            trees.append((pt.x, pt.y))
            s += 9.0
    # scatter in larger lawns/parks
    for g in polys(lawn):
        if g.area < 150:
            continue
        minx, miny, maxx, maxy = g.bounds
        target = int(g.area / 120)
        tries = 0
        while target > 0 and tries < target * 6:
            tries += 1
            x, y = rng.uniform(minx, maxx), rng.uniform(miny, maxy)
            if g.buffer(-2).contains(Point(x, y)) and (path is None or not path.buffer(1.5).contains(Point(x, y))):
                trees.append((x, y))
                target -= 1
    # avenue trees along both kerbs of the bigger roads
    for l, w, major in roads_by_w:
        if w < 6 or l.length < 20:
            continue
        for side in (1, -1):
            try:
                off = l.parallel_offset(w / 2 + 1.6, "left" if side > 0 else "right", join_style=2)
            except Exception:
                continue
            for seg in getattr(off, "geoms", [off]):
                s_ = 4.0
                while s_ < seg.length:
                    pt = seg.interpolate(s_)
                    if not bfoot.buffer(3.5).contains(pt):
                        trees.append((pt.x, pt.y))
                    s_ += 11.0
    blocked = bfoot.buffer(1.5)
    if water is not None:
        blocked = blocked.union(water)
    blocked = blocked.union(roads.buffer(-0.5))
    seen, tree_out = set(), []
    for x, y in trees:
        k = (round(x / 4), round(y / 4))
        if k in seen or not CLIP.contains(Point(x, y)) or blocked.contains(Point(x, y)):
            continue
        seen.add(k)
        tree_out.append([round(x, 2), round(-y, 2), rng.choice([0, 0, 1, 1, 2, 3]), round(rng.uniform(0.85, 1.35), 2), round(rng.uniform(0, 6.28), 2)])
    lamps = [[round(x, 2), round(-y, 2)] for x, y in lamp_pts if not bfoot.contains(Point(x, y))]

    json.dump({"trees": tree_out, "lamps": lamps, "origin": ORIGIN}, open(os.path.join(out, "instances.json"), "w"), separators=(",", ":"))
    print(STATS)
    print("buildings", len(buildings), "trees", len(tree_out), "lamps", len(lamps), "glb", os.path.getsize(os.path.join(out, "city.glb")))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
