# Animations as data and the animation editor

An **animation set** is a JSON file in `assets/anim/<id>.json` that says which images the FRAMES come from and which
SEQUENCES exist (idle, walk, attack…). It is created and changed in the **animation editor** — no code. The game
only asks "which frame now?" and draws it.

```
love . --anim [id]        open (or create) a set
```

**Files**

| File | Role |
|---|---|
| `src/fx/Anim.lua` | the runtime: `Anim.load(id[, variant])`, `set:draw(name, t, x, y, r, sx, sy)`, `set:frameAt`, `set:frameN`, `set:eventsBetween`, `Anim.player(set)`; works on the headless server |
| `assets/anim/<id>.json` | the sets |
| `src/editor/AnimPanel.lua` | the editor as a reusable PANEL (also embedded in the enemy editor) |
| `src/editor/AnimEditor.lua` | the standalone tool around the panel (open / new / save) |
| `src/editor/ToolShell.lua` | shared by the tools: LÖVE callbacks, saving repo files, readable JSON, play-testing a level |
| `src/fx/SpriteStrip.lua` | the older primitive (one strip image, frames by index); still used by code-driven sprites |

## The format

```json
{
  "id": "gummy",
  "scale": 4,
  "origin": [0.5, 1],
  "fallback": "idle",
  "frames": [
    {"image": "assets/images/enemies/gummy/gummy.png"},
    {"image": "assets/images/.../sheet-Sheet.png", "x": 16, "y": 0, "w": 16, "h": 21}
  ],
  "anims": {
    "walk": {"frames": [2, 3], "fps": 7, "loop": true, "durations": [0.1, 0.2], "events": {"2": "step"}, "next": "idle"}
  },
  "variants": {
    "ice": {"from": "assets/images/enemies/gummy/", "to": "assets/images/enemies/gummy_ice/"}
  }
}
```

- **frames** — numbered from 1. A whole image, or a rectangle of a sheet. Any mix of images.
- **anims** — a sequence is a list of frame numbers with `fps`, `loop`, optional per-frame `durations` (seconds; 0 or
  absent = 1/fps), optional `events` (a name fired on entering that position of the sequence) and `next` (what
  follows a non-looping sequence in `Anim.player`).
- **origin** — the anchor inside a frame (0..1); `[0.5, 1]` = the feet.
- **fallback** — the sequence used when code asks for one that does not exist.
- **variants** — the SAME sequences with other images: every frame path that starts with `from` is rewritten to
  `to`. This is how one set serves the five Gummies or the six Hopper skins.

**The rule that makes it network-safe:** the frame is a PURE function of (sequence name, time). So drawing derives
from what already travels in snapshots — an entity's `state` and its time in that state — and looks the same in
single player, on the server and online. Never keep animation time in state that is not sent.

## The editor

Three columns. **Frames** (left): "+ Imagen" adds a whole image as a frame; "+ Cortar hoja" picks a sheet and slices
it on a grid; a frame can be re-cut by hand (x, y, w, h), reordered (sequences are remapped) or removed.
**View** (centre): the selected sequence playing, with the frame outline and the anchor cross; wheel = zoom; below,
the STRIP of the sequence: add the selected frame, reorder, remove, set a per-frame duration. **Sequences** (right):
create (preset names or any name), fps, loop, what follows, an event on the current position, duplicate, delete;
then the set's scale, anchor, fallback and variants (with a selector to preview each variant).
Keys: Space play / pause · `,` `.` previous / next position · Ctrl+S save.

Images must already be files under `assets/images/` (copy a new one there and press "Releer" in the picker).

## Using a set from code

```lua
local Anim = require 'src/fx/Anim'
local set = Anim.load('gummy', 'ice')          -- cached
set:draw('walk', t, x, y, 0, sx, sy)            -- anchored at its origin
local frame, finished = set:frameAt('dead', t)
set:drawFrame(set:frameN('walk', self.frame), x, y, 0, sx, sy)   -- for code that keeps its own frame counter
```

- **Tiles:** `texture = { anim = 'my_tile', seq = 'idle' }` in a tile def draws the current frame stretched to the
  cell (`TileTypes.drawTexture`); mini blocks draw their quarter.
- **Anything else** (decorations, effects, UI): load the set and call `draw`; for things that are not simulation,
  `Anim.player(set, 'idle')` keeps the clock (`update(dt)`, `play(name)`, `onEvent`).
- **Data-driven enemies** use a set for everything: [enemy-editor](../entities/enemy-editor.md).

## What is on the new system today

| Sprite | Set | Notes |
|---|---|---|
| Gummy and its four island variants | `gummy` (variants `ice`, `magma`, `cave`, `fortress`) | `Gummy.loadArt` reads the set; the walk cycle still advances by the simulation's frame counter |
| Hopper, six island skins | `hopper` (variants per island) | frames by sequence name: `idle`, `crouch`, `air`, `dead` |
| every enemy made in the enemy editor | its own | fully data-driven |

Both migrations were verified pixel-identical against screenshots taken before them.

**Still code-driven** (their frames are picked by hand-written code from strips or single images): the Crabby
family, Gloomy, bombs, pufferfish, mortar, every boss, the player, decorations (`DecoFx`), lava. They keep working
exactly as before. Moving one over is mechanical — describe its images in a set, then replace the frame choice with
`set:frameN / frameAt` by state — but each needs its own before / after screenshot check, and the bosses' poses are
computed (squash, claws, rotation), which a frame list alone does not replace. Do them one at a time when they are
next touched.

**Tests:** `enemy_data` (timing, events, variants, every set in `assets/anim` valid), `tool_editors` (the real editor:
open, create a sequence, slice a sheet, save, re-read).
