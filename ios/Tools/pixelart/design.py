"""Deskmates pixel art — single source of truth.

Sprites are string grids; each char is a palette role, '.' is transparent.
`gen_swift.py` / `gen_js.py` turn this into Swift and JS so the app and the web
preview draw exactly the same pixels.
"""

# ---------------------------------------------------------------------------
# Palette (fixed roles). Character roles s/S, h/H, c/C are filled per look.
# ---------------------------------------------------------------------------
FIXED = {
    "k": "#2B1F2E",  # outline plum
    "e": "#2B1F2E",  # eyes
    "m": "#7A2E35",  # mouth line
    "r": "#C9474F",  # mouth inside
    "b": "#F2A3A0",  # blush
    "g": "#3C4150",  # headset
    "G": "#7D8496",  # headset light
    "l": "#2B1F2E",  # glasses frame
    "w": "#F6F1E6",  # white
    # props
    "p": "#E4574A",  # phone coral
    "P": "#B23E33",  # phone shade
    "o": "#5C5357",  # lamp off
    "u": "#D9CFB8",  # monitor putty
    "U": "#B4A98F",  # monitor shade
    "y": "#F4D35E",  # sticky note
    "Y": "#D9B43E",
    "d": "#C98B3F",  # desk oak
    "D": "#9C6A2C",  # desk front
    "q": "#7A5020",  # desk shadow edge
    "n": "#E0BC62",  # brass plate
    "N": "#A88536",  # brass shade
    "t": "#4A3518",  # engraving
    "f": "#7083B8",  # partition fabric
    "F": "#5A6C9E",  # partition shade
    "T": "#C9CBD3",  # partition trim
    "a": "#2D3557",  # chair
    "A": "#3E4870",  # chair light
    "v": "#5FA86A",  # plant
    "V": "#3F7F4C",
    "z": "#B5653A",  # pot
    "Z": "#8E4A28",
    "M": "#F6F1E6",  # mug
    "x": "#8C6248",  # coffee
}

SKIN = [  # (s, S)
    ("#F6D2B4", "#E2AE8C"),
    ("#EDB88B", "#D2996B"),
    ("#C98E5E", "#AA7144"),
    ("#9C6440", "#7E4C2E"),
    ("#6E4428", "#55331D"),
]
HAIR = [  # (h, H)
    ("#2E2633", "#1C1720"),  # black
    ("#6B4127", "#4E2E1B"),  # brown
    ("#B14D2E", "#86371F"),  # copper
    ("#E7C76B", "#C6A246"),  # blonde
    ("#BDBAC4", "#918E9A"),  # silver
    ("#5476D8", "#3A57AE"),  # blue
    ("#EA82AE", "#C65F8D"),  # pink
]
SHIRT = [  # (c, C)
    ("#E8A33D", "#C1822A"),  # mustard
    ("#2F9C90", "#22766C"),  # teal
    ("#9C88D8", "#7A66B6"),  # lilac
    ("#EEEBE4", "#C8C4BA"),  # white
    ("#5BA661", "#438548"),  # green
    ("#3D4F86", "#2B3A66"),  # navy
    ("#E4574A", "#B23E33"),  # coral
    ("#3B3641", "#27232C"),  # charcoal
]

# Scene colors
CARPET = "#1F4D57"
CARPET_DOT = "#25596A"
CARPET_DARK = "#1A424B"
WALL = "#A7BFB0"
WALL_SHADE = "#93AD9D"
BASEBOARD = "#6B5A4A"
SKY = {
    "day": ("#8ED3F2", "#BFE8FA"),
    "dusk": ("#F2A35E", "#F6C98A"),
    "night": ("#1E2B57", "#2E3E73"),
}
AMBER = "#F4B23E"
MINT = "#74E0B0"

# ---------------------------------------------------------------------------
# Character: 16 x 18. Base + face + hair + accessory layers.
# ---------------------------------------------------------------------------
BODY = [
    "................",
    "................",
    "....kkkkkkkk....",
    "...ksssssssSk...",
    "...ksssssssSk...",
    "...ksssssssSk...",
    "..kSsssssssSSk..",
    "...ksssssssSk...",
    "...ksssssssSk...",
    "...ksssssssSk...",
    "....kSsssssk....",
    ".....kkkkkk.....",
    "......kSSk......",
    "...kkkcSScckk...",
    "..kccccSSccccCk.",
    ".kcccccccccccCk.",
    ".kCcccccccccCCk.",
    ".kCcccccccccCCk.",
]

FACE = [
    "................",
    "................",
    "................",
    "................",
    "................",
    ".....e....e.....",
    ".....e....e.....",
    "................",
    "....b......b....",
    ".......mm.......",
    "................",
    "................",
]
FACE_BLINK = [
    "................",
    "................",
    "................",
    "................",
    "................",
    ".....s....s.....",
    ".....e....e.....",
    "................",
    "....b......b....",
    ".......mm.......",
    "................",
    "................",
]
MOUTH_OPEN = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "......kmmk......",
    ".......rr.......",
    "................",
]

