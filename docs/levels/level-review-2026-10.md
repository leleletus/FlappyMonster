# Level review and proposals (2026-10-28)

**Status: the user approved the order of work (2026-10-28). Step 2 DONE in 0.5.72: the Gusts of the table below (41,
except the two marked OPTIONAL: `pradera_explosiva` G2 and `tren_fugaz`) and the Blizzard in `torre_viento`.** The user asked (0.5.71): look at absolutely every
level and propose (1) where to place Gusts or which enemies to replace with them, (2) changes, reworks and remakes —
repetitive or simple levels, mechanics not used well, flyers the player cannot reach —, decoration and structure, new
levels, and where the new mechanics (Scale, boxes) fit. The **Blizzard in `torre_viento` is mandatory** (agreed).
The user places the other new props (Scale, boxes, Seed, Geyser) themselves later; this page only suggests where.

Marked images of every proposed Gust: `FlappyMonster_pruebas/niveles_propuesta/<level>.png` (G1, G2… = Gusts;
crossed = enemy replaced). Coordinates are (column, row) of the level grid, 1-based, as in the editor.

## How it was reviewed

- A level shot of all 46 levels (`run.sh level_shots`) and zoomed crops of every hazard the player has to jump
  (spike floors, lava) and of every flying enemy.
- A tile-data pass over every level: hazards, pits, decoration density, which mechanics and special tiles it uses.
- Real-physics reachability (`run.sh level_solve EXPLORE=1`): which enemies and items the player can actually reach
  (section "Unreachable" below).
- Boss arenas, `EnemyTest` and the Mega Mashup are left out of the Gust placement (boss fights have their own design).

## Findings

1. **One skeleton reskinned many times.** `pradera_explosiva`, `bosque_interruptores`, `playa_rebotes`,
   `jungla_colgante`, `cantera_dinamita`, `cumbres_escarcha`, `fabrica_criogenica`, `caldera_roja` and
   `templo_del_eco` (all 28 tall, from `tools/levelgen/levels_batch2.py`) share the same plan: floor at row ~25, spike
   pits every 25-40 columns, an upper route of thin platforms and two floating slabs at rows 12-15 (cols ~16-28,
   ~42-52, ~114-126), a flying enemy at (37, 12) in most of them and two more at ~(110, 12) / ~(140, 12), checkpoints
   at the same thirds. Played in story order the islands feel like the same level with another skin.
2. **The upper third of those levels is empty sky** (rows 1-10): nothing to do there, nothing to see.
3. **Flyers parked over the upper route** at the same coordinates in every level, far above where the player walks:
   they CAN be reached (real-physics check below) but only by leaving the path, so in practice they are skipped and
   add nothing.
4. **Island mechanics stay in one level each.** ON/OFF blocks: 2 levels; thin ice: snow only; floods: bosses and
   bonus arenas; Freezer: 2 levels; bombs: 3. Each island introduces something and forgets it.
5. **Thin decoration** (decorations per 10 columns): `cascada_dorada` 0.4, `cumbre_cangrejo` 0.8,
   `isla_flotante` 1.0, `lago_helado` 1.1, `isla_del_groove` 1.2, `canon_trampolines` 1.4, `tren_fugaz` 1.4,
   `marea_alta` 1.5, `reino_gummy` 1.6, `guarida_cangrejo_rey` 1.7, `glaciar_cangrejo` 1.7, `playa_rebotes` 1.8,
   `cala_resaca` 1.8, `fortaleza_malvada` 1.8 — against 5-9 in the best-dressed ones (`cripta_del_silencio`,
   `mina_inundada`, `nivel01`, `torre_viento`).
6. **Fortress levels read flat**: the same wall-with-towers silhouette for 120-170 columns (`fabrica_morteros`,
   `tren_fugaz`, `cantera_dinamita`), little foreground.

## Global proposals

- **A signature mechanic set per island**, reused across its 4 levels and growing in difficulty:
  - Meadow: bombs + boxes + Seed (beanstalk), the Gust as a dandelion puff (introduced gently in 1-1).
  - Coast: water Geysers, Gust (foam), floods/tides, pufferfish.
  - Fortress: Scale + big/small boxes + steam Geysers + mortars and bombs (puzzles: weigh a pan down with a box to
    raise a platform, ground-pound to launch).
  - Snow: Blizzard, ice Geysers (temporary pillars), thin ice, Freezer.
  - Caves: darkness, Seed mushrooms (they give light), glowing steam Geysers, hoppers and Gloomies (the Gust's blow is
    a noise: it lures them).
  - Volcano: lava, smoke Geysers, Gust (ash), ember-vine Seeds as stepping stones near lava.
- **Break the shared skeleton**: every templated level gets its own macro-shape (below). Keep what works (pacing,
  checkpoints) but change heights, routes and set pieces.
