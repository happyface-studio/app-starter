"""Office floor plan, in art pixels. The app and the web preview both read the
manifest `pack.py` writes from this, so edit the layout here.

Coordinates are top-left of each sprite. Props are depth-sorted by their
bottom edge (`y + h`), the same rule the characters use with their feet.

    ┌───────────────────────────┬──────────────────────────────┐
    │ work corner: cooler,      │ kitchen: fridge, sink, coffee │  y 0..44 wall
    │ whiteboard, copier        │ table + chairs, sofa          │  y 44..112
    ├───────────────────────────┴──────────────────────────────┤
    │   desk 0        desk 1        desk 2                      │  y 112..248
    │   desk 3        desk 4        desk 5                      │
    ├───────────────────────────────────────────────────────────┤
    │ waiting sofa, chair         ▒door▒        reception        │  y 248..H
    └──────────────────────────────┘    └──────────────────────┘
"""

W, H = 192, 320
BORDER = 4
WALL_H = 44                  # cap + face + baseboard
FLOOR_TOP = WALL_H

# The kitchen is an alcove: a partition wall on its left, open towards the desks.
PARTITION_X = 86             # left edge of the 4px partition wall
KITCHEN_X = PARTITION_X + 4
KITCHEN_BOTTOM = 112
LOBBY_TOP = 250

# Floors, painted in order: (floor, x, y, w, h). See art.FLOORS.
ZONES = [
    ("office", 0, FLOOR_TOP, W, H - FLOOR_TOP),
    ("kitchen", KITCHEN_X, FLOOR_TOP, W - KITCHEN_X, KITCHEN_BOTTOM - FLOOR_TOP),
    ("lobby", 0, LOBBY_TOP, W, H - LOBBY_TOP),
]
# Wallpaper along the top wall: (wall, x from, x to). See art.WALLS.
WALL_SEGMENTS = [
    ("office", 0, PARTITION_X),
    ("kitchen", PARTITION_X, W),
]
# Entrance: a gap in the bottom wall.
DOOR_X, DOOR_W = 84, 24

# Always behind everyone: hangs on the wall or lies flat on the floor.
WALL_DECOR = [
    ("window_curtains", 8, 9),
    ("whiteboard_pie", 50, 11),
    ("picture_plant", 118, 13),
    ("picture_leaf", 132, 12),
]
FLOOR_DECOR = [
    ("rug_wide", 6, 286),
    ("doormat", 89, H - 26),
]

# Furniture with depth. (sprite, x, y). Animated sprites use their nominal frame box.
PROPS = [
    # work corner
    ("water_cooler", 6, 30),
    ("plant_tall", 22, 34),
    ("copier", 56, 42),
    ("plant_bush", 68, 88),
    # kitchen along the wall
    ("fridge", 92, 24),
    ("kitchen_counter", 114, 36),
    ("sink", 116, 28),
    ("espresso", 140, 26),
    ("cuckoo", 166, 4),
    ("drinks_fridge", 164, 37),
    # kitchen floor: a table for two and a sofa to put your feet up
    ("kitchen_chair_r", 93, 74),
    ("kitchen_table", 106, 81),
    ("kitchen_chair_l", 122, 74),
    ("sofa_small", 153, 84),
    # lobby
    ("sofa_blue", 8, 262),
    ("side_table", 58, 270),
    ("wait_chair", 75, 268),
    ("cat", 8, 96),
    ("reception", 122, 256),
    ("plant_pot", 108, 252),
]

# Six workstations, three columns by two rows. Seat order matches OfficeStore seats.
DESK = "desk_oak"
COLUMNS = [36, 96, 156]       # desk centre x
ROWS = [148, 210]             # desk top y
DESK_W, DESK_H = 41, 23
DESK_ITEMS = [None] * 6
# Which side of the desk a deskmate gets up on, per column: the gaps between desks.
EXIT_X = [66, 126, 126]

# Places to go. Deskmates ("staff") wander to these on a break; guests use theirs.
# x, y: where the feet end up. face: which way they look there. pose: idle, sit or read.
# Seats sit inside furniture, so they add `approach` (a free spot to walk to first) and
# `z` (draw order while seated, so they show on top of the chair or sofa).
POIS = {
    "cooler": {"who": "staff", "x": 13, "y": 66, "face": "up"},
    "copier": {"who": "staff", "x": 68, "y": 68, "face": "up"},
    "fridge": {"who": "staff", "x": 102, "y": 66, "face": "up"},
    "coffee": {"who": "staff", "x": 151, "y": 66, "face": "up"},
    "drinks": {"who": "staff", "x": 173, "y": 66, "face": "up"},
    "table_left": {"who": "staff", "x": 100, "y": 93, "face": "right", "pose": "sit", "z": 96, "approach": [100, 102]},
    "table_right": {"who": "staff", "x": 128, "y": 93, "face": "left", "pose": "sit", "z": 96, "approach": [128, 102]},
    "sofa_left": {"who": "staff", "x": 160, "y": 102, "face": "down", "z": 109, "approach": [160, 116]},
    "sofa_right": {"who": "staff", "x": 176, "y": 102, "face": "down", "z": 109, "approach": [176, 116]},
    "wait_sofa_left": {"who": "guest", "x": 20, "y": 284, "face": "down", "pose": "read", "z": 292, "approach": [20, 299]},
    "wait_sofa_right": {"who": "guest", "x": 44, "y": 284, "face": "down", "pose": "read", "z": 292, "approach": [44, 299]},
    "wait_chair": {"who": "guest", "x": 82, "y": 284, "face": "down", "z": 290, "approach": [82, 299]},
}

# Visitors come in through the door, check in at reception, wait, and leave.
GUESTS = {
    "outside": [96, H + 18],
    "inside": [96, H - 12],
    "desk": {"x": 154, "y": 306, "face": "up"},
}

# Collision boxes for path finding, on top of every prop's footprint.
BLOCKED = [
    (0, 0, W, FLOOR_TOP + 4),                               # top wall
    (0, 0, BORDER + 2, H),                                  # left wall
    (W - BORDER - 2, 0, BORDER + 2, H),                     # right wall
    (0, H - BORDER - 2, DOOR_X, BORDER + 2),                # bottom wall, left of the door
    (DOOR_X + DOOR_W, H - BORDER - 2, W, BORDER + 2),       # bottom wall, right of the door
    (PARTITION_X - 1, 0, 6, KITCHEN_BOTTOM - 8),            # kitchen partition
]
