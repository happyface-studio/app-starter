"""Which LimeZu sprites the office uses, and where they come from.

Paths are relative to the folder that holds LimeZu's "Modern_Office_Revamped" and
"Modern_Interiors_v41.3.4" packs (in Simon's setup: Game/Game Assets/Modern Pixel Art packs).
Rects are (x, y, w, h) in the 16x16 sheets.
"""

OFFICE = "Modern_Office_Revamped/Modern_Office_16x16.png"
MI = "Modern_Interiors_v41.3.4/"
GENERIC = MI + "1_Interiors/16x16/Theme_Sorter/1_Generic_16x16.png"
KITCHEN = MI + "1_Interiors/16x16/Theme_Sorter/12_Kitchen_16x16.png"
ROOM = MI + "1_Interiors/16x16/Room_Builder_16x16.png"
UI = MI + "4_User_Interface_Elements/UI_16x16.png"
ANIM = MI + "3_Animated_objects/16x16/spritesheets/"
UI_ANIM = MI + "4_User_Interface_Elements/Animated_Spritesheets/"
CHARS = MI + "2_Characters/Character_Generator/"

# name -> (sheet, rect). Single-frame props.
STATIC = {
    # desks (front view, 41x23)
    "desk_oak": (OFFICE, (114, 457, 41, 23)),
    "desk_olive": (OFFICE, (162, 457, 41, 23)),
    "desk_lilac": (OFFICE, (18, 489, 41, 23)),
    "desk_cork": (OFFICE, (66, 489, 41, 23)),
    "desk_pine": (OFFICE, (114, 489, 41, 23)),
    "chair": (OFFICE, (0, 135, 16, 23)),
    "chair_orange": (OFFICE, (0, 167, 16, 23)),
    "monitor_back": (OFFICE, (224, 140, 16, 15)),
    "monitor_back_white": (OFFICE, (224, 172, 16, 15)),
    "laptop": (OFFICE, (226, 248, 13, 16)),
    "desk_lamp": (OFFICE, (176, 241, 15, 17)),
    "phone_rotary": (GENERIC, (199, 664, 16, 14)),
    "phone_rotary_white": (GENERIC, (167, 664, 16, 14)),
    "plant_tall": (OFFICE, (96, 122, 16, 28)),
    "plant_small": (OFFICE, (96, 164, 16, 18)),
    "plant_snake": (OFFICE, (98, 204, 12, 26)),
    "plant_big": (GENERIC, (133, 905, 22, 30)),
    "plant_bush": (GENERIC, (240, 1021, 16, 25)),
    "plant_pot": (GENERIC, (224, 1011, 15, 19)),
    "shelf_plant": (OFFICE, (113, 200, 30, 30)),
    "shelf": (OFFICE, (113, 249, 30, 29)),
    "whiteboard_pie": (OFFICE, (145, 231, 30, 23)),
    "whiteboard_chart": (OFFICE, (145, 199, 30, 23)),
    "popart": (OFFICE, (4, 199, 24, 20)),
    "painting": (OFFICE, (241, 40, 14, 17)),
    "certificate": (OFFICE, (113, 138, 14, 16)),
    "water_cooler": (OFFICE, (193, 248, 14, 30)),
    "vending": (OFFICE, (37, 373, 23, 34)),
    "vending_drinks": (OFFICE, (5, 373, 23, 34)),
    "sofa": (OFFICE, (1, 276, 31, 24)),
    "armchair": (OFFICE, (0, 340, 16, 24)),
    "printer": (OFFICE, (128, 353, 15, 18)),
    "copier": (OFFICE, (131, 298, 25, 20)),
    "espresso": (KITCHEN, (209, 475, 22, 19)),
    "window": (GENERIC, (195, 695, 25, 20)),
    "window_curtains": (GENERIC, (182, 727, 35, 28)),
    "window_curtains_grey": (GENERIC, (134, 727, 35, 28)),
    "rug": (GENERIC, (3, 706, 43, 28)),
    "rug_wide": (GENERIC, (0, 738, 48, 28)),
    "tv_wall": (GENERIC, (53, 711, 22, 15)),
}

# name -> (sheet, frame w, frame h, frame count, fps). Animated sheets laid out in one row.
ANIMATED = {
    "mug": (ANIM + "animated_coffee.png", 16, 32, 6, 6),
    "cat": (ANIM + "animated_cat.png", 48, 16, 12, 5),
    "fishtank": (ANIM + "animated_fishtank_orange.png", 32, 32, 8, 5),
    "cuckoo": (ANIM + "animated_cuckoo_clock.png", 16, 32, 10, 5),
}

# Emote bubbles. name -> (list of (sheet, rect)) or a GIF, plus fps.
EMOTES = {
    "ring": ([(UI, (146, 11, 12, 14)), (UI, (162, 11, 12, 14))], 4),
    "speak": ([(UI, (2 + 16 * i, 202, 12, 15)) for i in range(8)], 8),
    "boss": ([(UI, (258, 10, 13, 15))], 1),
    "mail": ([(UI, (258, 42, 12, 14))], 1),
    "heart": ([(UI, (98, 11, 12, 14))], 1),
    "think": (UI_ANIM + "UI_thinking_emote_dots_16x16.gif", 8),
}

# Room builder blocks: wall face (3 tiles wide, 32 tall) and floor (3x2 tiles).
WALL = (ROOM, (352, 176 + 32 * 6, 48, 32))  # teal wall
FLOOR = (ROOM, (736, 560, 48, 32))  # walnut planks

# Character generator: frames we keep from each 896x656 layer sheet (16x32 frames).
CHAR_ROWS = [
    ("idle", 1, 24),   # 6 frames x right, up, left, down
    ("walk", 2, 24),
    ("phone", 6, 12),  # pull out phone, 3..8 loops, put away
]
DIRS = ["right", "up", "left", "down"]

ACCESSORIES = [  # curated, office friendly; (file stem, label)
    ("Accessory_15_Glasses", "Glasses"),
    ("Accessory_16_Monocle", "Monocle"),
    ("Accessory_12_Mustache", "Mustache"),
    ("Accessory_13_Beard", "Beard"),
    ("Accessory_11_Beanie", "Beanie"),
    ("Accessory_04_Snapback", "Cap"),
    ("Accessory_05_Dino_Snapback", "Dino cap"),
    ("Accessory_08_Detective_Hat", "Detective"),
    ("Accessory_19_Party_Cone", "Party hat"),
    ("Accessory_02_Bee", "Bee"),
    ("Accessory_01_Ladybug", "Ladybug"),
]

FONT = {
    "A": ["###", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": ["###", "#..", "#..", "#..", "###"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
    "G": ["###", "#..", "#.#", "#.#", "###"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", "###"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": ["###", "#.#", "#.#", "#.#", "###"], "P": ["###", "#.#", "###", "#..", "#.."],
    "Q": ["###", "#.#", "#.#", "###", "..#"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": ["###", "#..", "###", "..#", "###"], "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
    " ": ["...", "...", "...", "...", "..."], "-": ["...", "...", "###", "...", "..."],
    ".": ["...", "...", "...", "...", ".#."], "!": [".#.", ".#.", ".#.", "...", ".#."],
    "?": ["##.", "..#", ".#.", "...", ".#."], "'": [".#.", ".#.", "...", "...", "..."],
    "&": [".#.", "#.#", ".#.", "#.#", ".##"],
}
FOLD = {"Ä": "A", "Ö": "O", "Ü": "U", "ß": "S", "É": "E", "È": "E", "Á": "A", "À": "A", "Ç": "C", "Ñ": "N"}
