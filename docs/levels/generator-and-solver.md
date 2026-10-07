# Level generator, solver and design numbers

Most levels were written by Python generators and then touched up by hand in the editor.

**DANGER — read first.** `tools/levelgen/build.py` WITHOUT `--only <name>` rewrites EVERY generated level and
destroys the user's hand edits (`--show` does too). Always `python3 tools/levelgen/build.py --only <name>`.
`tools/levelgen/retheme.py` has no `--help`: any unknown flag runs it over every level — always pass level names.

**Files** (`tools/levelgen/`): `lib.py` (grid helpers), `levels_run.py`, `levels_hunt.py`, `levels_koth.py`,
`levels_boss.py`, `levels_water.py`, `levels_batch2.py`, `levels_chase.py` (the builders), `build.py`, `retheme.py`
([retheme](retheme.md)), `add_apples.py` (places food; re-run after a rebuild), `make_sets.py` (film sets),
`arenas/` (test arenas + their generators; boss levels graft them).

**Checks:** `tools/tests/run.sh level_solve -- <level>` (can it be completed? a search with the REAL player
physics), `level_check` (validator + which modes list it + 20 s of entity simulation), `level_shots` (a picture of
the whole level), `bot_nav` for arenas.

## Generator, solver and design numbers

- **Level generator + solver**: `tools/levelgen/` writes levels from Python
  (`lib.py` = grid helpers, `levels_run|hunt|koth|boss.py`, `python3
  tools/levelgen/build.py [--show name]` → `assets/levels/*.json`; boss levels graft
  the proven arenas of `tools/levelgen/arenas/`). Check them with
  `tools/tests/level_solve` (BFS with the REAL player physics: double jump, crouch,
  water, spikes, trampolines emulated; `EXPLORE=1` = every enemy reachable, for hunt)
  and `tools/tests/level_check` (editor validate + which modes list it + 20 s entity
  sim). Design numbers (double jump): one jump ≈ 1.6 tiles, two ≈ 3; gaps ≤ 4 easy;
  a 1-tile tunnel needs a crouch jump; up trampoline ≈ 5 tiles + air control;
  water: exit a 3-deep pool needs a ledge at the surface (drag eats the jumps).
  `build.py` WITHOUT `--only` rewrites every generated level and loses the user's editor
  touch-ups: always `python3 tools/levelgen/build.py --only name`.
  **`build.py --show name` ALSO rewrites every level** (it happened on 2026-10-03: 36 files had to be restored with
  `git checkout HEAD -- assets/levels`). To LOOK at a level, read its JSON (tile id = `raw % 16 + 16 * (raw / 2^17 % 16)`,
  `TileCodec`); never call build.py without `--only`.
  Underwater design numbers: one jump ≈ 1.1 tiles, double ≈ 2.1 (jumps only come back on
  ground) → vertical climbs need footholds: ladders of waterlogged drop-through
  platforms (`DROP + 16`, one per row). Surfacing (head in air) refills air at once;
  vents only give a bubble every 8-26 s, so long water sections need air pockets with a
  ledge to stand and breathe. `laberinto_submarino` (`levels_water.py`): 20x9-chamber
  maze, 1-2 routes to the finish (loops only inside dead branches; asserted), exit = the
  right-column chamber farthest from the start, air ≤ every 2 chambers on the route,
  ~77 pufferfish (gentler on the route), spikes, checkpoints/vents/stars/lives; the
  generator tries seeds until the rules hold. Solver: `NODROWN=1` = terrain only; the
  heuristic is the tunnel distance to the goal (`HDIST=0` = straight line).
  Batch of 15 (race: valle_soleado, cavernas_cristal, torre_viento, fabrica_morteros,
  tren_fugaz (auto-scroll), canon_trampolines; hunt: ciudadela_cangrejos,
  jardin_gummies, mina_inundada; koth: isla_flotante, coliseo_pinchos, cascada_dorada;
  race+boss: ruta_del_espejo, fortaleza_malvada, guarida_cangrejo_rey, lago_helado, glaciar_cangrejo, reino_gummy, gruta_lugubre). Each level
  whitelists its mode with `"modes"`. Ship = bump `version.txt`.

## The second batch and its building pieces

**Batch 2** (`tools/levelgen/levels_batch2.py`, 15 levels, 3.35.0): 10 race + hunt (pradera_explosiva, bosque_interruptores,
playa_rebotes, arrecife_globo, cantera_dinamita, cumbres_escarcha, fabrica_criogenica, templo_del_eco (dark),
jungla_colgante, caldera_roja; ~140-170 x 28) and 5 KOTH arenas 92 x 28 (cantera_real, lago_de_cristal,
ciudadela_alterna, cala_de_los_muelles, cripta_del_silencio (dark)); `modes` also list `hide` (the planned Hide and Seek
mode: unknown ids are ignored today). Built from PIECES laid with a cursor (`c = L.piece(c)`: can't overlap; `put()`
asserts on collisions; `check()` warns about pits inside cellars and patrols without floor): bomb_vault / bomb_wall
(breakable walls a bomb opens; bombs respawn), switch_bridge / switch_door (ON/OFF, with explicit `blockLinks`), lake
(thin ice) / dive_pool (puffers; STEPS on both sides: under water you can't swim up, one jump = 1 tile), freezer_hall,
ice_run, lava_hops, tramp_cliff / tramp_gap, crouch_tunnel, spikefall_hall, mortar_nest, cellar (basement with stair /
breakable-floor entrances), stairs + `upper()`. Built things use `STRUCT` = border rock (retheme doesn't turn it into
grass). RULES learnt: (1) the mandatory route never depends on something that can be lost — only Activators, head
bumps and ground pounds; bombs guard shortcuts and loot. (2) NO continuous upper walkway (v1 had one: the user saw you
could clear the level in a straight line on top) — `upper()` makes SHORT separate sections, one per stairway, with
≥ 9-tile voids between them. (3) Solver flow: `OPEN=1 python3 tools/levelgen/build.py --only x --out assets/levels/_open`
writes the SOLVED variant (breakables removed, ON/OFF as after hitting the Activator) for `level_solve` (which can't
break blocks or use Activators); then build + `retheme.py x` + `level_check`. `level_solve EXPLORE=1` = every enemy and
pickup reachable. Harness `level_shots` renders a whole level to a PNG to review its look.
