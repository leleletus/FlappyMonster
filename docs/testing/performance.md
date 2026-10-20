# Performance and memory

**What:** how the game's cost is measured (frame time, garbage, GPU resources, leaks, the server's tick) and the
rules that keep it low. The game is small, but it runs on Switch and Android: Lua garbage turns into GC pauses,
GPU memory is only freed when Lua's collector runs, and OpenAL voices are few.

**Files**

| File | Role |
|---|---|
| `tools/tests/perf/main.lua` | the harness (`run.sh perf`): real scenes at fixed 1/60 s steps — menu, levels, boss, Flappy, reloads |
| `tools/tests/lib/garbage_profile.lua` | garbage BY FUNCTION: wraps every function of the loaded `src/` modules and counts the KB each one creates, without its callees (allocation-free wrapper) |
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

**How to extend:** a new scene = a function in `SC` of the harness (+ its name in the default `SCENES`). A new
per-frame system: run `perf GARB=1` before committing it.

**Tests:** `run.sh perf` (in the battery as `perf N=240 PROFILE=0`).

**Decisions / history**
- 0.5.2 (2026-10-20): requested by the user ("a complete optimisation round: memory cleanup, optimise code"). The
  measured causes were, in order: per-tile tables in the tile renderer, a full-screen redraw per water cell, the
  server's rewind history copying every entity every tick, a new scene canvas per level, per-call bounding boxes.
- The remaining ~30 KB of Lua per reload are not reachable tables (census empty): most likely interned strings.

- 0.5.11 (review): new scene `map` (the story map, the monster walking stop to stop; lazy loading only reported).
  It found ~77 KB of garbage per frame on the map: `_drawTerrain` created a closure per visible cell (the cliff-edge
  test) and string keys per quad. Now 5.5 KB. `FM_PERF=1` on the server also logs snapshot sizes (see netcode).
