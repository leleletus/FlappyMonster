# Performance and memory

**What:** how the game's cost is measured (frame time, garbage, GPU resources, leaks, the server's tick) and the
rules that keep it low. The game is small, but it runs on Switch and Android: Lua garbage turns into GC pauses,
GPU memory is only freed when Lua's collector runs, and OpenAL voices are few.

**Files**

| File | Role |
|---|---|
| `tools/tests/perf/main.lua` | the harness (`run.sh perf`): real scenes at fixed 1/60 s steps — menu, levels, boss, Flappy, reloads |
| `tools/tests/lib/garbage_profile.lua` | garbage BY FUNCTION: wraps every function of the loaded `src/` modules and counts the KB each one creates, without its callees (allocation-free wrapper) |
| `src/ui/PerfOverlay.lua` | the on-screen meter for real devices (Settings → Performance, or F3; saved as `showPerf`): FPS, update / draw CPU ms (average, worst), Lua and texture memory, draw calls. Low FPS with low CPU ms means the GPU |
| `server/main.lua` (`FM_PERF=1` / `2`) | the server logs every 10 s: ms per room step and per snapshot, KB created per step, Lua memory; `2` adds garbage by function |

**What the harness reports, per scene:** update / draw CPU ms (avg, p95, max); **garbage** KB per frame (collector
stopped in 60-frame windows); draw calls and texture/shader switches; texture memory; **resources created after
load** (`newImage`, `newQuad`, `newCanvas`, `newSource`, `filesystem.read`... with the call site); Lua memory after a
full collect; a `jit.profile` profile. `fugas`: the same level entered `RELOADS` times in a row; Lua growth per reload
(after the 4th) and texture memory must stay flat. Options: `SCENES=`, `N=`, `WARM=`, `TOP=`, `PROFILE=0`, `GARB=1`,
`CALLERS=module:function` (who calls it, how often), `LEAKS=1` (census of the tables that grow, also inside closures'
upvalues), `SHOTS=1` (a screenshot per scene, to compare before / after a change). Fails on > `LIMIT_KB` (64) KB of
garbage per frame, a call site creating resources 3 or more times in a fixed scene (once or twice = a lazy load), or > `LIMIT_LEAK` (64) KB per reload.

**Reading the numbers:** the test machine renders in SOFTWARE (llvmpipe). Drawing ms are mostly rasterisation, and
`jit.profile` charges it to the first function that waits for the GPU (e.g. `TitleLogo.draw` at 50 % with a dozen
sprites). Judge drawing by draw calls and full-screen passes; judge Lua by update ms, garbage and the profile of
update.

**Rules (what the round of 0.5.2 fixed and must not come back)**

- No tables per tile, per entity or per call in per-frame paths: reuse a module-level scratch table (documented as
  read-only / valid until the next call), or accept an `into` table: `Entity:getOuterBounds(into)`,
  `getInnerBounds(into)`, `PlayerAdventure:getOuterBounds(into)`, `Entity.box(into, x, y, w, h)`.
  `TileCodec.decode` returns a cached, READ-ONLY spikes table per tile value; `TileTypes.edges` a reused one.