- **Rule for flyers**: a flying enemy must be within ~3 tiles of a route the player actually takes, or it is moved
  or replaced (often by a Gust, which is designed to hover near the path).
- **Decoration pass**: target ≥ 4 decorations / 10 columns in every story level, with foreground clusters near set
  pieces, not evenly sprinkled.
- **Use the vertical space**: in 28-tall levels, the upper third becomes an optional high route with its own reward
  (stars / extra life) instead of empty sky.

## Gust placements (all levels)

Rule of thumb used: the Gust hovers on the FAR side of a hazard, ~2 tiles above the floor, so it catches the player in
the middle of the jump (it turns to face the player by itself). Few in world 1, more later. Autoscroll levels get none
or one optional (being blown back against the scroll is a death), underwater sections none.

| Level | Gusts (col, row) | Notes |
|---|---|---|
| `valle_soleado` (1-1) | G1 (53, 10) | Intro: after the first 3-wide spike pit (48-50). Nothing at the long spike floor (88-107): too hard for 1-1 |
| `pradera_explosiva` (1-2) | G1 (107, 19) replaces flying Gummy (102, 18) · G2 (134, 19) optional | G1 over the pit 101-104; G2 by the bombs: blown bombs roll |
| `bosque_interruptores` (1-3) | G1 (75, 19) · G2 (110, 11) replaces flying Gummy (110, 11) | G2 on the upper path between spike floors: blows the player off the platform |
| `isla_flotante` (bonus) | G1 (36, 11) | Next to the floating island with the point zone: pushes players off it |
| `playa_rebotes` (2-1) | G1 (94, 19) · G2 (151, 19) | After the pools 82-91 and 140-148 |
| `jungla_colgante` (2-2) | G1 (89, 19) replaces flying Gummy (85, 18) · G2 (136, 19) | |
| `canon_trampolines` (2-3) | G1 (52, 14) · G2 (99, 13) | G2 at the end of the long spike floor 71-96: blows at players bouncing between trampoline platforms |
| `arrecife_globo` (2-4) | G1 (73, 11) replaces flying Gummy (73, 11) | On the beach; nothing in the underwater part |
| `cala_de_los_muelles` (bonus) | G1 (46, 5) replaces flying Gummy (46, 5) | Above the point zone |
| `fabrica_morteros` (3-1) | G1 (87, 9) | Far side of the spike floor 64-84 crossed on grey platforms, with the mortars |
| `cantera_dinamita` (3-2) | G1 (34, 19) · G2 (97, 18) replaces flying Gummy (97, 18) · G3 (126, 19) | Bombs nearby get blown too |
| `taller_trampas` (3-3) | G1 (42, 8) | In the right part, across the platform ladder |
| `tren_fugaz` (3-4, autoscroll) | G1 (129, 7) OPTIONAL | Only if the user wants it hard: blown back = crushed by the scroll |
| `ciudadela_alterna` (bonus) | G1 (46, 19) | Between the two spike pools |
| `cumbres_escarcha` (4-1) | G1 (98, 19) · G2 (154, 19) | Snow cloudlet Gusts |
| `fabrica_criogenica` (4-2) | G1 (41, 19) · G2 (116, 19) | With the Freezers: a frozen player is blown like a block |
| `torre_viento` (4-4) | none (the Blizzard does it) or 1 near the top | See the Blizzard section |
| `lago_de_cristal` (bonus) | G1 (46, 20) | Over the lower zone |
| `cavernas_cristal` (5-1) | G1 (81, 18) · G2 (131, 18) | |
| `nivel01` (5-2) | G1 (20, 24) | One corridor only: the level is a tight maze |
| `laberinto_submarino` (5-3) | none | Underwater |
| `templo_del_eco` (5-4, dark) | G1 (46, 19) · G2 (119, 19) | The blow is a NOISE: it lures the Gloomies to the player — the cave twist |
| `cripta_del_silencio` (bonus, dark) | G1 (46, 17) | Its noise drags Gloomies onto the zone |
| `carrera01` (6-1) | G1 (46, 8) | After the long spike floor 30-43 |
| `caldera_roja` (6-2) | G1 (34, 19) · G2 (60, 20) replaces flying Gummy (60, 20) · G3 (128, 19) | Over the three lava pools: ash Gusts |
| `lluvia_pinchos` (6-3, autoscroll) | none | Already chaotic (spike rain) |
| `huida_del_espejo` (6-4, chase) | none | Being pushed back in a chase is unfair |
| `cantera_real` (bonus) | G1 (46, 10) replaces flying Gummy (46, 10) | Above the zone |
| `jardin_gummies` (hunt) | G1 (61, 10) · G2 (111, 10) | |
| `ciudadela_cangrejos` (hunt) | G1 (30, 8) · G2 (70, 8) | On the upper tiers |
| `mina_inundada` (hunt) | G1 (50, 10) | Upper corridor |
| `coliseo_pinchos` (koth) | G1 (20, 15) | With the spike rain: pushes players under it |
| `cascada_dorada`, `rebote_real`, `cumbre_cangrejo`, `marea_alta` | none | Too small: a Gust would dominate the arena |

