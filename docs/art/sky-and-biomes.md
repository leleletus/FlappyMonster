# Sky, backgrounds and biome art

The background of a level is drawn by `src/fx/Sky.lua` from level data: a SURFACE biome (`background`), the time of
day (`time`), optional `clouds: false`, and an optional DEPTH biome (`depth`) below a surface line (`surfaceRow`).
Art in `assets/images/world/sky/` from `tools/art/world/make_sky.py`. A new biome = PNGs + one entry in `Sky.BIOMES`.
The editor draws the same sky under the map. Lighting on top of it (dusk, night, cave) is in
[dark-levels](../gameplay/dark-levels.md).

## Sky

Level JSON `"background"` (SURFACE biome, default meadow), `"time"` (day|dusk|night, default day),
`"clouds": false`, `"depth"` (optional DEPTH biome: cave, underwater, abyss, icecave, underground)
and `"surfaceRow"` (row whose top is the surface line; default `Sky.autoSurfaceRow` = 2 rows
above the player start, `Sky.AUTO_ABOVE`); editor: Nivel tab → "Fondo y clima" → "Superficie:
fila" (0 = auto; always visible) or Alt + click on the map with the Nivel tab open (the map shows
the line dashed cyan). Without a depth the line is only used when set manually (auto = the old
look: landscape on the level bottom). With a depth, the whole
background is ONE cross-section moving with the nearest surface layer (the user rejected a
world-locked seam: "abrupt, different speeds, unrelated"): horizontal parallax per layer, but
VERTICAL parallax close to the world (`pv(p) = 0.7 + 0.4p`, so deep down no sky shows). The
landscape rests on a background line B (the line seen at ~78 % of the screen); under B a strip
of the surface's own ground colour (`e.bottom` of its nearest opaque layer) + `sky/blend.png`
dither (scrolls sideways WITH the nearest landscape layer, never screen-fixed) into the depth gradient, the depth's `top` layer hangs from there and its ground layers
rest on the level bottom (scissor below B). Every depth biome also has a `wall` (160x160,
repeats in BOTH directions, slow parallax 0.18) so very deep levels (laberinto_submarino,
torre_viento) always have scenery, and the depth gradient spans the whole level depth. Drawn first in
Adventure/OnlineAdventure states (`Sky.render(level, camX, camY)`; `Background.png` is ONLY
for the Flappy mode now). Pixel-banded gradient per time (cave/underwater have their own,
tinted by the time), sun (day; low + orange at dusk) or moon + twinkling stars (night),
drifting clouds, then the biome's silhouette layers (`Sky.BIOMES`: meadow, coast, mountain,
snow, forest, fortress, cave, underwater) repeated horizontally with parallax; ground layers
rest on the level bottom (tall levels show more sky as you climb), `top` layers hang from the
level top (cave ceiling), `add` = additive (underwater rays); outside a layer, its edge row
colour fills the screen. Dusk/night tint layers and clouds. The EDITOR draws the same sky under the map (`drawCanvas`:
`Sky.render(lv, camX, camY)` with WINDOW_W/H = the visible world area, clipped to the level rect;
Sky clips with `Clip` so it works inside the editor's zoom transform), so surface/depth/row
changes show without playtesting (at zoom ≠ 1 the view is larger than a game screen). Art: `assets/images/world/sky/` from
`tools/art/world/make_sky.py` (simple 2-3 tone silhouettes). New biome = PNGs + one BIOMES entry.

## Volcano and meadow biome art

Made for the "retheme" stage (every story level must look like ITS island). Style = the game's: parts with a 4-tone
palette (outline = the darkest tone of the object's OWN colour, never black; light from the top-left), 1-px margin;
the user rejected a first version with black outlines and flat colours ("too simple"). `Canvas.part(mask, pal)`.

- VOLCANO PALETTE v2 (3.63.1): on the world map the volcano island is reddish and so is the levels' sky, but the
  ground was charcoal grey. `BASALT` and `ASH` in `tools/art/world/make_biome_art.py` are now REDDISH (old lava / scoria: 200d10 ·
  3e1a1c · 5c2a26 · 804238; ash 4c1e18 · 8c3e2c · b25c3c · d88856): the two tiles, the rock decorations (basalt_rock,
  basalt_pebbles, ash_pile, lava_vent, glow_rock, steam_stones, lava_fall), the materials' debris colours and the
  thumbnail colours. Charred trees and bushes stay dark. Before / after: `FlappyMonster_pruebas/volcan/`.

- Sky (`tools/art/world/make_sky.py`): surface biome **volcano** (own red ash gradient tinted by the time: volcano with a
  glowing crater and lava streams, basalt ridges, charred trees) and depth **magma** (rock with magma veins, hanging
  basalt with glowing tips, `magma_wall`). Gradients 9 / 10.

- Decorations: `volcano_set` (category Volcán): charred_tree, basalt_rock, lava_fall (hangs, lights, embers),
  dead_bush, basalt_pebbles, ash_pile, lava_vent (smoke + embers, light), glow_rock (light), steam_stones (HOT SPRINGS:
  steam puffs; retheme puts them next to water in volcano levels — carrera01's pools are hot springs, same gameplay);
  `meadow_set` (category Pradera): oak_tree, pine_tree, round_bush, fallen_log, flower_patch, tall_grass, sunflower,
  red_mushroom, mossy_rock. Particle sprite `fx/smoke-Sheet.png`. Preview: `FlappyMonster_pruebas/biomas/vista_previa.png`.
