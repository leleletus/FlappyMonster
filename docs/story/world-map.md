# The world map

One big scrolling map in the style of Super Mario World: six islands, one path per world with a node per level, a
castle for the boss, a blue "B" bonus node, bridges between worlds, wandering critters and the hero walking along the
path — plus a seventh island, the JUNGLE, drawn as "coming soon" ([below](#the-jungle-island-coming-soon)). Everything about its shape is DATA in `assets/story/overworld.json`, written by a deterministic generator.

**Files:** `src/states/story/StoryMapState.lua` (drawing, walking, input, camera, the films' map set),
`tools/art/story/make_overworld.py` (writes `overworld.json` and the sprites in `assets/images/story/`),
`tools/art/ui/make_story_icons.py`. **Music:** `map_<world>`; the arrangement switches with the island nearest the
hero at the same position of the tune (`Sound.switchMusic`), with a CROSSFADE (0.5.95, the user: the hard switch was
noticeable): the old arrangement fades out while the new one fades in at the same position, `Sound.XFADE` 1.2 s,
equal-power curve (`sounds` harness: "fundido del mapa").

**Controls:** each arrow goes to the neighbouring stop that lies that way on the map; tap a node to walk there, tap
your own to play; ENTER plays. Rules (`dirMap` in `StoryMapState.lua`): neighbours of a stop = previous and next
along the path, plus the bridge to the next island from a castle (and back from an island's first level). (1) What
counts is where the neighbouring NODE is. (2) Every neighbour always has an arrow of its own: the clearest direction
wins; between two equally clear (the level next door and, far away, the next island, both straight left) the NEAREST
node wins and the other takes the arrow that points where its path leaves. (3) A free arrow goes to a neighbour only
if it really points at it (a diagonal neighbour answers both of its arrows); otherwise it does NOTHING. (4) Presses
while walking chain from where the hero is going.
History: the first version (same week) looked at where the PATH left the node, left about 10 % of neighbours with
no arrow, and when no path matched fell back to previous / next (left / right) or jumped a whole island (up /
down) — the user: "it works quite badly, uncomfortable, and often does strange things". Rewritten 2026-10-08.
`story_flow` checks every stop of the real map (`MAPDBG=1` prints where each arrow leads). Not yet judged by the
user.

**To change the map:** edit the tables in `make_overworld.py` (terrain, relief, paths, decorations, `CRITTERS`,
`NODE_BOSS`) and re-run it; never hand-edit `overworld.json`. Adding a level to a world needs nothing here: nodes
are spread along the path from `Worlds.lua`. **Harness:** `story_flow` (captures at three widths,
`story_map_full.png`, `story_map_bosses.png`).

## The jungle island (coming soon)

The island after the Coast (`jungla`, `src/world/level/Isles.lua`; boss the [Giant Rhino Beetle](../bosses/giantbeetle.md),
level `templo_escarabajo`, Free Play only today) is on the map with NO levels yet: data + art only.

- **Where:** SOUTH of the gap between the Coast and the Fortress. The map grew downwards from 84x48 to 84x63 cells
  (`H`; `H0 = 48` is the old height). The six story islands are untouched: every random loop of the generator for
  them runs only to `H0`, and the jungle comes at the END of the generator with its own seed (`jrng`), like the
  secret islet — `overworld.json` rows, heights, decorations and critters of the old map are identical (checked by
  diffing the JSON when it was added).
- **What:** terrain `j` (dark jungle grass: `jungle_grass` lip, `mud` cliff body, `jungle_blades` tufts) and `t`
  (temple stone plaza around the castle: `temple_brick`); a plateau inside the path's loop with the hand-placed
  ZIGGURAT; new feature sprites drawn by the generator in the features' house style — `jungle_tree` (round canopy on
  a trunk), `ziggurat` (three stepped tiers, stairs, moss, dark door), `ruin` (broken mossy wall) — plus the game's
  jungle decorations (`jungle_fern`, `heliconia`, `banana_plant`, `elephant_ear`, `tree_fern`, `bromeliad`,
  `broken_pillar`, `stone_idol`, `stone_brazier`: `DECO` in `StoryMapState`); critters: jungle Gummy (tree frog),
  jungle Crabby, the blue Rhino Beetle (`beetle`, new `CRITTER`), the jungle Hopper, two pufferfish. The boss art is
  `giantbeetle/body-Sheet.png` (fw 22) beside a red-flag castle.
- **Data:** `overworld.json` `soon = [{ id, path, stops, boss, bridges, label }]` (NOT in `worlds`: that list is
  read by position = `Worlds.LIST` index). `StoryMapState.loadMap` builds `MAP.soon`: `stops` sample nodes spread
  along the path (the last one = the castle), the boss side, the bridges, and path dots with `soon = true` (always
  drawn locked). `_drawSoon` draws grey nodes, the castle + boss and the label (`story.world.jungla` +
  `story.soon`, "PRÓXIMAMENTE" pulsing). They are NOT stops: `stopIndex` / `dirMap` / `_nodeAt` / `totalStops` only
  know `Worlds`, so no arrow, tap or walk can reach them and the hero can never be on the island.
- **Bridges:** two LOCKED (dark) bridges — Coast castle → down the 1-cell canal between the Coast and its bonus
  strip → the jungle's first sample node; the jungle castle → up the channel west of the Fortress → the Fortress's
  first node. The Coast → Fortress bridge (`connect[2]`) is unchanged: that is still how the hero walks.
- **Music:** `_music` also measures the jungle's sample nodes; when one is nearer than every real node AND
  `Music.get('map_jungla')` exists it plays `map_jungla`, otherwise the old rule. Today the hero only stands on or
  walks between real stops, all nearer than the jungle, so in practice the jungle track will play once the island
  has stops.
- **Films:** `StoryMapState.mapSize()` returns `view` (84x48 cells = the six islands), so the films that centre or
  clamp on the map frame exactly as before; the jungle stays out of them.

**Why it is NOT in `Worlds.LIST` yet:** the saves and the progression address worlds BY INDEX: `Run.worldOpen(w)`
opens world w when the boss of w-1 is done, `Run.frontier()` walks the list in order, the save keeps `world` /
`node` (where the hero stands) and `worldReward[w]` (the once-per-world reward) by index, and `overworld.json`
`worlds[i]` / `connect[i]` are read by the same index. A world with no levels has no boss to beat (nothing would
ever open the Fortress), and inserting it as world 3 would shift every saved `world` and `worldReward` of existing
slots onto the wrong island.

**To give it levels later:** (1) add `{ id = 'jungla', levels = {...}, boss = 'templo_escarabajo', bonus = ... }`
to `Worlds.LIST` right after `costa` (add the boss to `Shards`/films if it needs them); (2) migrate old saves that
are past the Coast (`Run.data.world` ≥ 3 → +1, `worldReward` keys ≥ 3 → +1; the Fortress opens on the jungle boss,
so a save that already beat the Coast boss must be handled — e.g. treat the jungle as open but not required, or
mark it done; decide with the user); (3) in `make_overworld.py` move the jungle from `soon` into `ORDER` / `PATHS` /
`BOSS_ART` (path = `JPATH`, `LAND` 'j', `ISLE_TYPES` already know it), replace `CONNECT[1]` (Coast → Fortress) with
the two `JBRIDGES` (Coast castle → jungle first node, jungle castle → Fortress first node), add its `BONUS`, and
drop `soon`; (4) `THEME.jungla` in `StoryMapState`; (5) `story_flow` (`direccion` counts the stops, `musica` wants
`map_jungla`), `story-mode.md`, the shards / Mirror counts if a shard is added.

## How it is built and drawn

- `StorySlotState` (pick / create / delete with confirmation) and `StoryMapState` = the WORLD MAP (stage 5, Super Mario
  World style): ONE big scrolling map (84x63 cells of 32 px; the six story islands in the top 84x48) from DATA `assets/story/overworld.json`, written by
  `tools/art/story/make_overworld.py` (deterministic; also writes `assets/images/story/` node/castle/water/path/bridge/ground/
  edge/foam sprites): terrain letters per cell (`~` sea, g grass, s sand, w snow, c cave rock, f fortress stone, l volcanic
  rock, L lava = the game's lava.png animated, j jungle grass, t temple stone) + `heights` per cell (0 pit, 1 plain, 2 plateau, 3 summit; RELIEF table
  of wobbly blobs per island, never within ~2 cells of a path — paths run along the VALLEYS —, min 2x2, cave pits,
  the volcano's lava crater): the game tints tops by height (`LIT`) and draws a CLIFF under every cell higher than the
  one below (lip = its block texture, body = `CLIFF_BODY`, 0.75 cell per level) + rim edges where a neighbour is
  lower. Landmarks = `assets/images/story/features/*.png` (hill, dune, peak, spire*, rock_*, cave_mouth; drawn ×3; a
  deco name not in `DECO` is looked up there; `oy` = feet offset in cells, used by cave mouths on cliff faces). Paths
  and bridges are Catmull-Rom curves through control points (generator `catmull`, stored smoothed). One PATH per world (its `Worlds` levels are spread evenly along it
  by arc length, however many there are, boss last = a CASTLE with the boss sprite small beside it, gold flag once beaten),
  bridges between worlds (`connect`; planks over water), decorations and wandering critters (the game's own sprites at ×2),
  per-world boss art (`worlds[i].boss` {img, fw, over, glow, fly, invert}). Island tops = ground tiles coloured from the
  game's blocks; CLIFF faces under land facing the sea = the real block textures seen from the side (grass/sand/snow/
  stone/border/deep_stone). The hero (monstrito walk frames) WALKS along the path: ←→ = previous / next level (crosses
  worlds over the bridge; a locked stop stops it with a bump), ↑↓ = walk to the next world's first level / previous
  world's boss; long trips speed up (~1 s). `self.world/self.node` change at once (the walk is visual; ENTER while walking
  snaps and plays). Tap a node = walk there (tap your own = play); bottom arrows = previous / next. Camera follows the
  hero between the top band (TOP_H) and the level card (BOT_H), clamped to the map. The boss stands on the side of
  its castle that has LAND (`bossDx/bossDy`, right → left → below). Bridges are always opaque (locked = darker) and run
  2 planks onto each shore. FULL MAP for review: `StoryMapState:renderFull()` → `story_flow` writes
  `story_map_full.png` (2688x2016, every world open); copy it to `FlappyMonster_pruebas/mapa/mapa_completo.png`. Bonus nodes (KOTH vs bot) = stage 8.
  `PixelFont.draw` draws ONLY the letters (it used to fill a tight black box behind them: fine on the black menus,
  odd everywhere else — the user had it removed); over coloured backgrounds use `PixelFont.shadow` (1-font-pixel black
  drop shadow).

- Map boss art data (`overworld.json` `worlds[i].boss`): `under` = drawn inside (the Evil Monster in its ship),
  `overBig` = the `over` image only at full size (the crown: only the Gummy King has it); small = no Mega claws.

## Critters per island

- 3.83.1 WORLD MAP critters per island (it only had the plain Gummy / Crabby + icy ones + Gloomies): in
  `tools/art/story/make_overworld.py` the `CRITTERS` list says KIND (gummy / crabby / hopper / gloomy / bomb / puffer) and
  `critter_type` picks the type from the ISLAND where its run lands (`ISLE_TYPES`; grass and sand: x ≤ 26 = meadow,
  else coast): meadow Gummy + River Crabby, coast the originals, fortress wind-up Gummy + steel Crabby (+ bombs),
  summits icy, caves Cave Gummy + Cave Crabby + Gloomies, volcano Magma Gummy + Lava Crabby (the volcano had none) —
  and a HOPPER of its skin on every island. `StoryMapState` `CRITTER`: the new types (river / lava claws like in game)
  and `hopper_<isla>` (`hop = true`: stands, crouches, jumps in an arc, ~1 hop per second; `left` = art faces left).
  Hoppers are only in huida_del_espejo and the dark caves (and the EnemyTest gallery).

## The secret node

The last world has a `secret` level in `Worlds.lua` (`isla_del_groove`: [Groove Crab](../bosses/groovecrab.md)). On the
map it is the LAST STOP: a branch from the Final's bonus node (`worlds[6].secret` in `overworld.json`, `SECRET` in
`make_overworld.py`) to a sand islet NE of the volcano. The islet is always there (a mystery); while the secret is
locked (`Run.secretState`: open once the last world's boss is beaten) it DOES NOT EXIST on the map: no node, no path
dots, not a stop (`totalStops` leaves it out), no arrow leads to it, it cannot be tapped. When the Mirror falls it
opens with the usual rings (the "what just opened" check counts every stop, `allStops`). Its node carries one of The
Groove's notes dancing above it; its card says "a secret stage". It does not count for progress. The islet is added
at the END of the generator (after decorations and critters), so nothing else on the map moved. Harness: `story_flow`
case `secreto`.

## Moving on the map

- (6) WORLD MAP ARROWS BY DIRECTION: `StoryMapState:_dirMove(dx, dy)` goes to the neighbouring stop whose path leaves toward the pressed direction (previous / next; from a castle also the next world over the bridge); no path that way → the old meaning (left / right = previous / next, up / down = previous / next world). `_walkTo` crosses castle ↔ next world by the bridge without detouring to the bonus node.

- (8) ENTER WAITS FOR THE HERO (3.101.0; the user: pressing enter while the monster was still walking entered the
  level at once): `_play` with the walk queue not empty only notes `playOnArrive`; the level opens when the hero
  ARRIVES; asking for another destination cancels it (`_walkTo`). Harness `story_flow` `andando`.

- (9) ENTERING A LEVEL (0.5.36; the user: "de golpe apareces en el nivel"): `_play` plays `levelEnter`
  (`tools/sounds/ui.py`) and goes through `_go`: `Transition.go(..., { style = 'level' })` — the iris closes on the
  monster (0.6 s), the screen fades to black (0.4 s) and the level (or its first-time film / the bonus) fades in from
  black (0.5 s), then the level's start countdown ([start-countdown](../gameplay/start-countdown.md)). Changes that
  don't start on the map (after a film, a race chaining into the next node) stay direct. Not judged by a person yet.

- (7) AFTER A LEVEL the hero stays on the node JUST CLEARED and the newly opened stops unlock on screen (`args.opened` → `self.opening`: locked for `OPEN_AT` 0.7 s, then a hop + rings + sound).

## History and decisions (dated notes)

Kept because they record WHY things are the way they are and what was tried and rejected. Where a note
conflicts with the sections above, the sections above describe the current behaviour.

- 2026-10-28: the JUNGLE island added as "coming soon" (south of the Coast–Fortress gap, map 84x48 →
  84x63, locked bridges, no stops) — the user asked for its island "after the coast", still without levels. Not
  judged by the user yet.
- 3.65.0: (1) WORLD MAP: the Mega Crabbies beside their castles now have their CLAWS (`BOSS_CLAWS` in StoryMapState: same
  sheets and placement as in game — megacrabby 0.7 scale, icy 1.0, gloomy sickles pointing inward — swaying, with a snap
  now and then) and the two spiked ones their head SPIKE behind the body; the Gummy King's crown was already drawn. The PUFFERFISH swim only in OPEN SEA: `loadMap` moves each
  one to the nearest run of sea cells with water above, below and beside (their hand-written coordinates crossed sand).
  `story_flow` also writes `story_map_bosses.png` (every boss shown: `state.showBosses`). (2) COAST = SAND: the user
  found jungla_colgante (2nd coast level) looked like a meadow level with water — theme 'tropical' = grass + palms. In
  `retheme.py` the coast levels are now 'beach' (jungla_colgante, canon_trampolines, cala_de_los_muelles; also
  cumbre_cangrejo), re-dressed with `--terrain --force` + `--decor --fix --theme`, jungla's background forest → coast;
  nav of the changed arenas rebuilt. Audit of every story level vs its island: also fixed isla_flotante (tropical
  decorations in the meadow → theme 'meadow') and lago_de_cristal (clams in the snow). Left as is on purpose:
  bosque_interruptores (forest look inside the Meadow), the underwater caves (corals in nivel01 / laberinto_submarino).
  Before/after: `FlappyMonster_pruebas/retema_costa/`. (3) VICTORY music was very quiet: the results screens used fixed
  volumes (0.6 / 0.4, tuned for the borrowed track) × 0.45 while counting; now they take the catalog volume (levels.py,
  victory target −14 LUFS effective) and duck to 60 %.
