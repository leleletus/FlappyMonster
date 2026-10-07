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
