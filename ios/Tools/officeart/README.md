# Office art (LimeZu)

The office, desks and deskmates are drawn with LimeZu's **Modern Office** and **Modern Interiors** packs (Generic, Kitchen, Living Room, Hospital and Conference Hall themes), and the deskmates are built from the Modern Interiors character generator layers (body, eyes, outfit, hair, accessory).

The floor plan: a work corner and a kitchen with a break corner along the top wall, six desks in the middle, and a lobby at the bottom with the entrance, a waiting couch and the reception.

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
| `art.py` | Which sprites come from which sheet (rects in the 16x16 sheets, or several layered into one), walls and floors, animated objects, emotes, curated accessories, nameplate font |
| `scene.py` | Floor plan: floor zones and wallpaper, the kitchen partition, the door, furniture, six workstations, break spots and visitor seats |
| `pack.py` | Builds the atlas, background, character layer strips and `office.json`, including walk paths (A* around furniture) for deskmates and visitors |
| `render.py` | Reference renderer for stills. The Swift `OfficeScene` and the web preview follow the same rules |
| `preview.py`, `preview.template.html`, `preview.js` | Single-file browser preview with scripted calls. Contains licensed art: keep it private |

## Rules every renderer follows

- Coordinates are art pixels, top-left origin. The scene is 192x304; the app scales it by a whole number of device pixels.
- Everything is depth-sorted by its bottom edge. Characters sort by their feet. A seated deskmate's feet are 3px below the desk's back edge, so the desk top hides their legs.
- Character strips hold 84 frames of 16x32: idle (6 per direction: right, up, left, down), walk (same), phone (0-2 take out, 3-8 loop, 9-11 put away), sit (6 facing right, 6 facing left) and read (12, front-facing). `office.json` lists where each starts.
- A `Look` picks one layer per slot and every index wraps: `skin` → body, `eyes`, `shirt`/`shirt_color` → outfit style and colour, `hair`/`hair_color`, `accessory` (0 = none).
- Seated deskmates with a phone line wear a headset (`headset`, or `headset_live` with a lit mic while on a call). Dialing out plays the phone animation. Emotes: `!` ringing, thought dots thinking, speech dots talking, crown when you've taken over.
- Idle deskmates take a break at a free staff place in `scene.POIS` (cooler, copier, fridge, coffee, drinks fridge, the kitchen table, the sofa), wait there and walk back. If their desk gets a call while they're away, they turn around and hurry back, and the call is answered once they're seated.
- Every 20-50 seconds a visitor may come in through the door (at most two at a time, one at reception), check in at the counter, sit on the waiting couch or chair with a magazine, and leave.
- Each place holds one person. Seats have an `approach` spot in front and a `z`: people walk to the approach spot, step into the seat, and are drawn at the seat's `z` so they appear on top of the chair or sofa.
