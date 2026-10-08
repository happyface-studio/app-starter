# Pixel art source

The office, desks and deskmates are drawn from the string sprites in `design.py`.

- `design.py` — palettes, sprites, the 3×5 nameplate font and scene geometry. Edit art here.
- `render.py` — reference renderer. `python render.py office.png` writes a 4× preview.
- `gen.py` — regenerates the Swift data file:

```bash
pip install pillow   # only needed for render.py
python gen.py ../../Targets/OfficeKit/Sources/Pixel/PixelArt.swift /tmp/pixelart.js
```

`OfficeRenderer.swift` mirrors `render.py` line for line; change both together.
