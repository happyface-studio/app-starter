# Office art (LimeZu)

The office, desks and deskmates are drawn with LimeZu's **Modern Office** and **Modern Interiors** packs, and the deskmates are built from the Modern Interiors character generator layers (body, eyes, outfit, hair, accessory).

**The PNGs are not in git.** LimeZu's license allows using the art in our app but not redistributing it, and this repo is public. Everything generated from the packs is gitignored. Build it locally:

```bash
python3 -m pip install pillow
python3 ios/Tools/officeart/pack.py \
  --limezu "~/Documents/Aiden Technologies/Game/Game Assets/Modern Pixel Art packs" \
  --preview /tmp/office.png
```

That writes `ios/Targets/OfficeKit/Resources/OfficeArt/` (about 400 small PNGs plus `office.json`). Run `tuist generate` afterwards so Xcode picks them up. Without them the app still builds and falls back to the procedural sprites in `Sources/Pixel`.

## Files

| File | What it does |
|---|---|
| `art.py` | Which sprites come from which sheet (rects in the 16x16 sheets), animated objects, emotes, curated accessories, nameplate font |
| `scene.py` | Floor plan: wall decor, furniture, six workstations, places deskmates wander to |
| `pack.py` | Builds the atlas, background, character layer strips and `office.json`, including walk paths (A* around furniture) |
| `render.py` | Reference renderer for stills. The Swift `OfficeScene` and the web preview follow the same rules |
| `preview.py`, `preview.template.html`, `preview.js` | Single-file browser preview with scripted calls. Contains licensed art: keep it private |

## Rules every renderer follows

- Coordinates are art pixels, top-left origin. The scene is 192x304; the app scales it by a whole number of device pixels.
- Everything is depth-sorted by its bottom edge. Characters sort by their feet. A seated deskmate's feet are 3px below the desk's back edge, so the desk top hides their legs.
- Character strips hold 60 frames of 16x32: idle (6 per direction: right, up, left, down), walk (same), then the 12-frame phone animation (0-2 take out, 3-8 loop, 9-11 put away).
- A `Look` picks one layer per slot and every index wraps: `skin` → body, `eyes`, `shirt`/`shirt_color` → outfit style and colour, `hair`/`hair_color`, `accessory` (0 = none).
- Seated deskmates with a phone line wear a headset (`headset`, or `headset_live` with a lit mic while on a call). Dialing out plays the phone animation. Emotes: `!` ringing, thought dots thinking, speech dots talking, crown when you've taken over.
- Idle deskmates wander to a random place in `scene.POIS` along the baked path, wait a few seconds and walk back. If their desk gets a call while they're away, they turn around and hurry back, and the call is answered once they're seated.
