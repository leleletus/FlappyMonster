# Tiles, terrain and special blocks

The level is a grid of 64-px cells. Each cell stores one raw number = tile id + water bit + spikes
(`src/world/tiles/TileCodec.lua`). A tile type is one file in `src/world/tiles/types/` registered in
`src/world/tiles/Tiles.lua`; its physical behaviour comes from its `collision` (`none` / `solid` / `oneway`), its
`hitbox` and its material (`src/world/tiles/materials/`: friction, liquid, deadly contact, debris colours). The full
list is generated: [reference/tiles](../reference/tiles.md).

**Files:** `src/world/tiles/` (catalog), `src/world/level/Level.lua` (queries: `collisionAt`, `getDefAt`,
`liquidAt`, `landingCross`, `onewayCellAt`, `isStandable`…), `src/world/level/LevelTiles.lua` (tiles that CHANGE
during play: breakable, ON/OFF, thin ice, invisible blocks), `src/world/level/SubTiles.lua` (quarter-cell blocks),
`src/world/level/SpikeSkins.lua`, `src/world/systems/PhaseBlocks.lua` (blocks that appear with a boss phase),
`src/world/level/LevelRender.lua` (drawing).

**Rule for anything that changes a tile during play:** only single player and the server change tiles; they queue the
change (`brokenQueue`) and clients apply `tile` events. A block never becomes solid with a player inside.

**To add a tile:** a file in `types/` + its name in `Tiles.lua` `TYPES`; give it a `texture` (an image in
`assets/images/world/tiles/`) and, if it should exist as a mini block, add it to `SubTiles.KINDS`. Then
`tools/tests/run.sh docs_reference`. **Harnesses:** `mechanics` (ice, thin ice, switches, helmet…), `subtiles`,
`flood_control switchblocks`.

## Terrain and how blocks join

- Terrain tiles: `solid` (label **Piedra**, grey), `dirt` (**Tierra** 16, brown with
  pebbles), `grass` (**Césped** 17, green; blades drawn ABOVE the cell when its top is
  exposed), `border`. All `joinGroup='ground'`. Materials `dirt`, `grass`.

- **Block joining = ONE rule** (`TileTypes.joinsCell` / `sideExposure` / `half`): big tiles,
  subtiles and boss walls of the same `joinGroup` never draw a border between them. An edge
  is `true` / `false` / `{a, b}` (half edges, when the neighbour cell has subtiles covering
  only half the side; `drawEdges` and grass blades honour halves). Entities that draw as
  blocks expose `e:joinsCell(c, r, group)` and are registered by `BossZones.link` in
  `level.joinOverlay` (boss walls, only while 'solid'). Harness `subtiles` case `union`.

- Tiles: **Basalto** `basalt` 38 (dark volcanic rock, 2x2 drawing like stone, very few marks) and **Ceniza** `ash` 39
  (ash cap with embers over basalt when its top is in the air, like grass over dirt); materials `basalt` / `ash`
  (debris), sub-tile kinds, thumbnails 'V' / 'H', sand blends, boss-wall `material` options.

## Mini blocks (subtiles)

- **Subtiles** (`src/world/level/SubTiles.lua`): quarter-cell versions of the tiles in
  `SubTiles.KINDS` ({'solid','dirt','grass'}; a new one = one name). JSON
  `"subtiles": [{col,row,sub 1..4,kind[,solid=false]}]` (solid by default; the editor
  only writes `solid:false`). Physics: `Level:getDefAt` returns the quarter's def
  (`SubTiles.def(kind,q)` = the tile def with that quarter as hitbox) in cells without
  collision, so collisionAt/entitySolidAt/landingCross (samples both halves of such
  cells) and everything built on them (player, entities, server, prediction, solver)
  see them. With subtiles `Level:samples(a,b)` gives denser probe points (≤ 24 px; a
  quarter is 32) and the player keeps the MOST restrictive face of all hits.
  `level.subCells` (draw) / `level.subSolid` (physics, nil when none). Editor layer 7
  "Mini bloques": brush/pick/erase per subcell + "Sólido" toggle; non-solid ones show a
  dotted frame in the editor. Thumbnails: 'D' dirt, 'G' grass, 'm' mini blocks.

## Hitting blocks: breakable, ON/OFF Activators and ON/OFF Blocks

