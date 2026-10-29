# Level themes (`retheme.py`)

`tools/levelgen/retheme.py <levels>` re-dresses a level by its island's THEME with zero gameplay change: terrain
blocks (grass / dirt / stone / sand / snow / ash / basalt), sky, decorations on the right material, and with
`--enemies` the island's enemy variants. Themes follow `src/story/Worlds.lua`. **Always pass level names** and prefer
the narrow modes on levels the user has hand-edited.

## Details

**Story retheme (by island)**: THEMES now follows `src/story/Worlds.lua` — meadow (temperate: no palms/ferns/hibiscus),
`beach` (sand, playa_rebotes), fortress (tren_fugaz), snow (fabrica_criogenica), cave (nivel01, laberinto_submarino:
background cave, music dark_cave), volcano (carrera01, caldera_roja, lluvia_pinchos — moved to the Volcano world —,
ruta_del_espejo: terrain → ash/basalt, sky volcano, depth magma, boss walls basalt). `--decor --fix --theme` also swaps
decorations of ANOTHER biome (palms in the meadow, corals/shells in snow or fortress water: `NO_SEA`, `SEA_LIFE`,
`EXTRA_OK`) for one of the level's theme.

The levels were built when stone was the only block. `retheme.py` re-dresses them by
THEME (table `THEMES`: meadow, tropical, snow, cave, mine, underwater, fortress) with
ZERO gameplay change (stone/dirt/grass/snow are identical for physics): solid blocks and
the frame's bottom row → surface of the theme where the top is in the air (grass / snow /
dirt / stone), dirt 2-3 rows below, stone deeper; SAND 2 deep under water (sea floor) and on
meadow/tropical shores (water ≤ 3 columns away; shells/starfish/palms on it); snow: small one-row islands → ice (+
`"snow": true`). Then decorations by theme on floors (planks: small ones only), ceilings
and underwater floors, always `layer = 'back'`, never on spikes/entities/start/finish/
vents/boss walls/boss arenas. `--force` re-rolls only its own decorations (the ones with
`layer='back'` of its types; hand-placed ones stay); `--terrain` also re-decides dirt/grass/
snow/sand blocks (overrides hand-placed ones); `--tiles` = terrain only (decorations untouched);
Theme **frozen_coast** (the Frozen Coast island, 2026-10-29) behaves like snow (`ICY` = snow + frozen_coast: falling
snow, ice spikes, loose one-row islands → ice, icy enemies, no sand / deep stone under water) with its own decorations
(`frozen_coast_set`; the floating `floe` is placed by hand on the cell above the water). No level uses it yet.
`--deep` = ONLY ground ≥ 4 rows under a water surface → deep stone (any theme but snow; the
'underwater' theme also below 45 % of the height); `--sky` = writes the SKY table's background/
time only into levels that don't set them. The user edits levels by hand afterwards: prefer the
narrow modes (`--deep`, `--sky`, `--tiles`) over `--force`/`--terrain` on levels they touched. Seeded per level (stable). Writes the
editor's JSON format. Run it again after `build.py --only x`. New levels: add a THEMES row.

**Decorations go on THEIR material** (user's rule: no plants, palms or flowers growing out of rock, snow, sand or a
girder). `retheme.py` table `REQ` = the tile that must support each decoration type (the one below; hanging ones, the one
above): plants → grass/dirt (tropical ones also sand), snow things → snow (piles also on planks), rock formations →
stone/deep stone/border (+ dirt), mushrooms also on wood, shells/starfish → sand, aquatic ones only in water; nothing
hangs from the top FRAME under an open sky (only in closed themes `CLOSED` / levels in `ROOFED`). The placer filters by
it, and `retheme.py --decor [--fix] [levels]` audits EVERY decoration of every level (auto or hand-placed): `--fix`
swaps a misplaced one for something of the theme that fits there, or removes it (251 + 113 fixed in the old levels:
palm trees on stone in fortaleza_malvada, tulips on girders, icicles hanging from the sky...). Themes added: `forest`,
`volcano`.

## Background-plane structures (`--bg`)

`retheme.py --bg <levels>` fills the [background plane](../art/background-plane.md) (`bgTiles` + decorations with
`"plane": "bg"`) with structures of the level's island where there is open space behind the playable layer. The
generator lives in `tools/levelgen/retheme_bg.py` (table `SPEC`, one entry per theme); `retheme.py` only parses the
command line.

