# The background plane

One extra layer of **blocks and decorations BEHIND the level** — behind everything except the sky — with no collision
and no effects. It scrolls with the level (same camera, no parallax), is drawn darker so it reads as background, and
the front blocks cast a hard shadow on it. Added in 0.5.87.

## Files

| File | What |
|---|---|
| `src/world/level/BackPlane.lua` | `allows(def)` (which blocks may go there), `build(level, data)` (the plane's grid → `level.bg`), `isBg(d)`, `render(level, camX, camY)`; the look constants `SHADE`, `SHADOW`, `OFF` |
| `src/world/level/Level.lua` | `Level.fromData`: `BackPlane.build` and `level.bgDecorations` (the decorations on the plane) |
| `src/world/level/LevelRender.lua` | `Level:renderBackPlane`; `Level:render(camX, camY, noPlane)` draws the plane first unless `noPlane`; `renderDecorations` skips plane decorations |
| `src/world/decorations/DecorationTypes.lua` | `plane` in `normalize` / `serialize` / `instantiate`; a type with `plane = 'bg'` always goes on the plane |
| `src/editor/` | the editor's plane switch (see [levels/editor](../levels/editor.md) § Background plane) |
| `tools/levelgen/arenas/make_fondo.py` → `fondo.json` | the showcase arena (jungle front, temple walls, an arch and a big tree behind) |
| `tools/levelgen/retheme_bg.py` (`retheme.py --bg <levels>`) | generates island structures on the plane of existing levels (hills, walls, outcrops, ruins, big trees) — [levels/retheme](../levels/retheme.md) § Background-plane structures |

## Data

- `bgTiles` in the level JSON: the same grid and cell encoding as `tiles` (one row per line). Absent = no plane. Only
  the block id is used: water and spike bits are dropped, and so is any block `BackPlane.allows` refuses.
- A decoration with `"plane": "bg"` goes on the plane. A type whose definition has `plane = 'bg'` (every big tree: the
  island trees of `make_big_trees.py`, the giant mushrooms, the ceiba / strangler fig, the big palms) is ALWAYS there;
  `serialize` does not write `plane` for those.
- What may go on the plane (`allows`): the blocks that look solid — terrain, stone, bricks, platforms, ice… Not:
  empty, `collision = 'none'`, triggers (finish, checkpoints), ON/OFF activators and blocks, lava, liquids, contact
  materials (hazards). Every decoration may go.

## Single player / server / client

Render only. `AdventureState` and `OnlineAdventureState` draw it right after the sky (`level:renderBackPlane`, then
`Entities.renderBack` and `level:render(camX, camY, true)`). The server builds the level (so `level.bg` exists) but
never draws; nothing travels in snapshots and the protocol is unchanged (the plane is part of the level file).

Drawing (`BackPlane.render`): the plane's blocks (joined among themselves, never with the front ones) and its
decorations go into a canvas of `WINDOW_W × WINDOW_H` drawn at the origin; on top, the hitbox of every front block that
collides, moved `OFF` (16 px, ¼ tile) down-right, with blend `multiply` × `SHADOW` (it only darkens what is already in
the canvas: the sky never gets a shadow); the canvas is then drawn over the sky tinted `SHADE` × the time-of-day tint
of the sky layers. No stencil (Switch / Android).

- The canvas only GROWS and a Quad uses its `W × H` corner: in the editor `WINDOW_W/H` is the view, which changes on
  every zoom step (a new canvas per step filled video memory). It is clamped to the GPU texture limit.
- After the canvas pass the scissor is set again explicitly: `pop()` restored it while the plane canvas was still
  bound, so on the screen it landed elsewhere (the editor's scissor cut the plane, or hid it when zoomed out).

## How to extend

- A new block that should be allowed or refused: `BackPlane.allows` decides from the definition (collision, trigger,
  toggle, activator, lava, liquid / contact material); a new kind of hazard must be refused there.
- A decoration type that must always be in the background: `plane = 'bg'` in its definition.
- Structures for a theme generated on existing levels: table `SPEC` in `tools/levelgen/retheme_bg.py` (see
  [levels/retheme](../levels/retheme.md) § Background-plane structures; generated parts are listed in `tools/levelgen/bg_gen/<level>.json`).
- Darker / lighter or a different shadow: `SHADE`, `SHADOW`, `OFF` (the user chose them: ask before changing).

## Tests

- `run.sh editor_open PLANE=1 LEVEL=tools/levelgen/arenas/fondo.json`: the editor side (switch, painting, palette,
  decorations, undo, save / reload, resize, play-test) and captures `editor_open_plano_*.png`.
- `run.sh editor_open PLAY=tools/levelgen/arenas/fondo.json` and `run.sh level_shots SCALE=1 -- tools/levelgen/arenas/fondo.json`:
  how it looks in game.

## Decisions (the user's)

- ONE plane, scrolling with the level (no parallax): enough to give depth; the sky already has its parallax layers.
- Solid-looking blocks + all decorations; never liquids, hazards, triggers or switches (it has no gameplay).
- A fixed, darker shade (slightly blue toward the sky); after the first preview the user asked for it **"a little
  darker"** (`SHADE` 0.5 / 0.53 / 0.6).
- A hard shadow ¼ tile down-right from the front blocks onto everything on the plane (light from the top-left, like
  all the art).
- The big trees ALWAYS go on the plane (the stage reads better with them behind).
- The editor gets a layer switch "Delante / Fondo" (P); while editing the plane, the front is drawn translucent.

## History

- 0.5.87: first version (plane, shadow, big trees moved to it, editor switch). Rejected: nothing yet.

- 2026-10-28, after seeing the generated levels of the dark islands (night fortress, caves too dark): the user asked to
  go back to the ORIGINAL shade (0.56 / 0.59 / 0.66, the first preview; the "a little darker" 0.5 / 0.53 / 0.6 is
  rejected) and to install the generated background in every story level to try how it plays (originals backed up in
  `FlappyMonster_originals/assets/levels_antes_plano_fondo_2026-10-28/`).
- Editor bug (the user): editing the plane, the translucent front left TRAILS outside the level when panning — its canvas
  was cleared with the window's scissor still set (clear respects the scissor) → cleared without it. Test:
  `editor_open PLANE=1` case `estela`.