- `Level:hitTile(col,row)` = the ONE entry for "head bump from below / ground pound
  on top": breaks `breakable` tiles, turns `toggle` tiles into their other state
  (`toggle = '<tile name>'`, keeps water/spikes bits). Returns 'break'|'toggle'|nil;
  changes go to `brokenQueue {c, r, raw, kind}` → server event `tile` (+`k='toggle'`)
  → clients `setTileRaw` + fx/sound (online clients never change tiles themselves:
  `canBreak = false`). A GP toggles each block once and lands normally.
  `hitTile(c, r, from)`: `from` = 'head' | 'pound' → `Level:tileBump` (render-only,
  `level.tileAnim`, advanced in `Level:update`): head = hop up, pound = the same hop
  DOWN (0.22 s, 0.22 tile). Online: tile event field `from`.

- **ON/OFF Activators** (`switch_on` 13 / `switch_off` 14, labels "Activador ON/OFF",
  Mecanismos; textures `assets/images/world/tiles/switch_*.png`; fx `switch_hit`, sounds
  switchOn/switchOff). They drive linked activatable entities (floods, `links`) and
  **ON/OFF Blocks** (`switchblock_on.lua`, 4 tiles: `switchblock_on` 18 / `_on_x` 19,
  `switchblock_off` 27 / `_off_x` 28; `switchBlock = {kind, active, other}`; inactive
  variants `editorHide`): ON Block solid while its activator is ON, OFF Block while it's
  OFF; inactive = passable + outline texture. Source = level JSON `"blockLinks":
  [{col,row,from=[c,r]}]` or the NEAREST activator. `Level:updateSwitchBlocks` (after
  every toggle; swaps tile ids, queues `tile` events with `k='set'` = no fx) — a block
  never turns solid with a player/obstacle inside (`pending`, retried in `Level:update`,
  only where tiles are decided: SP/server). Editor: Conectar tool → pick an activator,
  then click/drag ON/OFF Blocks to (un)link; cyan lines = links, faint = nearest.
  Harness `flood_control` case `switchblocks`. Protocol v27.

## Invisible block

