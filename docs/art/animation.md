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
Traps, Decorations, Tiles, Effects, Interface…) with an animated thumbnail, a search box and how many animations
each has. Ctrl+O reopens it.

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

## One set per thing in the game

There is ONE set per image folder — `enemies/bomb`, `bosses/snowboss`, `world/decorations/cave`, `player`… — holding
every animation of that thing, and every set is edited the same way (until 3.88 sheets had their own "used by the
game" sets with a single "all frames" animation; the user found the split confusing and chose this, 2026-10-08).
What is in a set:

| In the set | How the game reads it | What editing changes in the game |
|---|---|---|
| **Named animations the code asks for by name** (`enemies/gummy`, `enemies/hopper`, `enemies/crabby*`, every enemy made in the enemy editor) | `Anim.load(id)` | everything: frames, order, speed |
| **A sheet as an animation** — marked `"sheet": "<file>"` and `"frameW"`: e.g. `bomb-fuse-Sheet.png` is the animation `bomb-fuse` of `enemies/bomb` | `SpriteStrip.load(path, frameW)` finds the animation with that `sheet` in the folder's set; the strip's frames are that animation's frames, in its order | each frame's picture and crop, the order and number of frames. Speed too when the code plays it by the clock (`"codeFps"` is present: the editor says "the game plays it exactly as it is here"). When the code picks the frame from what is happening (how close a bomb is to exploding, a boss pose) the editor says so: the speed there is only for viewing, and removing frames makes the code clamp to the last one |
| **Loose images** — frames with `"key": "<file name>"` | `Anim.image(path)` (every loose-image load in `src/world`, `src/player`, `src/flappy`) | which picture that file name resolves to. Their animations (`all`, …) are for viewing them together |

**One animation per state** (the user, 2026-10-08: "each distinct state managed as its own animation, not one long
animation"). A sheet where the code uses each frame for a different state is split into one animation per state,
all pointing at the same `sheet`; each says with `"at"` which frame numbers of the sheet are its own — the numbers
the code asks for. Gloomy: `walk` (at 1-4), `idle` (5), `crouch` (6), `leap` (7), `scared` (8), `dead` (9), and the
same for its glow overlay (`glow_walk`…). Split this way: Gloomy, Mega Gloomy (body, glow, claws), Mega Gummy, the
Mega Crabby claws, the Snow Ball and Verity (body, cracks by level), bombs (body and fuse), pufferfish, cryo, touch
buttons, ping. Loose images are no longer lumped in an `all` animation either: one animation per object or state
(trampoline `idle` / `bounce` / `idle_ice` / `bounce_ice`, mortar `idle` / `shoot`, spikes `spike` / `spike_ice`…).
The table lives in `tools/anim/split_states.py` (re-runnable; add a row when a new multi-state sheet appears).
In such an animation the frames and their order are yours; the game uses as many frames as its `at` lists (fewer →
they repeat, extra → not shown) and its own rhythm, because those sprites' code still steps the frames. Making one
of them free in count and speed means porting its code to ask by name, as Gummy, Hopper and the Crabbies do.

A sheet animation can be renamed freely (the game finds it by `sheet`, not by name). If its animation is deleted
the game falls back to cutting the image as before.

Generators (`tools/anim/`; they add, never overwrite what exists): `make_strip_sets.py <capture>` adds each sheet
the game loads to its folder's set and records the speed the code asks for (the capture is written by running the
battery and `level_shots` with `FM_ANIM_CAPTURE=<file>`), `make_folder_sets.py` (loose images),
`make_family_sets.py` (the Crabbies). **After adding a new sheet or image folder to the game, run them** so it shows
up in the editor.

## The runtime contract: ask for an animation by name

Decided by the user on 2026-10-08: **the editor defines the animation, the runtime plays it; entity code defines
behaviour and state, never how frames are processed.** An animation is always *name → ordered frames → playback
settings*, whether its frames were cut from a sheet or are loose images (a sheet is only a source format).

Rules for entity code:

- Ask by **name**: `self:anims():draw('walk', t, …)`. Never a frame index, never a frame count, never an fps.
- `t` is the time inside that state, taken from what travels in snapshots (`deadTimer`, `modeT`…) or, for idle
  loops that are only decoration, the wall clock.
- A walk cycle that is simulation state (the `frame` counter sent over the network) uses `set:drawN('walk', k)`;
  its rhythm and length come from the animation: `Entity:walkCycle()` reads the `walk` animation's fps and frame
  count for every type that declares `Type.animId` (the tuning's `walkFps` / `walkFrames` are only the fallback).
- A composed motion is its own animation, not code: the Gloomy's taunt is `taunt` (crouch ↔ idle at 9 fps), the
  pufferfish's warning is `warn` (per-frame `durations`, not looping), the explosion is `explosion` (not looping).
- Per-frame facts the code needs are frame data in the set (`inset` on Crabby frames, `tip` = the fuse tip on bomb
  frames), read with `set:data(name, t)` or `set:frame(i).data`.
- Variants of the same thing are name suffixes or prefixes decided by behaviour (`idle_ice`, `glow_walk`,
  `object_idle`), or set `variants` when only the images change.

API (`src/fx/Anim.lua`):

- **Set** — `Anim.load(id, variant)`, `set:draw(name, t, x, y, r, sx, sy, ox, oy)`, `set:drawN(name, k, …)`,
  `set:drawPx(…, oxPx, oyPx)`, `set:frameAt(name, t)`, `set:frameN(name, k)`, `set:count / fps / width / has(name)`,
  `set:data(name, t, k)`.
- **Clip** — ONE named animation, the object most code holds: `Anim.clip(id, name)` →
  `clip:play(t, x, y, r, sx, sy, ox, oy)`, `clip:at(t)` (the step at time t by ITS fps, loop and durations),
  `clip:atProgress(p)` (the whole animation spread over a 0..1 progress: a charge, a level meter, one turn of a
  rolling ball), `clip:atFraction(p)` (same but respecting each frame's duration), `clip:draw(k, …)` (a step
  counter, wraps), `clip:rec(k)` / `clip:now()` (the frame record: image, quad, x, y, w, h, data — for code that
  draws by hand: cropping a growing icicle, tiling a stream), `clip.count`, `clip.w`, `clip.h`.
  A clip also answers `getWidth / getHeight / getDimensions` and `clip:show(x, y, r, sx, sy, oxPx, oyPx)`, so it
  drops in where a loose image was drawn with `love.graphics.draw(img, …)`.
- **Part** — `Anim.part(path)`: the clip of a loose image given its FILE path, for skin tables that store files (each
  Crabby's spike, each apple). Every tracked image of a folder that has a set is in that set.
- In the base: `Entity:anims()` and `Entity:walkCycle()`; decorations: `DecoFx.anim(set, name)`, `DecoFx.fx(name)`;
  the monster: `src/player/PlayerSprite.lua` (the pose NUMBER that travels in the simulation → its animation).

### Migration status: complete (3.92)

Every sprite in the game asks for its animations by name: enemies, the seven bosses (bodies, claws, overlays,
projectiles), traps and mechanisms, items, all decorations and their particles, effects (lava, snow, ice drips,
boss marks), the player everywhere it is drawn (player, online players, Flappy, both Mirrors), touch buttons, ping
and flashlight HUD. What used to be composed in code is data: Gloomy `taunt`, pufferfish `warn` / `deflate`, bomb
`explosion` and `fuse_*`, the snow boss's `land` / `shoot` / `intro_*`, the clam and anemone cycles, the stretch
plant's ping-pong, the Mirror's `laugh_body` / `laugh_head`.

Not animations, and left as they were — **textures**: tile textures (stretched, tiled or cut in quarters;
`texture = { anim = … }` already animates a tile), water surfaces, the sky layers and the story-map terrain. They
still load through `Anim.image(path)` / `love.graphics.newImage`.

What stays in code by design, because it is behaviour and not frame handling: which animation a state shows; poses
computed with squash, rotation or shake; progress-driven animations (the code gives the progress, the animation
gives the frames); random variant choice (one of `clip.count`); and walk cycles that are simulation state — their
step counter travels over the network, but its rhythm and length come from the animation.

Compatibility kept for old content: `SpriteStrip.load(path, frameW)` (no game code uses it any more; it returns the
clip of the animation marked `sheet`, or cuts the image) and `Anim.image(path)`.

Porting anything new = give it a set, ask by name, put composed sequences in data (`tools/anim/port_names.py` holds
every data step of this migration, re-runnable), and add its old formulas to the `por_nombre` case of `enemy_data`.

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

Everything else is in its folder's set as sheet animations and loose images (previous section). For the
hand-written bosses and the player, WHEN each frame shows is still decided by code — their poses are computed
(squash, claws, rotation), not frame lists. All migrations were verified pixel-identical against screenshots taken
before them.

**Tests:** `enemy_data` (timing, events, variants, every set in `assets/anim` valid and its images present;
`por_nombre`: 8,037 frame comparisons between the by-name runtime and the old index formulas — Gloomy, Mega Gloomy,
bombs, pufferfish, Snow Ball and Verity, Mega Gummy, cryo, Mega Crabby — none different),
`tool_editors` (every sheet is read from its set and the set's speed reaches the game; the real editor: open, create
an animation, undo / redo, the browser, slice a sheet, save, re-read),
plus the before / after screenshot comparison of all 44 levels (`level_shots FIXED=1`), identical after the migration.