About 40 Gusts in 30 levels. Every replaced enemy is a flying Gummy hovering over a hazard — the spots where the Gust's
push matters most.

## Torre del Viento — the Blizzard (agreed, mandatory)

- One `blizzard` area over the climb (cols 2-43, rows 4-54), all four directions, `warn` 1 s, wind 2-3 s, calm 4-8 s
  (`gapMin` 4, `gapMax` 8: slightly longer than the default so the climb stays fair), `power` 0.8 to start.
- Down-wind is the dangerous one (it drags the player down the tower): either keep it rare (a second area for the
  top third with `dir_down` off) or give the tower more ledges to land on.
- The tower itself is a regular zig-zag of identical plank platforms (see the shot): rework it into varied ledges —
  ice blocks, a few thin-ice platforms, nooks to shelter from the wind (a wall on one side = safe from that
  direction), the checkpoint in a sheltered alcove. That makes the Blizzard a decision (wait in a nook / go) instead of
  noise.
- Optional: one Gust near the top (its blow plus a Blizzard gust = the climax).

## Per level: reworks and other changes

World 1 — Meadow
- `valle_soleado` (1-1): good intro, fine pacing. Add the Gust intro (G1). Decoration 3.1 → more foreground
  bushes / fences near the start. Keep simple.
- `pradera_explosiva` (1-2): templated. Rework: make it the BOMB level for real — breakable walls that hide the
  route, a box you push under a bomb ledge, a big box + Seed puzzle to reach the upper floating island (use the empty
  sky). Replace the flyer at (37, 12) (parked over the upper route) with a walking Gummy on that route.
- `bosque_interruptores` (1-3): the ON/OFF idea is good but used twice. Rework around ON/OFF + the first Scale (a
  switch block that only holds when the other pan is weighted). Upper path with spikes is good: keep, add G2.
- `isla_flotante` (bonus): decoration 1.0 — dress the floating island and the ground (trees, flowers).

World 2 — Coast
- `playa_rebotes` (2-1): templated, decoration 1.8. Rework into a beach with tide pools: water Geysers in the
  pools (launch to the upper route), small boxes to carry and stack to reach a shell bonus.
- `jungla_colgante` (2-2): templated. Rework around HANGING structures (as the name says): long vines/Seed kelp,
  platforms that hang from the rock overhangs, a Scale hanging from the big overhang at 48-58.
- `canon_trampolines` (2-3): good identity (trampolines), but decoration 1.4 and a 26-wide spike floor crossed the
  same way. Add Geysers as "natural trampolines" in the second half, more palms/rocks.
- `arrecife_globo` (2-4): the surface is a flat strip with 3 flyers; the underwater part is good. Rework the
  surface into an islet chain with Geysers between islets.

World 3 — Fortress
- `fabrica_morteros` (3-1): flat silhouette. The factory should introduce the SCALE + BOXES (a crate line, a
  freight scale lifting the player over the long spike floor). Decoration 2.8 → chains, crates, banners.
- `cantera_dinamita` (3-2): templated. Rework as a quarry with boxes of dynamite: small boxes to carry next to
  bombs, a big box to push into a pit to cross it, rubble that bombs clear.
- `taller_trampas` (3-3): short and dense, good. Add steam Geysers in the lower workshop.
- `tren_fugaz` (3-4): 170 columns of the same towers; add variety in the scroll (tunnels, a bridge over a gorge,
  wagons as platforms with small boxes on top that the player can push off).

World 4 — Snow
- `cumbres_escarcha` (4-1): templated. Rework as a mountain climb (it has none of the vertical feel of "peaks"):
  ice Geysers as temporary pillars to climb a cliff, thin ice over pools.
- `fabrica_criogenica` (4-2): templated but the Freezers give it identity. Add ice Geysers and use ON/OFF more.
- `lago_helado` (4-3, boss) and `glaciar_cangrejo` (boss): decoration 1.1 / 1.7 — dress them (snowy pines,
  icicles, frozen rocks).
- `torre_viento` (4-4): the Blizzard (above) + tower rework.

World 5 — Caves
- `cavernas_cristal` (5-1): fine. Add a glowing-steam Geyser and a Seed mushroom (light) in the darker middle.
- `nivel01` (5-2): dense and well decorated (7.8). Keep.
- `laberinto_submarino` (5-3): strong level. Keep.
- `templo_del_eco` (5-4): templated under the darkness. Rework the layout (temple halls, a vertical section) and use
  Seed mushrooms as light sources + the Gust noise.