- No closures created per entity per step when a function reference will do (`Interactions.run`'s `rewind(i, e,
  check)`).
- GPU resources: never one per state or per level when one shared object will do (`src/fx/SceneCanvas.lua`: the
  scene canvas of every level state and the menu background); release caches that are dropped
  (`ModeSelectMenu.clearPreviews`).
- Draw calls: many identical pieces go in ONE mesh or as sprites of the same image (autobatch): the water
  distortion is one mesh of every liquid cell (it was a full-screen draw per cell); the lights of the darkness canvas
  are sprites of `assets/images/fx/light_*.png` (they were 5 circles of hundreds of vertices each). Skip full-screen
  passes that do nothing (`Darkness` restores the glowing background only if `Sky.punched`).
- Sounds: `Sound.play` reuses a pool of at most 6 voices per sound (it cloned a new OpenAL source each time).
- Lazy caches are fine (quads per art row, previews) as long as they are bounded by the content.

**Numbers (1280×720, this machine; before → after 0.5.2)**

| | before | after |
|---|---|---|
| garbage per frame, level (laberinto_submarino / caldera_roja / boss) | 188 / 193 / 218 KB | 13 / 25 / 54 KB |
| garbage per frame, menu | 201 KB | 16–23 KB |
| server: ms per room step · KB created per step | 1.5 ms · 190 KB | 0.7 ms · 25 KB |
| texture memory after 8 reloads of a level | +3.5 MB per stale scene canvas | flat |
| draw calls, menu | 164 | 102 |

**Why one core, and why the devices suffer (2026-11-02, the user: "all at 100 % on one core, others idle")**

This is how LÖVE works, not a bug: all Lua and all GL calls run on one thread, and Lua states share nothing, so gameplay
cannot be spread over cores without rewriting the simulation. What hurts is the cost per frame on devices WITHOUT THE
JIT: `love-nx` (Switch) is built with no JIT at all (no trace or assembler symbols in `resources/switch/love.elf`) and
LÖVE's `jitsetup` runs `jit.off()` on ARM. Never turn it on: `perf JIT=1` on an ARM Mac was much worse (`caldera_roja`:
update 0.71 → 4.70 ms, garbage 38 → 377 KB per frame). Work that can leave the main thread does:
`CatalogWorker`, see [free-play](../gameplay/free-play.md). Budget per frame with this in mind: every Lua call counts.

Fixes of that round (this Mac, JIT off, before → after; device numbers are still to be read from the meter):

| | before | after |
|---|---|---|
| Free Play first visit: frames over 16.7 ms · worst update + worst draw | 16 · 67 ms | 0 · 15 ms |
| Free Play textures, all thumbnails (`PREVIEW_CELL` 6 → 4) | 26 MB total | 23 MB total, about 8 MB of it thumbnails (computed) |
| `laberinto_submarino` draw calls (cells of a row merged in the water mesh) | 351–441 | 163 |
| `caldera_roja` garbage per frame (`getOuterBounds(into)` in Gummy, Crabby, Crawler) | 37 KB | 26 KB |
| `caldera_roja` draw CPU | 2.04 ms | 1.79 ms |

Also: `Level:render` skips air cells, `liquidOfRaw` is a table lookup per raw value, `Level:bodyAt` rejects by x before
the bounds call (about 1000 calls per frame in `caldera_roja`), vent bubbles off screen are not drawn. Not attempted without device
numbers: caching tile chunks in canvases (GPU memory for CPU, every animated tile needs a flag), pre-compiling shaders.

**How to extend:** a new scene = a function in `SC` of the harness (+ its name in the default `SCENES`). A new
per-frame system: run `perf GARB=1` before committing it.

**Tests:** `run.sh perf` (in the battery as `perf N=240 PROFILE=0`). Scene `freeplay`: first visit without saved cards, scrolling to the last card; fails if worst update + worst draw ≥ 33 ms. `JIT=0` / `JIT=1` forces the compiler.

**Decisions / history**
- 0.5.2 (2026-10-20): requested by the user ("a complete optimisation round: memory cleanup, optimise code"). The
  measured causes were, in order: per-tile tables in the tile renderer, a full-screen redraw per water cell, the
  server's rewind history copying every entity every tick, a new scene canvas per level, per-call bounding boxes.
- The remaining ~30 KB of Lua per reload are not reachable tables (census empty): most likely interned strings.

- 0.5.11 (review): new scene `map` (the story map, the monster walking stop to stop; lazy loading only reported).
  It found ~77 KB of garbage per frame on the map: `_drawTerrain` created a closure per visible cell (the cliff-edge
  test) and string keys per quad. Now 5.5 KB. `FM_PERF=1` on the server also logs snapshot sizes (see netcode).

- 0.5.182 (2026-11-09, the user: "optimisation / modularisation update: search the whole game for what is slow or
  tangled and rewrite it better without changing what it does"). Measured first (`perf GARB=1`). Garbage per frame,
  before → after: boss (guarida_cangrejo_rey) 51 → 15 KB, caldera_roja 25 → 16 KB, menu 20–36 → 19 KB,
  laberinto_submarino 10.4 → 8.2 KB. JIT off (as on Switch / Android): boss draw 1.65 → 1.37 ms, menu update 0.48 →
  0.33 ms; the Gloomies' path cost in templo_del_eco (`gloomy_rules`) 55 → 38 ms. What it was:
  - `bosswall:render`: a closure and three tables PER CELL per frame and no culling (30 KB/frame in the boss scene).
    Now reused tables and only the cells on screen (the editor still draws all: it zooms).
  - `Level:samples(a, b, into)` and the entity / player collision probes reuse their point lists; boxes that callers
    dropped at once (`inLava`, the player against solid bodies, `Crawler.entityAhead`, the menu bot's safety sim) pass
    an `into`.
  - `Level:getDef` / `getDefAt` call `getRaw` directly and cache raw → definition (they went through getTileAt →
    getTile → getRaw → TileCodec.id → TileTypes.get: five Lua calls for the most repeated query of the game).
  - Lights: `Entity:oneLight` and the mortar refill their own tables; `Darkness.render` lost its two closures per
    frame (its fan cache is now shared and CLEARED per flashlight: it memoises ray lengths).
  - 38 `ipairs({ -1, 1 })` (a table per loop) → a file-level `SIDES`.
  - The harness: `garbage_profile` now also wraps the entity CLASSES (their garbage was charged to the caller:
    `_renderScene` showed 30 KB that were `bosswall:render`), and the per-function table prints UNDER its scene's
    header (it printed above it, so it read as the previous scene's).
  Second pass (same version, 2026-11-10): the story map's terrain went from 611 to 234 draw calls (scene `map`): it
  alternated textures cell by cell (sea, ground, lava, grass blades), which breaks LÖVE's automatic batching. Now one
  pass per texture (nothing overlaps: the blades are 8 px tall, inside their cell) and the cliff faces grouped per ROW
  (faces in one row never overlap; a tall face does reach the row below, so rows keep their order). Checked with
  `perf SCENES=map SHOTS=1` against the old capture: 0 pixels differ. Also `Spikes/liquidInBox` without per-call
  tables, `Crawler.toWorldBox` without its 5 corner tables (same float operations, same order), and the online
  renderer's flashlight list and HUD closures reused. `run.sh` now forwards `FM_PERF=` to its local server (it only
  forwarded `FM_TEST_*`): `run.sh online_boss ... FM_PERF=2` then `/tmp/fm_test_server.log`. Server, Snowball arena
  boss fight: 0.23 ms per room step, 20 KB per step.
  Not done: merging the single-player and server step order (a design decision, known-debt).

