# The world map

One big scrolling map in the style of Super Mario World: eight islands (the JUNGLE, world 3 since 0.5.99; the FROZEN COAST, world 6 since 0.5.100: [below](#the-frozen-coast-world-6-0-5-100);
[below](#the-jungle-island-world-3)), one path per world with a node per level, a castle for the boss, a blue "B"
bonus node, a CANNON at each end of every crossing between worlds ([below](#cannons-between-islands); they replaced the
bridges on 2026-10-29), wandering critters and the hero walking along the path. Everything about its shape is DATA in `assets/story/overworld.json`, written by a deterministic generator.

**Files:** `src/states/story/StoryMapState.lua` (drawing, walking, input, camera, the films' map set),
`tools/art/story/make_overworld.py` (writes `overworld.json` and the sprites in `assets/images/story/`),
`tools/art/ui/make_story_icons.py`. **Music:** `map_<world>`; the arrangement switches with the island nearest the
hero at the same position of the tune (`Sound.switchMusic`), with a CROSSFADE (0.5.95, the user: the hard switch was
noticeable): the old arrangement fades out while the new one fades in at the same position, `Sound.XFADE` 1.2 s,
equal-power curve (`sounds` harness: "fundido del mapa").

**Controls:** each arrow goes to the neighbouring stop that lies that way on the map; tap a node to walk there, tap
your own to play; ENTER plays. Rules (`dirMap` in `StoryMapState.lua`): neighbours of a stop = previous and next
along the path, plus the crossing to the next island from a castle (and back from an island's first level) — by cannon. (1) What
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

## Cannons between islands

The user (2026-10-29): "para cambiar de isla se usa un puente; estaba pensando en usar un cañón. El cañón se carga con
el jugador, apunta y dispara. Se vería mejor y quedaría más cómico." Decision: a cannon at EACH end of every crossing
(one goes forward, the other brings you back); the bridges are gone from the map (the sea between islands is empty).

- **Data:** `overworld.json` `cannons[w]` = the crossing from world `w`'s castle to world `w + 1`'s first node:
  `a` / `b` = the cannon at the castle end / at the arriving end, `la` / `lb` = where the hero lands when arriving at
  that end (one cell from the cannon toward the node). Cell coordinates like the paths. Written by
  `make_overworld.py` from the same crossings as before (`SCONNECT_OUT`, still in `connect` and still counted for the
  distance to paths, so nothing else on the map moved): each cannon goes on land next to the shore where the old
  bridge left the island, never on a path, a decoration, the castle or the boss beside it, with a land-only line to
  its node. Placement runs last and without randomness. A new island = one more crossing, nothing in code.
- **Route:** `M.bridge` is now `{ castle, first node }` whose arrival point carries `fly = crossing` ("this hop is a
  cannon flight"); `reversed()` moves the mark so the way back is a flight too. Everything that walks legs (arrows,
  `_walkTo`, the queue, ENTER-on-arrival, chaining presses) is unchanged: the walker stops at a `fly` point and
  `StoryMapCannons:_cannonTick` does the rest, starting from the cannon nearest to the hero. `legDir` points a
  crossing at its cannon (the little dotted path), so the arrow that leads to the next island is the one that points
  at the cannon.
- **The sequence** (`src/states/story/StoryMapCannons.lua`, a part of `StoryMapState`): walk to the cannon → hop into
  the mouth (0.32 s; `cannonLoad`, the cannon squashes) → aim (0.45 s; the barrel turns from 20° to the launch angle
  of the arc, in 10° frames) → fuse (0.6 s; spark, `cannonFuse`, the cannon trembles) → BOOM (`cannonBoom` +
  `cannonWhoosh`, muzzle flash, 4 smoke puffs, screen shake, recoil) → flight along a parabola (0.8-2.4 s by
  distance, height 80-360 px; the hero curled — `monstrito5` — spinning, a smoke trail, a shadow on the ground; the
  camera follows, including some of the height) → landing (0.4 s; `cannonLand`, dust both sides, squash and a bounce)
  → walk to the node. `heroX/heroY` follow the GROUND track during the flight, so the map music crossfades to the
  next island when the hero is nearest to it, mid-air.
- **Locked crossing** (the next island not open): both cannons darker and corked (barrel frame 11); the route never
  reaches them (the next stop is locked: the usual bump). When the island opens after its boss, the corks pop with a
  puff at `OPEN_AT`, with the other "just opened" animations.
- **Art:** `tools/art/story/make_cannon.py` → `assets/images/story/cannon/` — a CIRCUS cannon (the human cannonball
  kind): a long slim red barrel with a bell mouth and gold rings on a blue one-wheel carriage; few flat colours.
  Drawn ×3 like the hero. Sheet: `FlappyMonster_pruebas/canones/hoja.png`; frames of a real crossing:
  `FlappyMonster_pruebas/canones/` (from `story_flow`). Sounds: [sound](../audio/sound.md#the-world-maps-cannon).
- **Films** draw the map with the cannons (state as in the save; no flight).
- `soon` islands still draw locked bridges (none exists today).
- **Harness:** `story_flow` case `canon` (forward and back by arrow, every phase, lands on the right node, the music
  switches, a locked crossing does not fire; captures `story_cannon_*.png`). Feel, timing and sounds are not judged
  by the user yet.

In the older notes below, "bridge" between islands now means this crossing.

## The Frozen Coast (world 6, 0.5.100)

The ice island split in two (the user, 2026-10-29: "8 bosses and 7 islands"): the old one is now the FROZEN MOUNTAINS
(`nieve`, the Snowball Boss beside its castle — `BOSS_ART['nieve']`; `NODE_BOSS` is empty now, the support stays) and
the new FROZEN COAST (`costa_helada`, the Icy Mega Crabby) is a flat ICE island EAST of the Mountains: the map grew
eastwards (90x63 → 112x63, `W0` = 90 keeps the random loops of the older islands where they were). Terrain `i` (ice:
`ice` tile lip and cliff, `GROUND`/`CLIFF` in StoryMapState), low ice banks, snow piles / frozen bushes / snowmen,
icy crabs, a Gummy, a Hopper and two pufferfish. Built at the END of `make_overworld.py` with its own seed (`crng`):
path `CPATH` (castle at its north-west), bonus `CBONUS`, bridges `CBRIDGES`: Mountains' castle → its first level, its
castle → the Caves (along the north edge, over the sea, like the old Mountains → Caves bridge). The Mountains' bonus
branch now points north-west (their bonus is still to come). Map music: `map_costa_helada` = the old ice arrangement.

## The jungle island (world 3)

The island after the Coast (`jungla`, `src/world/level/Isles.lua`; boss the [Giant Rhino Beetle](../bosses/giantbeetle.md),
`templo_escarabajo`). Added on 2026-10-28 as "coming soon" (art only); since 0.5.99 it is **world 3 of `Worlds.LIST`**
with its levels and bonus ([story-mode](story-mode.md#worlds-and-saves): how old saves are migrated).

- **Where:** SOUTH of the gap between the Coast and the Fortress; the map grew downwards (84x48 → 84x63 cells, now
  90x63). It is generated at the END of `make_overworld.py` with its own seed (`jrng`), so it does not move anything
  of the other islands; their random loops run only to `H0` (50).
- **What:** terrain `j` (dark jungle grass: `jungle_grass` lip, `mud` cliff body, `jungle_blades` tufts) and `t`
  (temple stone plaza around the castle: `temple_brick`); a plateau inside the path's loop with the hand-placed
  ZIGGURAT; feature sprites drawn by the generator in the features' house style — `jungle_tree` (round canopy on
  a trunk), `ziggurat` (three stepped tiers, stairs, moss, dark door), `ruin` (broken mossy wall) — plus the game's
  jungle decorations (`jungle_fern`, `heliconia`, `banana_plant`, `elephant_ear`, `tree_fern`, `bromeliad`,
  `broken_pillar`, `stone_idol`, `stone_brazier`: `DECO` in `StoryMapState`); critters: jungle Gummy (tree frog),
  jungle Crabby, the blue Rhino Beetle (`beetle`, a `CRITTER`), the jungle Hopper, two pufferfish. The boss art is
  `giantbeetle/body-Sheet.png` (fw 22) beside its castle.
- **Data:** in `make_overworld.py` the jungle's path (`JPATH`), its bonus branch (`JBONUS`, east of the castle) and its
  boss art join `SPATHS` / `SBONUS` / `BOSS_ART` at the end, and the output lists the worlds in story order (`STORY`
  = `Worlds.LIST`). Bridges: Coast castle → down the canal between the Coast and its bonus strip → the jungle's first
  node; the jungle castle → up the channel west of the Fortress → the Fortress's first node (`JBRIDGES`, in place of
  the old Coast → Fortress bridge, which still counts for the path distances of the old islands so nothing there
  moved). `THEME.jungla` in `StoryMapState`; its map music `map_jungla` plays as for any island.
- **`soon` is kept, empty:** `overworld.json` `soon = [{ id, path, stops, boss, bridges, label }]` is still read
  (`MAP.soon`, `_drawSoon`: grey sample nodes, castle, "PRÓXIMAMENTE" label, locked bridges; NOT stops) for a future
  island shown before it has levels; the jungle no longer uses it.
- **Films:** `view` is now the whole map; the wide map shots of the films frame all the land (`K.far`,
  [cinematics](cinematics.md#data-driven-how-many-bosses-and-shards-there-are-is-never-written-in-a-film)).

## Island separation (`OFF`)

The user (2026-10-29): "separa la isla costera de la isla fortaleza porque si no parecen muy pegadas y queda algo
raro. Lo mismo con la isla pradera con la isla caverna y la isla caverna con la isla volcánica" — measured, the Coast
and the Fortress were one land mass and the Caves were 1.4 tiles from the Meadow and from the Volcano. In
`make_overworld.py` every island moves as a whole with `OFF[island] = (dx, dy)` (cells): its blobs (`iblob`), path
and bonus (`off`), relief groups (`RELIEF` is grouped by island name), cave pits and critters (`CRITTERS` grouped by
island); bridges stretch between the two islands' offsets (`stretch`). Today `pradera` (0, 2), `fortaleza` (5, 0),
`cuevas` (0, -1) with a narrower caves blob (rx 14 → 12.5, centre one cell left); map 84 → 90 cells wide. Gaps now:
Coast–Fortress 6.0, Caves–Meadow 5.7, Caves–Volcano 4.1 tiles. Decorations were re-rolled by the generator (same seed,
new land). Not yet judged by the user.

## How it is built and drawn

- `StorySlotState` (pick / create / delete with confirmation) and `StoryMapState` = the WORLD MAP (stage 5, Super Mario
  World style): ONE big scrolling map (112x63 cells of 32 px; eight islands) from DATA `assets/story/overworld.json`, written by
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
  `story_map_full.png` (3584x2016, every world open); copy it to `FlappyMonster_pruebas/mapa/mapa_completo.png`. Bonus nodes (KOTH vs bot) = stage 8.
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

## The secret nodes

`Worlds.lua` `secrets` ([story-mode](story-mode.md#the-secrets-secret-exits-splinters-the-groove-and-the-mashup)) puts
optional secret levels on the map: a RED node with a KEYHOLE (`assets/images/story/node_secret-Sheet.png`, 10x10 ×4:
open red, done gold) at the end of a short branch from its `from` node, with the icon of what it guards floating above
it (its collectible's icon; the Groove, which guards nothing, a dancing note). While locked it DOES NOT EXIST: no node,
no dots, not a stop (`totalStops` counts only visible stops; hidden stops keep their number, `allStops`), no arrow
leads to it, it cannot be tapped. When it opens (the stops that were locked before a level and are not after it:
`args.opened`) its DOTTED PATH DRAWS ITSELF from the `from` node (`SECRET_PATH_T`: from 0.35 s, in 1.1 s; each dot knows
its place along the path, `u`) and the node pops out at `SECRET_OPEN_AT` 1.5 s with the usual rings and sound.

- **Geometry** (`make_overworld.py`, `SECRETS`, at the END of the generator, no randomness): the `from` node is found as
  the game finds it (node k of n spread by arc length along the world's path: `(k, n)` = `Worlds.lua`, keep them in
  step; the game starts the branch at the real node anyway if they drift), a Catmull-Rom branch through its control
  points, sand / rock put under it where it crossed the sea, an islet blob where given, relief flattened next to it and
  the few decorations it touches removed — nothing else moves. Output `worlds[i].secrets = { [level] = points }`.
  Today: the Mega Crabby's lair on a sand spit north of Arrecife Globo; the Mega Gloomy's grotto west of Templo del Eco
  on the flat; the Groove's islet NE of the volcano (its path, which crossed water as a bridge, now runs on a sand spit);
  the Mega Mashup a little east on the same islet (slightly enlarged).
- **The map is a TREE** (rewritten 2026-10-29 for the secrets, which hang mid-sequence): every stop hangs from another
  by one leg — a level from the previous one (`seg`), the bonus from the castle (`branch`), a secret from its `from`
  (`secret`), a world's first level from the previous castle (`bridge` = the crossing, the cannon flight of
  `StoryMapCannons.lua`). `parentOf(i)`, `edgeOf(a, b)` → `{ pts, kind }` (points passed through untouched: the cannon's
  `fly` marks survive; backwards with `reversed()`), `route(a, b)` = the unique path. `_walkTo` walks that path stop by
  stop and stops in front of a locked (or hidden) one; `neighbours` (the arrows) = the visible tree neighbours. Same
  behaviour as before on the main chain; from a bonus the next island is no longer a direct neighbour (walk back to the
  castle). The bottom arrows / `_move` step to the previous / next VISIBLE stop in stop order.
- **The map SCENES** (`StoryMapScenes.lua`; text-free; seen once — `films[id]` —; ENTER / back skips, its effect still
  applies; they start when nothing is opening and the hero is still, with cinema bars over the HUD, and the camera goes
  to the scene and back): `groove` — the Groove on its islet, its disco ball pulls the splinters out of the crown and
  the amulet (they rise from the monster; orbs fly to the ball), the ball is whole (flash, rays), its beams hit the
  monster, whose flap sputters (three ever-smaller hops with fizzling sparks), the Groove dances → splinters become
  `'stolen'` and the Groove's node opens. `regrow` — after beating the Groove: beams from the ball make the small Mega
  Crabby, Icy Mega Crabby and Mega Gloomy grow back (normal sprite → giant) → the Mashup's node opens. `disco` — after
  the Mashup: the ball shakes and shatters, the splinters fly back (states `true` again), the crabs and the Groove
  shrink and dance with notes, the monster flaps free above them, and the Disco Ball trophy fills the screen. Not
  watched by a person yet.
- Harness `story_flow`: `salida_secreta` (hidden → secret exit → the path draws itself, `story_map_secret_path.png`,
  `story_map_secret_open.png`), `secreto` (Groove gate + the theft scene, `story_scene_groove.png`), `mashup`
  (`story_scene_regrow.png`, `story_scene_disco.png`).

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

- 2026-10-29: CANNONS replace the bridges between islands, one at each end of every crossing (the user:
  "para cambiar de isla se usa un puente; estaba pensando en usar un cañón. El cañón se carga con el jugador, apunta y
  dispara. Se vería mejor y quedaría más cómico") — [above](#cannons-between-islands). Not judged by the user yet.
- 0.5.113 (2026-10-30): the user — in the "crabs grow back" and "ball breaks" scenes the small crabs looked bigger than
  the giants and "growing" shrank them; the small Icy Crabby lacked its claws; the Groove kept its trampoline and big claw
  when small; the islet was too tight. Now the scenes use the map's sizes (giant 1, normal enemy 0.62, `SMALL`/`MID` in
  StoryMapScenes; the ending film too), the small Groove has no trampoline and two small claws, and the Groove's islet
  grew westwards with the Mashup node at its west end. story_flow captures every stage (`scene_regrow_pequenos`,
  `scene_disco_grandes`).
- 0.5.100 (2026-10-29): the ice island split in two — the Frozen Coast (world 6) added east of the Mountains; map
  112x63 (the user: "son 8 bosses y 7 islas… separamos la isla congelada en 2").
- 0.5.99 (2026-10-29): the jungle became world 3 (its four levels, boss and bonus; bridges Coast → Jungle → Fortress);
  the islands were moved apart on the user's request (`OFF`, above); map 90x63.
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