HAIR_STYLES = {
    "short": [
        "................",
        ".....kkkkkk.....",
        "....khhhhhhk....",
        "...khhhhhhhHk...",
        "...khhhhHhhhk...",
        "...kh......hk...",
    ],
    "bob": [
        "................",
        ".....kkkkkk.....",
        "....khhhhhhk....",
        "...khhhhhhhHk...",
        "..khhhHhhhhhHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..kkh......hkk..",
        "...kk......kk...",
    ],
    "bun": [
        "......kkkk......",
        ".....khhHhk.....",
        "....kkhhhhkk....",
        "...khhhhhhhHk...",
        "...khHhhhhhhk...",
        "...kh......hk...",
    ],
    "curly": [
        "....kkkkkkkk....",
        "...khhhHhhhhk...",
        "..khhHhhhhHhhk..",
        ".khhhhhhhhhhHhk.",
        ".khHhhhhhhhhhHk.",
        ".khh........hHk.",
        ".khh........hHk.",
        ".kkh........hkk.",
        "..kk........kk..",
    ],
    "buzz": [
        "................",
        "................",
        "....kkkkkkkk....",
        "...khHhHhHhHk...",
    ],
    "long": [
        "................",
        ".....kkkkkk.....",
        "....khhhhhhk....",
        "...khhhhhhhHk...",
        "..khhhhHhhhhHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khh......hHk..",
        "..khk......khk..",
        "..kk........kk..",
    ],
}
HAIR_ORDER = ["short", "bob", "bun", "curly", "buzz", "long"]

ACCESSORIES = {
    "none": [],
    "headset": [
        "................",
        "................",
        "................",
        "................",
        "................",
        "..kk........kk..",
        ".kGgk......kgGk.",
        ".kggk......kggk.",
        "..kk........kk..",
        "...gg...........",
        "....ggG.........",
    ],
    "glasses": [
        "................",
        "................",
        "................",
        "................",
        "................",
        "....lll..lll....",
        "....l.llll.l....",
        "....lll..lll....",
    ],
    "bow": [
        "..........kk.kk.",
        ".........kpkkpk.",
        "..........kk.kk.",
    ],
}
ACCESSORY_ORDER = ["headset", "glasses", "none", "bow"]

# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
PHONE = [
    "..kkkkkk..",
    ".kppppppk.",
    "kpPk..kPpk",
    "kkppppppkk",
    "kpwpwpwopk",
    "kPPPPPPPPk",
    ".kkkkkkkk.",
]
PHONE_LAMP = (7, 4)
PHONE_DEAD = [row.replace("p", "U").replace("P", "D") for row in PHONE]  # no line yet

MONITOR = [
    ".kkkkkkkk.",
    "kuuuuuuuuk",
    "kuUUUUUuuk",
    "kuuuuuuuuk",
    "kuUUUUUuuk",
    "kuuuuuyyuk",
    "kuuuuuyYuk",
    ".kkkkkkkk.",
    "....kk....",
    "..kkkkkk..",
]

MUG = [
    "kkkk",
    "kxxk",
    "kMMk",
    "kkkk",
]
STEAM = [
    [".w..", "w...", ".w.."],
    ["..w.", ".w..", "..w."],
]

PLANT = [
    "...v.v...",
    "..vVvVv..",
    ".vVvvvVv.",
    "..vvVvv..",
    "...kkk...",
    "..kzzzk..",
    "..kzZzk..",
    "...kkk...",
]

CHAIR = [
    "..kkkkkkkkkkkkkk..",
    ".kaAAAAAAAAAAAAak.",
    "kaAaaaaaaaaaaaaAak",
    "kaaaaaaaaaaaaaaaak",
    "kaaaaaaaaaaaaaaaak",
    "kaaaaaaaaaaaaaaaak",
    "kaaaaaaaaaaaaaaaak",
    "kaaaaaaaaaaaaaaaak",
]

# Speech-bubble contents (drawn inside a 15 x 9 bubble)
THINK = [
    ["k........", ".........", "........."],
    ["k...k....", ".........", "........."],
    ["k...k...k", ".........", "........."],
]

# 3x5 font for desk nameplates (engraved caps, like a real brass plate)
FONT = {
    "A": ["###", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": ["###", "#..", "#..", "#..", "###"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": ["###", "#..", "#.#", "#.#", "###"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "#.#", "###"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": ["###", "#.#", "#.#", "#.#", "###"],
    "P": ["###", "#.#", "###", "#..", "#.."],
    "Q": ["###", "#.#", "#.#", "###", "..#"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": ["###", "#..", "###", "..#", "###"],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", ".#.", "#..", "###"],
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"],
    "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "##."],
    " ": ["...", "...", "...", "...", "..."],
    "-": ["...", "...", "###", "...", "..."],
    ".": ["...", "...", "...", "...", ".#."],
    "!": [".#.", ".#.", ".#.", "...", ".#."],
    "?": ["##.", "..#", ".#.", "...", ".#."],
    "'": [".#.", ".#.", "...", "...", "..."],
    "&": [".#.", "#.#", ".#.", "#.#", ".##"],
}
# German-friendly fallbacks
FOLD = {"Ä": "A", "Ö": "O", "Ü": "U", "ß": "S", "É": "E", "È": "E", "Á": "A", "À": "A", "Ç": "C", "Ñ": "N"}

# ---------------------------------------------------------------------------
# Scene geometry (logical pixels)
# ---------------------------------------------------------------------------
SCENE_W = 96
WALL_H = 24
CELL_W = 48
CELL_H = 48
ROWS = 3
SCENE_H = WALL_H + ROWS * CELL_H

PARTITION = (2, 2, 44, 16)      # x, y, w, h inside a cell
CHAIR_POS = (15, 17)
CHAR_POS = (16, 8)
DESK_TOP = (3, 26, 42, 4)       # x, y, w, h
DESK_FRONT = (4, 30, 40, 11)
MONITOR_POS = (3, 17)
PHONE_POS = (34, 19)
MUG_POS = (12, 23)
PLATE_Y = 31
PLATE_H = 9
BUBBLE_POS = (29, 0)
NAME_MAX = 8