| Theme | Plane blocks | Plane decorations |
|---|---|---|
| meadow / forest | rolling hills (grass cap over dirt), ramps of one step every 1-2 columns | big_oak, big_birch, big_fir (forest: more firs); hazel bush, boulder, stump on the hills |
| beach / tropical | sand dunes; sandstone outcrops (tropical: grass cap) — stone on the plane reads almost black in daylight, so the outcrops are SAND | coconut_palm, twin_palm, young_palm on sand / grass (front floor or plane top) |
| fortress | stone walls with alternate merlons and 1×2 windows, 4-wide towers with a slit | banner and hanging ivy ON the wall face; cypress, old_tree; urns on top |
| snow | snow drifts; snow walls with an ICE crest (ice is translucent: reads as glacier); frozen-brick ruins (`frostwall`, 2026-10-29: `frost_brick` with merlons, `frost_window` every 3 columns, an `ice_rock` foot) | snowy_fir, snowy_fir_small (on snow only) |
| cave / mine / underwater | floor mounds; rock hanging from the ceiling in irregular bands (≤ 45 % of the cavity); now and then a 2-wide floor-to-ceiling column in a wide, clear spot (never against a front wall). mine: dirt top, underwater: deep stone | giant_mushroom(_violet), cave_crystals, cave_boulder, mushroom_cluster; stalactites under the hanging rock |
| volcano | basalt spires (one full column, shorter ones beside it), jagged basalt walls, ash mounds | dead_tree; charred stump, basalt rock, obsidian shards |
| frozen_coast | low snow drifts and ice walls (sea level, no forest) | a rare snowy_fir_small; iceberg, snow rock on top |
| jungle | temple ruins (`temple_brick`): colonnades with a lintel (a piece fallen, one column broken) and arch springers, stepped pyramids, broken walls; low jungle-grass hills | ceiba, strangler_fig; lianas / moss hanging from the lintels; broken pillar, idol, fallen block on top |

**Readability rules** (the path must stay readable): nothing on the plane behind or 1 tile around spikes, lava, water,
platforms and loose (non-terrain) blocks — 2 tiles above them, where the player lands —, readable entities (traps,
mechanisms, items: `READ_ENTS`; falling ones also down their column), checkpoints, the finish, the start, boss zones
(+3 columns, their arena keeps its own plane) and boss walls. LIGHT zones (start ±8 columns, finish ±7, checkpoints ±4)
only get things 2 tiles high and no big trees. Structures stand on front terrain (blocks joined to the frame or masses
of ≥ 12), are never taller than the free space above them minus 1 (they shrink whole, no notches), fill 2 rows down
into the hidden terrain (no bottom edge shows) and never overlap the user's plane. Big decorations must fit their
whole box in front-empty, allowed space and never hide a plane structure; enemies don't count (they read on the dark
plane by themselves).

**Safety and tagging.** `--bg` refuses to run without level names (`--bg-all` = every THEMES level, on purpose) and
rejects names without a theme; any unknown flag now stops `retheme.py` without touching anything. Generated content is
listed in a sidecar `tools/levelgen/bg_gen/<level>.json` (`{level, w, h, tiles: [[col,row,raw]…], decos: [...]}`), not
in the level: the editor drops unknown level keys on save, and a sidecar survives that. A level whose plane has no
sidecar (or whose sidecar entries are all gone, e.g. after `build.py --only`) counts as hand-made and is never touched.
`--force` removes only the listed cells / decorations that are still identical in the level (whatever the user
changed or added is theirs), then regenerates around what remains. Seeded per level (stable).

```
python3 tools/levelgen/retheme.py --bg valle_soleado                       # writes assets/levels + bg_gen/
python3 tools/levelgen/retheme.py --bg --force valle_soleado               # redo only the generated part
python3 tools/levelgen/retheme.py --bg --dry valle_soleado                 # count only
python3 tools/levelgen/retheme.py --bg --out <dir> valle_soleado ...       # COPIES in <dir> (+ <dir>/<level>.bggen.json)
tools/tests/run.sh level_shots SCALE=0.35 -- <dir>/valle_soleado.json     # look at it (LIGHT=0 for dark levels)
```

Frozen pack (2026-10-29, tiles 50-58, [tiles-and-blocks](../gameplay/tiles-and-blocks.md) § The frozen pack): the ids are
constants in `retheme.py` (`FBRICK`, `IROCK`, `IBRICK`, `GLACIER`, `SBRICK`, `IPILLAR`, `FWINDOW`, `FPLAT`, `ILEDGE`)
and count as `GROUND` (never converted by the terrain pass: they are the user's construction). Decorations: snow
things also on `snow_brick`, rock things and icicles also on frost brick / ice rock / window, icicles also under
`ice_brick` / `glacier_ice`. `PLATFORM_OF` = the drop-through platform of each theme (`jungle` → `jungle_platform`,
`snow` → `frost_platform`; a new theme such as `frozen_coast` = one entry). Tried on COPIES of snow levels with their
plane removed (`FlappyMonster_pruebas/tiles_helados/plano_fondo/`); not run on any real level.

History: 0.5.87, first version (user approved "Island structures"). Previews on copies in
`FlappyMonster_pruebas/plano_fondo/generado/` (one level per island; jungle tried on a copy of valle_soleado because
its only level, templo_escarabajo, has a hand-made plane). Tried and changed: stone outcrops on the beach (near-black
in daylight → sandstone); 1-high hills (read as dark slabs → hills are ≥ 2 high and ≥ 3 columns); 1-wide volcano
spires (read as chimneys → 2-4 wide); 3-wide towers with a centre window (read as an "H" → 4 wide, side slit); ice
walls of solid ice (ghostly → snow body, ice crest). Not applied to any real level yet.
