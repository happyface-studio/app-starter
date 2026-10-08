"""Generate PixelArt.swift and pixelart.js from design.py."""

import json
import sys

import design as d


def hex_u32(h: str) -> str:
    return "0x" + h.lstrip("#").upper()


def sw_sprite(rows: list[str]) -> str:
    inner = ",\n".join(f'\t\t\t"{r}"' for r in rows)
    return f"Sprite([\n{inner},\n\t\t])"


def swift() -> str:
    out: list[str] = []
    w = out.append
    w("// Generated from the Deskmates pixel-art source (design.py). Edit there, then regenerate.")
    w("// swiftlint:disable all")
    w("")
    w("import Foundation")
    w("")
    w("enum PixelArt {")
    w("\tstatic let fixed: [Character: UInt32] = [")
    for k, v in d.FIXED.items():
        w(f'\t\t"{k}": {hex_u32(v)},')
    w("\t]")
    for name, pairs in (("skins", d.SKIN), ("hairColors", d.HAIR), ("shirts", d.SHIRT)):
        w(f"\tstatic let {name}: [(UInt32, UInt32)] = [")
        for a, b in pairs:
            w(f"\t\t({hex_u32(a)}, {hex_u32(b)}),")
        w("\t]")
    w("")
    for name, val in (
        ("carpet", d.CARPET), ("carpetDot", d.CARPET_DOT), ("carpetDark", d.CARPET_DARK),
        ("wall", d.WALL), ("wallShade", d.WALL_SHADE), ("baseboard", d.BASEBOARD),
        ("amber", d.AMBER), ("mint", d.MINT),
    ):
        w(f"\tstatic let {name}: UInt32 = {hex_u32(val)}")
    w("\tstatic let sky: [String: (UInt32, UInt32)] = [")
    for k, (a, b) in d.SKY.items():
        w(f'\t\t"{k}": ({hex_u32(a)}, {hex_u32(b)}),')
    w("\t]")
    w("")
    for name, rows in (
        ("body", d.BODY), ("face", d.FACE), ("faceBlink", d.FACE_BLINK), ("mouthOpen", d.MOUTH_OPEN),
        ("phone", d.PHONE), ("phoneDead", d.PHONE_DEAD), ("monitor", d.MONITOR), ("mug", d.MUG),
        ("plant", d.PLANT), ("chair", d.CHAIR),
    ):
        w(f"\tstatic let {name} = {sw_sprite(rows)}")
    w("\tstatic let steam = [")
    for frame in d.STEAM:
        w(f"\t\t{sw_sprite(frame)},")
    w("\t]")
    w("")
    w("\t/// Same order as `Look.hair` in the database.")
    w("\tstatic let hairStyles: [Sprite] = [")
    for key in d.HAIR_ORDER:
        w(f"\t\t{sw_sprite(d.HAIR_STYLES[key])},  // {key}")
    w("\t]")
    w(f"\tstatic let hairStyleNames = {json.dumps([k.capitalize() for k in d.HAIR_ORDER])}")
    w("\t/// Same order as `Look.accessory` in the database.")
    w("\tstatic let accessories: [Sprite] = [")
    for key in d.ACCESSORY_ORDER:
        rows = d.ACCESSORIES[key] or ["."]
        w(f"\t\t{sw_sprite(rows)},  // {key}")
    w("\t]")
    w(f"\tstatic let accessoryNames = {json.dumps([k.capitalize() for k in d.ACCESSORY_ORDER])}")
    w("")
    w("\tstatic let font: [Character: [String]] = [")
    for k, glyph in d.FONT.items():
        key = k.replace("\\", "\\\\").replace('"', '\\"')
        w(f'\t\t"{key}": {json.dumps(glyph)},')
    w("\t]")
    w("\tstatic let fold: [Character: Character] = [")
    for k, v in d.FOLD.items():
        w(f'\t\t"{k}": "{v}",')
    w("\t]")
    w("")
    w("\tenum Layout {")
    for name, val in (
        ("sceneWidth", d.SCENE_W), ("wallHeight", d.WALL_H), ("cellWidth", d.CELL_W),
        ("cellHeight", d.CELL_H), ("rows", d.ROWS), ("sceneHeight", d.SCENE_H),
        ("plateY", d.PLATE_Y), ("plateHeight", d.PLATE_H), ("nameMax", d.NAME_MAX),
    ):
        w(f"\t\tstatic let {name} = {val}")
    for name, val in (
        ("partition", d.PARTITION), ("deskTop", d.DESK_TOP), ("deskFront", d.DESK_FRONT),
    ):
        w(f"\t\tstatic let {name} = (x: {val[0]}, y: {val[1]}, w: {val[2]}, h: {val[3]})")
    for name, val in (
        ("chair", d.CHAIR_POS), ("character", d.CHAR_POS), ("monitor", d.MONITOR_POS),
        ("phone", d.PHONE_POS), ("mug", d.MUG_POS), ("bubble", d.BUBBLE_POS), ("phoneLamp", d.PHONE_LAMP),
    ):
        w(f"\t\tstatic let {name} = (x: {val[0]}, y: {val[1]})")
    w("\t}")
    w("}")
    return "\n".join(out) + "\n"


def js() -> str:
    data = {
        "fixed": d.FIXED, "skin": d.SKIN, "hair": d.HAIR, "shirt": d.SHIRT,
        "carpet": d.CARPET, "carpetDot": d.CARPET_DOT, "carpetDark": d.CARPET_DARK,
        "wall": d.WALL, "wallShade": d.WALL_SHADE, "baseboard": d.BASEBOARD,
        "sky": d.SKY, "amber": d.AMBER, "mint": d.MINT,
        "body": d.BODY, "face": d.FACE, "faceBlink": d.FACE_BLINK, "mouthOpen": d.MOUTH_OPEN,
        "phone": d.PHONE, "phoneDead": d.PHONE_DEAD, "monitor": d.MONITOR, "mug": d.MUG,
        "steam": d.STEAM, "plant": d.PLANT, "chair": d.CHAIR,
        "hairStyles": [d.HAIR_STYLES[k] for k in d.HAIR_ORDER],
        "accessories": [d.ACCESSORIES[k] for k in d.ACCESSORY_ORDER],
        "font": d.FONT, "fold": d.FOLD,
        "L": {
            "sceneW": d.SCENE_W, "wallH": d.WALL_H, "cellW": d.CELL_W, "cellH": d.CELL_H,
            "rows": d.ROWS, "sceneH": d.SCENE_H, "partition": d.PARTITION, "chair": d.CHAIR_POS,
            "char": d.CHAR_POS, "deskTop": d.DESK_TOP, "deskFront": d.DESK_FRONT,
            "monitor": d.MONITOR_POS, "phone": d.PHONE_POS, "mug": d.MUG_POS, "plateY": d.PLATE_Y,
            "plateH": d.PLATE_H, "bubble": d.BUBBLE_POS, "nameMax": d.NAME_MAX, "lamp": d.PHONE_LAMP,
        },
    }
    return "const ART = " + json.dumps(data, separators=(",", ":")) + ";\n"


if __name__ == "__main__":
    swift_path, js_path = sys.argv[1], sys.argv[2]
    open(swift_path, "w").write(swift())
    open(js_path, "w").write(js())
    print("ok")