World 6 — Volcano / final
- `carrera01` (6-1): fine. G1.
- `caldera_roja` (6-2): templated; the three lava pools with stepping stones are identical. Make each pool different:
  smoke Geysers in one, a Scale over another (weight one pan to raise stones), ember-vine Seeds in the third.
- `lluvia_pinchos`, `huida_del_espejo`: keep (autoscroll set pieces).

Bonus / online arenas
- `cascada_dorada` (0.4), `cumbre_cangrejo` (0.8), `marea_alta` (1.5): decorate.
- `cala_de_los_muelles`: add a water Geyser that launches to the upper zone.
- `ciudadela_alterna`, `lago_de_cristal`, `cantera_real`: the Gusts above; a Scale in `ciudadela_alterna` (one
  zone on each pan: the heavier team sinks).

Boss arenas (no Gusts): only decoration (`reino_gummy` 1.6, `guarida_cangrejo_rey` 1.7, `cala_resaca` 1.8,
`fortaleza_malvada` 1.8, `isla_del_groove` 1.2).

## New levels (proposals)

One per island, each built around the new mechanics (they would be bonus/secret levels or replace a templated one —
the user decides; ids never rename existing levels):
- **Meadow — "Molino del Valle"**: a windmill: Gusts as the mill's wind, Scales as the grain scales, sacks = boxes.
- **Coast — "Géiseres de la Bahía"**: an archipelago crossed riding water Geysers, which also lift boxes into place
  to build stairs.
- **Fortress — "La Báscula"**: a puzzle fortress: Scales, big and small boxes, ground-pound catapults, steam.
- **Snow — "Cumbre Ventisca"**: an outdoor climb with the Blizzard and ice Geyser pillars.
- **Caves — "Jardín de Setas"**: dark caves lit by planting Seed mushrooms where you need light.
- **Volcano — "Fumarolas"**: smoke Geysers over lava, ash Gusts, ember-vine Seeds.

## Unreachable (real physics, `level_solve EXPLORE=1`, 300 000 states per level)

The solver does not flip ON/OFF switches, ride trampolines or break blocks reliably, so most "unreachable" entries are
behind those on purpose. Sorted:

- **All reachable**: `valle_soleado`, `canon_trampolines`, `cala_de_los_muelles`, `cantera_real`,
  `ciudadela_alterna`, `cascada_dorada`, `cumbre_cangrejo`, `huida_del_espejo`, `ciudadela_cangrejos`,
  `coliseo_pinchos`, `jardin_gummies`, `mina_inundada`, `lluvia_pinchos`, `marea_alta`, `lago_de_cristal`,
  `rebote_real`, `taller_trampas`, `tren_fugaz`. **No flying enemy was found unreachable** in any level.
- **Behind breakable walls (bomb puzzles, by design)**: `pradera_explosiva` (3 stars + extra life at 36-38/20,
  stars 116-118/20…), `cantera_dinamita`, `caldera_roja` (107-109/20), `templo_del_eco` (84-86/20),
  `fabrica_morteros` (extra life 94/14).
- **Behind ON/OFF switches** (the solver cannot press them): `bosque_interruptores` (half the level),
  `jungla_colgante`, `fabrica_criogenica` (4/28: an ON/OFF block gates the route early). Not a problem of the levels.
- **Budget ran out** (exploration incomplete): `torre_viento`, `arrecife_globo`, `playa_rebotes`.
- **Worth a manual check** (nothing obvious blocks them): `isla_flotante` stars (18, 7) and (42, 7) (probably via
  the trampolines), `carrera01` extra life (76, 16) and two magma Gummies (72, 17), (80, 17) in an underground pocket
  (probably via breakable blocks), `cumbres_escarcha` extra life (78, 24) in the ice pool, `cavernas_cristal` star
  (128, 15) and crab (135, 16) by the water near the end, `nivel01` (water sections: the solver struggles there).

## Order of work (proposal)

1. The user approves / edits this page.
2. ~~Gusts (quick: placements above) + the Blizzard in `torre_viento`~~ — DONE 0.5.72 (replaced flyers keep their
   index in the entity list: the story save remembers taken extra lives by index; new Gusts are appended). The user
   then asked for wider blows (2.8 tiles) and Gusts that WANDER an area like the pufferfish (free flight, 3 tiles
   around their spot); the bot was taught about wind (see story/bonus-and-bot); menu scene seeds re-picked
   (`menu_flow FINDSEED`) and nav graphs rebuilt.
3. Reworks of the templated levels, one island at a time (they need the user's playtesting).
4. Decoration passes (fast, low risk).
5. New levels.
