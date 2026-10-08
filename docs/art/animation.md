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

`love . --anim` opens the **browser**: every animation set in the game, grouped (Enemies, Bosses, Player, Items,
Traps, Decorations, Tiles, Effects, Interface…) with an animated thumbnail, a search box and a tag saying whether
the set is "complete" (everything is decided here) or "used by the game" (see below). Ctrl+O reopens it.

The editor itself reads left to right, the way you work:

1. **Animations** (left) — the list: Quieto (idle), Andar (walk), Ataque (attack)… Pick one or press
   "+ Nueva animación" (standard names or any name). Below: its speed (fps), whether it loops, what follows it,
   duplicate, delete.
2. **View** (centre) — the chosen animation playing, with a transport bar: previous / play-pause / next, a progress
   bar you can click, and a view speed (¼ ½ 1× 2×). Wheel = zoom. The yellow cross is the anchor (the feet).
3. **Timeline** (below the view) — the frames of that animation in order: add the frame selected in the bank,
   reorder, remove, give one frame its own duration.
4. **Frame bank** (right) — every drawing available: "+ Imágenes…" adds loose images (click several, then "Hecho"),
   "+ Cortar una hoja…" slices a sheet on a grid. Double-click a bank frame to append it to the timeline. Below, the
   selected frame (change its image, crop it by hand, reorder, delete) and two folded sections: set settings (scale,
   anchor) and variants.

Ctrl+Z / Ctrl+Y undo and redo everything; Ctrl+S saves; Space plays / pauses; `,` `.` step frames. Images must
already be files under `assets/images/` (copy a new one there and press "Releer" in the picker).

## Three kinds of set

| Kind | Tag in the browser | What editing it changes in the game |
|---|---|---|
| **Complete** — `enemies/gummy`, `enemies/hopper`, `enemies/crabby*`, every enemy made in the enemy editor | completo | everything: frames, order, which animation has which frames, speed |
| **Strip** (`"strip"` + `meta.code`) — one per sprite strip the game loads with `SpriteStrip` (decorations, bombs, Gloomy, pufferfish, boss sheets, effects, UI): id = the image path, e.g. `enemies/bomb/bomb-Sheet` | lo usa el juego | each frame's picture or crop. The code uses the frames BY NUMBER, so do not change their order or count. Speed stays in code unless you switch on "la velocidad la manda este conjunto" (`"timing": "set"`), which makes the strip play at the `all` animation's speed |
| **Folder** (`meta.folder`) — one per folder of loose images (player, mortar, items, tiles, boss pieces…): one frame per file, with `"key"` = the file name | lo usa el juego | which picture each file name resolves to: the game loads those images through `Anim.image(path)`, so pointing a frame at another image swaps it in game. The animations in these sets are only for viewing the frames together |

How the game reads them: `Anim.load(id)` (complete sets), `SpriteStrip.load(path, frameW)` (looks for the set named
after the image and uses its frames when the frame width matches; otherwise the plain strip) and
`Anim.image(path)` (every loose-image load in `src/world`, `src/player`, `src/flappy`).

Generators (they never overwrite an existing set; `--force` to rebuild): `tools/anim/make_strip_sets.py <capture>`
(the capture is written by running the game or the battery with `FM_ANIM_CAPTURE=<file>`: every strip loaded
without a set is logged), `tools/anim/make_folder_sets.py`, `tools/anim/make_family_sets.py` (the Crabbies).
**After adding a new strip or image folder to the game, run them** so it shows up in the editor.

## Using a set from code

```lua
local Anim = require 'src/fx/Anim'
local set = Anim.load('enemies/gummy', 'ice')   -- cached
set:draw('walk', t, x, y, 0, sx, sy)            -- anchored at its origin
local frame, finished = set:frameAt('dead', t)
set:drawFrame(set:frameN('walk', self.frame), x, y, 0, sx, sy)   -- for code that keeps its own frame counter
set:images('hide')                              -- the images of a sequence, for code that works image by image
```

- **Tiles:** `texture = { anim = 'my_tile', seq = 'idle' }` in a tile def draws the current frame stretched to the
  cell (`TileTypes.drawTexture`); mini blocks draw their quarter.
- **Anything else** (decorations, effects, UI): load the set and call `draw`; for things that are not simulation,
  `Anim.player(set, 'idle')` keeps the clock (`update(dt)`, `play(name)`, `onEvent`).
- **Data-driven enemies and bosses** use a set for everything: [enemy-editor](../entities/enemy-editor.md).

## What is fully data-driven today

| Sprite | Set | Notes |
|---|---|---|
| Gummy and its four island variants | `enemies/gummy` (variants) | the walk cycle still advances by the simulation's frame counter |
| Hopper, six skins | `enemies/hopper` (variants) | frames by animation name: `idle`, `crouch`, `air`, `dead` |
| Crabby, six skins (and their trampoline versions) | `enemies/crabby`, `crabby_ice`, `crabby_fortress`, `crabby_river`, `crabby_cave`, `crabby_lava` | `walk` (cycle + speed), `hide` / `unhide` (any number of frames; the length of `hide` is how long hiding takes), `hidden`, `peek`, `meat`, `dead`. A frame's `inset` = empty rows above the shell. Frames must be whole images |
| enemies and bosses made in the enemy editor | their own | everything |

Everything else is editable as a strip or folder set (previous section): the pictures can be swapped, re-cropped
and previewed, while WHEN each frame shows is still decided by that sprite's code — the bosses' and the player's
poses are computed (squash, claws, rotation), not frame lists. All migrations were verified pixel-identical against
screenshots taken before them.

**Tests:** `enemy_data` (timing, events, variants, every set in `assets/anim` valid and its images present),
`tool_editors` (the real editor: open, create an animation, undo / redo, the browser, slice a sheet, save, re-read),
plus the before / after screenshot comparison (`level_shots FIXED=1`).