- **Invisible block** (`hidden_block` 15, Plataformas): FULL-cell hitbox but
  `collision='oneway', dropThrough=false` (pass through going up / sideways, stand on
  top, can't drop); enemySolid for entities. Visibility is RENDER-ONLY per client:
  `Level:updateHiddenBlocks(dt, boxes)` (SP: the player; online: own predicted box +
  remote players via `PlayerAdventure.outerBoxAt`) → `level.hiddenVis[row*65536+col]
  = {age, left, hold, blink}`: appear anim while touched (box +1 px, standing on it
  counts), then hold 0.25 s, blink 0.9 s, gone. Editor/thumbnails draw a dashed ghost.

## Snow, ice and thin ice

- **Snow / ice** (`snow` 29, material snow, joinGroup ground; `ice` 30, drawn at 0.78 alpha, SLIPPERY: material `friction = 0.2` scales the player's ground friction, ice + thin ice; harness `mechanics hielo_resbala`;
  joinGroup ice). Textures `tiles/snow.png`, `ice.png` (the user's originals kept outside the
  repo), from `tools/art/world/make_snow_sprites.py` (never overwrites; `--force`).

- **Thin ice** (`thin_ice.lua`, 4 tiles 31-34: normal → `_1` damaged → `_2` → `_3` about to
  break; later stages `editorHide`): SOLID on every side, half a cell tall (hitbox top half),
  0.8 alpha, textures `thin_ice_0..3.png`. `Level:crackIce(c, r, n, from)` advances n stages
  (≥4 → breaks to empty/water): standing on it `Level.THIN_ICE_WEAR` (0.8 s) per stage
  (`Level:updateThinIce`, SP/server only), head bump 1, GP 3 (the player keeps falling if it
  breaks), explosion 4. Tile events `k='crack'|'icebreak'` → client `tileBump('crack')` (shake),
  fx `ice_crack` / `ice_break`, sounds iceCrack / iceBreak (`tools/sounds/ice.py`); SP gets the
  same through the `level.tileFx(kind, c, r)` hook.

- **Ice drips** (`src/fx/IceDrips.lua`, render-only, per client): tiles with `iceDrip` and air
  below grow drops (`fx/ice_drop.png`) that fall and splash. **Snowfall** (`src/fx/Snowfall.lua`):
  level JSON `"snow": true` (editor Nivel → Clima → "Nieve cayendo"), 3 depth layers of
  `fx/snowflakes.png`, visual only. Decoration `icicle` (Carámbano, `decorations/ice/icicle.png`,
  hangs from the top of its cell). Test arena `tools/levelgen/arenas/hielo.json`.

## Spikes and their skins

- Spikes are images too: assets/images/traps/spikes/spike.png (tile spikes, rotated/flipped for the 4 directions; falling spike) — SPIKE SKINS: level JSON `"spikeSkin": "ice"` (editor Nivel → Fondo y clima → Pinchos; `src/world/level/SpikeSkins.lua` LIST = id + PNG, new skin = PNG + one line) → `spike_ice.png` (`tools/art/world/make_ice_spikes.py`) for tile AND falling spikes (spikefall/rainspike `wantsLevel` → `levelRef.spikeSkin`); render only. Set in the snowy levels (lago_helado, torre_viento, icy arenas; retheme 'snow' theme + make_jefe_nieve write it; their Crabbies are Icy Crabbies too: retheme `ICY_CRABS` swaps crabby/crabbytramp), crabby/spike.png and bosses/miniboss1/spike.png (stretched in height while they grow)

## Tile textures (what the art is and where it comes from)

- Tile textures: assets/images/world/tiles/ (breakable, platform, platform_drop via the tile def's `texture`; finish.png = the checkerboard, its wave + gold frame stay in finish.lua). Stone, border (very hard compact rock) and deep stone are 2x2-cell drawings (`texture.span = 2`: each cell draws its part by column/row, so marks continue across blocks) kept VERY simple (flat colour + a few short marks away from the edges; the user rejected busy Voronoi cracks). **Lava** = tile `danger` (id 3, label "Lava"): lava.png / lava_top.png (exposed top), 4 frames of a hand-drawn pattern shifted 4 px = flowing; `src/fx/LavaFx.lua` (render-only bubbles that pop + droplets + glow, like IceDrips). **Deep stone** (`deep_stone` 36, "Roca abisal", also a mini block). Platform (non pass-through) = riveted steel girder. All these + mortar and checkpoint sprites + sand_blend from `tools/art/world/make_world_art.py` (originals outside the repo). Terrain: dirt.png, grass.png (grass cap over dirt, only when the top is in the air; covered grass = dirt.png), grass_blades.png (3 variants of 16x4 above exposed tops) from `tools/art/world/make_terrain.py`; the light edges on faces in the air are still drawn by code (neighbour-dependent). Mini blocks (ctx.quarter) draw THEIR quarter of the texture at the same scale (seamless with big blocks). **Sand** (`sand` 35, material sand, also a mini block): sand.png + `sand_blend.png` (dithered band in the neighbour's colours, frame 1 dirt/grass, 2 stone, 3 deep stone, 4 border), drawn per HALF cell (big sand = 4 halves; sand mini blocks too) towards any neighbour half cell — big block or mini block, `SubTiles.kindAt(level, gx, gy)` — so the change is never abrupt. A mini block inside a block is NOT a validator warning.

## Tile hitboxes as seen by entities

- Tile hitboxes are REAL for entities: platforms are slabs (`platform` h 0.72,
  `platform_drop` h 0.36). `Entity.moveAndCollide` snaps to the hit face of the
  tile hitbox (and of `solidFull` bodies via `Level:bodyAt`), in ≤16 px
  vertical sub-steps. `collisionAt` always uses the real shape. The PLAYER's
  landing also accepts `Level:onewayCellAt` (a one-way tile counts from its top
  face down to the cell bottom; with its prevFoot check a fast fall/GP can't
  skip a thin plank). Anything else that FALLS (Crabby/Crabby-trampolín drop,
  falling spikes, mortar fire) uses `Level:landingCross(x, y0, y1)`: hit only if
  it crossed a top face FROM ABOVE this step (never catches the slab it hung
  from, never tunnels). Walkers' edge probe is 4 px past the surface (half a
  tile fell out of thin slabs → turned every frame).

## Tests

- Harness: `tools/tests/run.sh mechanics` (also covers the Gummy helmet, the
  pufferfish and thin ice: `hielo_*`). Protocol v22 (ON/OFF + invisible blocks + helmet + pufferfish).
