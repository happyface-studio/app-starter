"""Office floor plan, in art pixels. The app and the web preview both read the
manifest `pack.py` writes from this, so edit the layout here.

Coordinates are top-left of each sprite. Props are depth-sorted by their
bottom edge (`y + h`), the same rule the characters use with their feet.
"""

W, H = 192, 304
BORDER = 4
WALL_H = 44                  # cap + face + baseboard
FLOOR_TOP = WALL_H

# Always behind everyone: hangs on the wall or lies flat on the floor.
WALL_DECOR = [
    ("window_curtains", 10, 9),
    ("whiteboard_pie", 58, 11),
    ("popart", 96, 12),
    ("window_curtains", 147, 9),
]
FLOOR_DECOR = [
    ("rug_wide", 72, 256),
]

# Furniture with depth. (sprite, x, y). Animated sprites use their nominal frame box.
PROPS = [
    ("water_cooler", 8, 30),
    ("plant_tall", 23, 34),
    ("cuckoo", 126, 6),
    ("vending", 164, 28),
    ("plant_bush", 88, 108),
    ("printer", 89, 176),
    ("sofa", 12, 260),
    ("armchair", 46, 262),
    ("cat", 72, 266),
    ("shelf_plant", 124, 258),
    ("fishtank", 156, 254),
    ("plant_pot", 6, 282),
    ("plant_snake", 174, 272),
]

# Six workstations, two columns by three rows. Seat order matches OfficeStore seats.
DESK = "desk_oak"
COLUMNS = [52, 140]          # desk centre x
ROWS = [81, 145, 209]         # desk top y
DESK_W, DESK_H = 41, 23
DESK_ITEMS = [None] * 6

# Where idle deskmates wander to: feet position and which way they face there.
POIS = {
    "cooler": {"x": 15, "y": 66, "face": "up"},
    "vending": {"x": 175, "y": 68, "face": "up"},
    "window": {"x": 148, "y": 54, "face": "up"},
    "cat": {"x": 96, "y": 258, "face": "down"},
}

# Collision boxes for path finding, on top of every prop's footprint.
BLOCKED = [
    (0, 0, W, FLOOR_TOP + 4),          # wall
    (0, 0, BORDER + 2, H),             # left border
    (W - BORDER - 2, 0, BORDER + 2, H),
    (0, H - BORDER - 2, W, BORDER + 2),
]
