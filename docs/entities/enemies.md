# Enemies

The regular enemies. Every island has its own Gummy and its own Crabby (same class, other art, sometimes other
shape); dark levels have the Gloomy Crabby; plus the Hopper, bombs, the pufferfish and the mortar. Types, files and
props: [reference/entities](../reference/entities.md). Base behaviour: [overview](overview.md).

| Island | Gummy | Crabby (spike / trampoline) | Hopper skin |
|---|---|---|---|
| Meadow | `gummy` | `crabby_river` / `crabbytramp_river` | pradera |
| Coast | `gummy` | `crabby` / `crabbytramp` (the originals) | costa |
| Fortress | `gummy_fortress` (wind-up toy) | `crabby_fortress` / `crabbytramp_fortress` (steel) | fortaleza |
| Summits | `gummy_ice` | `crabby_ice` (4 covers: ice spike, icicle, snow mound, trampoline) | nieve |
| Caves | `gummy_cave` | `crabby_cave` / `crabbytramp_cave`; dark levels: `gloomy` | cueva |
| Volcano | `gummy_magma` | `crabby_lava` / `crabbytramp_lava` | volcan |

`tools/levelgen/retheme.py --enemies <levels>` swaps enemy types by the level's island (`ISLAND_ENEMIES`).
`assets/levels/EnemyTest.json` is the user's gallery of all of them (a harmless test level).

**Art:** `assets/images/enemies/<enemy>/`; generators in `tools/art/enemies/`. Several sprites are HAND-EDITED by the
user and must never be regenerated: see [art/generators](../art/generators.md).

**User's rules for every variant:** legs 1 px wide with only the foot wider; symmetric faces (body an odd number of
pixels wide); no Crabby has a mouth; claws use the game's claw drawing and point inward; a "Mega" keeps the small
sprite's pixel grid.

## Gummy: helmet and the icy Gummy

- **Gummy helmet** (prop `helmet`, Gummies only; `assets/images/enemies/gummy/casco.png`
  drawn over the sprite on the same 16x16 grid, scaled `HELMET_K` 1.10 around its
  bottom edge; the outer box grows up by what the helmet sticks out). `Gummy:interact`
  has NO ambiguous case: player feet in the upper half (outer box overlap, feet ≤
  centre) → ground pound = `'stomp'` (dies, `onStomp` breaks the helmet: sound
  helmetBreak + fx helmet_break), falling/still = `'helmet'` (run: `pa:bounce` +
  `e:onHelmetBounce()`: sound helmetBounce + render-only bonk `bonkT`, helmet intact,
  no points), rising = nothing; from the side/below = normal Gummy rules (it hurts),
  and a normal stomp there is also turned into `'helmet'`. The GP landing
  `poundZone` kills it too. Client predicts `'helmet'` as a bounce (+ sound). Net:
  Gummy netPack {helmet, bonkT}. Harnesses `mechanics` (66 drops) + `online_helmet`.

- **Icy Gummy** (`types/enemies/gummy_ice.lua`, "Gummy helado"): the Gummy class with its own art folder (`artDir`;
  `Gummy.loadArt(dir)` / `Gummy:art()` = idle, walk1/2, dead per folder) — `assets/images/enemies/gummy_ice/` from
  `tools/art/enemies/make_gummy_variants.py --apply-helado` (user's pick: option A "Escarcha" WITHOUT the icicles = the
  exact Gummy shape in ice + snow on its head). Same behaviour (walk/fly, helmet...). Used in the icy levels
  (lago_helado, torre_viento, glaciar_cangrejo; retheme `ICY_CRABS` also maps gummy → gummy_ice). Harness
  `icecrabby_rules gummy_helado`. MEGA GUMMY = the boss **Rey Gummy** (see Boss system; the user rejected a new
  20x20 body — like the Icy Mega Crabby, a Mega must keep the SMALL sprite's resolution: the 16x16 Gummy drawn
  at scale 10, 1-px edits only). Gummies can be RESERVE minions (`Gummy:makeReserve/netAtRest/netRest`, like
  Crabby): the Rey Gummy's royal guard.

## Crabby: hiding, spike, ceiling drops, wall walking

- Crabby spike hazard = tile-spike proportions (base rectangle, 60% × 40% of the
  visible spike: `spikeDims` in crabby.lua), like `Level._spikeHitbox`.

- Crabby hooks: `drawTopper(cx, baseY, progress, dir)` (spike by default) and
  `bounceRotation()`; `Interactions.defaultCheck(pa, e)` = the normal rules, for
  entities whose `interact` only overrides some cases.

- Ceiling Crabbies detect players while hidden (`canDropNow`/`isHiding`) and drop
  straight from the shell (`dropHidden`). STUCK UPSIDE DOWN (`drop_stuck`: spike in the floor, body above it): `self.y`
  is where the SPIKE is, so everything about the body uses `stuckHeadY` (spike base + `topperDy` art px: the ice spike /
  icicle sit 2 px into the shell there too — it left a 2-px gap) and `stuckCenterY`: `getOuterBounds/getInnerBounds`
  (the stomp box used to sit on the spike, under the visible body), and the drawing, which places each frame by its
  VISIBLE rows (`sk.inset`: the icy sink frames have empty top rows, so flipped they appeared at the top, detached,
  and grew DOWN towards the spike; now the body grows up out of the spike and stays attached; no claws on partial
  frames). Stomped while stuck (`Crabby:stomp`): `flipped = true` and `y` on the floor, so the crushed sprite lies
  upside down where the spike was (both travel in snapshots). Harness `icecrabby_rules clavado` (+ `LOOK=1` →
  icecrabby_techo.png: ceiling hide/unhide and the stuck sequence with its box). A wall-walking one RELEASES the crawl when
  it starts falling (`releaseCrawl` at drop_fall; otherwise the stomp rules kept
  seeing a ceiling normal and a stuck Crabby killed whoever jumped on it) and, once
  back on the ceiling, clears `dropped` → it drops again (a plain ceiling Crabby
  stays a floor Crabby). Trampoline crush: `pa:squash` + hurt + invulnerability for
  `PlayerAdventure.SQUASH_T` + 1 s, and it lands walking AWAY (`crushDir`).

- Wall Crabby stomp (Interactions.defaultCheck): in the air, falling onto its top
  end OR coming from the open side (player centre beyond its outer face) =
  'stomp' with 4th return dirX = cnx → `pa:bounce(vy, dirX, soft=true)` (vx 300 +
  ctrlLockT, no stun); predicted via `recordBounce(vy, dir, soft)`. Protocol v15 (v16: King of the Hill; v17: crawler turn in snapshots; v18: MegaCrabby;
  v19: boss walls, Mega minions/pounce; v20: post-hit protection; v21: unified invulnerability;
  v23: boss intro + Mega emotes; v24: subtiles, dirt/grass; v25: connected floods; v26: generic links `to`; v27: ON/OFF blocks; v28: generic boss intros; v29: Mirror arena attacks; v30: boss broken glass; v31: special enemy deaths; v32: bombs; v33: snow/ice/thin ice; v34: sand; v35: deep stone; v36: freezer; v37: Snowball Boss; v38: Snowball Boss rebuilt, zone phases, phase blocks; v39: Icy Crabby; v40: Icy Mega Crabby; v41: Rey Gummy + reserve Gummies; v42: icicle field, guard entries/parachute, free flight; v43: dark levels, flashlight, Gloomy Crabby).

## Crabby skins and the Icy Crabby

- **Crabby skins + Icy Crabby** (`types/enemies/crabby_ice.lua`, one palette card "Crabby helado" with selector
  "Se esconde bajo" = 4 defs: `crabby_ice` ice spike, `crabby_ice_icicle`, `crabby_ice_snow`, `crabbytramp_ice`).
  Crabby images live in a SKIN (`Crabby.SKINS.normal|ice`, `self.sk`, class field `skinId`; network image
  names are prefixed per skin). The ice skin (`assets/images/enemies/crabby_ice/` from `tools/art/enemies/make_icecrabby_sprites.py`
  = the Icy Mega Crabby body at Crabby scale) SINKS row by row when hiding (`sink1..8.png`, same total time).
  The sink frames keep the 18x8 canvas with EMPTY top rows (`sk.inset[img]` = rows; hid = 1), so every cover
  (drawing, hazard box, trampoline box) sits on the VISIBLE shell top via `Crabby:headH(img)` (minus `topperDy`
  art px: the ice spike and icicle sit 2 px into the shell, like the Mega's spike); before, the cover floated up to
  32 px above the sinking shell. Harness `icecrabby_rules tapa_pegada` (measures the opaque top in the PNGs;
  `LOOK=1` → icecrabby_esconderse.png).
  SMALL CLAWS (user's pick "A: Mini Mega" of 3, `tools/art/enemies/make_icecrabby_claws.py --apply A`): `crabby_ice/claw_left-Sheet.png`
  2 frames 7x7 (open / closed; right = mirror), skin field `claw` {file, w, x, y, inset} (art px like the Mega);
  render-only `Crabby:drawClaws` after the body, animated like the Mega's (continuous offsets in art px placed to the
  SCREEN pixel = quarter-art-pixel steps; integer art-pixel steps looked choppy, and clipping every frame against the
  feet line cut the bottom row whenever a claw dipped — now only sinking frames are clipped): walking = each claw sways
  on its own phase + random snaps, `idle` = eased raise with a double snap, hiding / out / drops = closed and SINKING with the shell row by row (`inset + 1`; rows under the surface are
  cut with a quad viewport), hidden / peeking / dead = none; mirrored on the ceiling. Harness `icecrabby_rules pinzas`.
  Covers (on floor, walls and ceiling): ice spike = the normal spike (kills); icicle = the Snowball Boss icicle,
  always an icicle, hazard `effect='hurt', dmg=2` + `onHurtPlayer` recoil (Interactions 'hurt' now takes the
  damage from `hb.dmg`), drops from the ceiling like the spike (2 HP) and sticks; trampoline = the Crabby
  trampolín (`TC:trampImages` overridden); SNOW = a mound in the `snow_pile` decoration style, drawn IN FRONT
  (`coverFront`: grows from the surface while the crab sinks behind; `noPeek`): harmless while hidden;
  touching it → 'snow_crack' (0.25 s, no damage) → 'snow_burst' (whoever still overlaps: 1 HP + recoil);
  landing on it = 'bounce' (thrown up, no damage, bursts under you); GP on it = stomp kill; from the ceiling
  it falls as a snow lump (1 HP + 0.8 s stun) and bursts on the floor. Every Crabby (normal and icy) throws
  small physical debris of the block under it while hiding/unhiding (render-only `Crabby:renderDig` →
  particle `crab_dig`, colours from the surface, along its normal). Harness `icecrabby_rules` (+`LOOK=1`),
  online `online_smoke LEVEL=tools/levelgen/arenas/crabby_helado.json WATCH=crabby_ice_snow`. Protocol v39.

## Island variants (Gummies and Crabbies)

- IMPLEMENTED (the user kept the FIRST-round design A for these two, i.e. the original sprite recoloured + a detail; `tools/ui/make_variant_skins.py --apply`): **Gummy de magma** (`gummy_magma`, the Gummy class with `assets/images/enemies/gummy_magma/`: dark rock, glowing cracks, eyes and mouth) and **Crabby de la fortaleza** (`crabby_fortress` + `crabbytramp_fortress`, Crabby skin `fortress` = `assets/images/enemies/crabby_fortress/`: steel with rivets). Placed by `retheme.py --enemies [levels]` (ONLY swaps enemy types by the level's theme: `ISLAND_ENEMIES` — snow → icy, volcano → gummy_magma, fortress → crabby_fortress; 39 enemies in 11 levels; bot nav rebuilt). The Magma Gummy is dark on dark in the night volcano levels (no glow yet).

- 3.76.0 (user's picks from the third round; protocol v50): IMPLEMENTED as real enemies, new SHAPES with the Gummy
  class (`tools/ui/make_variant_skins.py --apply`, maps in `tools/art/enemies/make_enemy_designs.py`): **Gummy de cueva** (`gummy_cave`,
  version C: low and wide, wide-set eyes, one crystal; `helmetDy = 5` — generic Gummy field: its head sits 5 art px
  lower, so the helmet and its box go down with it) and **Gummy de la fortaleza** (`gummy_fortress`, version A: square
  steel wind-up toy, Gummy feet; the brass KEY turns with the walk: idle = medium, walk1 = tall, walk2 = thin).
  Placed by `retheme.py --enemies` (`ISLAND_ENEMIES` cave → gummy_cave, fortress also gummy → gummy_fortress;
  `ENEMY_ISLAND` = levels whose island differs from their terrain theme: cantera_dinamita → fortress, mina_inundada →
  cave; 57 enemies in 11 levels; bot nav rebuilt).
  STILL OPEN — fourth round, the two Crabbies, `FlappyMonster_pruebas/enemigos/variantes_v4.png` (`sheet_v4`). USER'S
  RULES: NO Crabby has a MOUTH (eyes only); claws must use the GAME'S claw drawing (the Icy Crabby's 7x7 sheet / the
  Mega's 10x7, open + closed, at the sides pointing inward) — the tiny blob claws of rounds 2-3 were rejected.
  River Crabby = body C (slim mossy shell) + Icy-Crabby-like legs with HAIRS; claws 1 the game's small claw / 2 furry
  "mitten" claws / 3 the Mega's big claw. Lava Crabby = wide basalt shell, claws A small / B big / C small with a
  red-hot edge; faces 1 ember eyes + loose cracks / 2 slit eyes with rock brows / 3 dark Crabby eyes + red-hot plates.

- 3.77.0 (the last two variants, user's final picks; protocol v51): **Crabby de río** (`crabby_river` +
  `crabbytramp_river`, meadow / forest levels) and **Crabby de lava** (`crabby_lava` + `crabbytramp_lava`, volcano).
  Crabby SKINS `river` / `lava` with their own SHAPE (`tools/art/enemies/make_crab_species.py --apply` → `assets/images/
  crabby_river|crabby_lava/`: crab1-3, sink1..N — they SINK row by row like the icy one, `addSkin(..., { sink = n })` —,
  hid, lookin, meat, dead, spike, claw_left-Sheet). River: 18x9 (NOT taller than the Crabby: user's rule), narrow
  mossy shell, long legs with ONE green pixel column hugging them (like the Icy Crabby's orange; the loose "hairs" were
  removed), no mouth. Lava: 18x9, wide low basalt shell, "face 1" (ember eyes + loose cracks, no mouth). CLAWS: the
  same drawing language as the other Crabbies' (long hooked top finger, gap, short lower finger) but 5x5 — the Icy
  Crabby's 7x7 reached from head to floor on these low bodies —, lava's with a red-hot edge; placed beside the shell
  (`Crabby.SKINS.river.claw` x 4.4 / `lava` 5.4, y −1.6, inset 0.5) and animated by the shared `Crabby:drawClaws`.
  Types come from ONE helper, `src/world/entities/base/CrabVariant.lua` (`defs(skin, label, name, trampName, desc)` = the
  spike and trampoline defs as one editor card). `retheme.py --enemies`: meadow / forest → river, volcano → lava
  (54 enemies in 11 levels; nav rebuilt). Test arena `tools/levelgen/arenas/crabbies_nuevos.json`. With this EVERY
  island has its own Gummy and Crabby (coast = the originals). Not done: special covers (flower tuft / lava vent)
  — they hide under the normal spike.
  3.77.1 (user): the Lava Crabby's shell had a BULGE on one side (three rows were 13 px wide in an 18-px canvas) —
  fixed, and `tools/art/enemies/make_crab_species.py` now ASSERTS that shell, standing legs and dead frame have a symmetric silhouette.
  River Crabby legs: the moss is no longer one flat green column down to the foot — three greens (M light, m, n dark),
  only on the UPPER part of each leg, the bottom 2 pixel rows clean (it must not reach the ground).

- **Crabby de cueva** IMPLEMENTED (3.78.0, protocol v52; the user picked version A "Geoda" — "perfect"): `crabby_cave` +
  `crabbytramp_cave`, Crabby skin `cave` (`assets/images/enemies/crabby_cave/` from `tools/art/enemies/make_crab_species.py`; 18x9, lilac round
  shell with a crystal cluster, NO claws at all, sinks to hide, `topperDy = 2` so the spike / trampoline sit on the
  shell between the crystals — `CrabVariant.defs(..., tuning, fields)`). `retheme.py --enemies`: cave → crabby_cave (22
  in cavernas_cristal, nivel01, mina_inundada). Dark levels keep the Gloomy only. EVERY island now has its own Gummy
  and Crabby: meadow (Gummy / River Crabby), coast (the originals), fortress (wind-up Gummy / steel Crabby), snow (icy),
  caves (cave Gummy / cave Crabby), volcano (magma Gummy / lava Crabby).

## Hopper (Saltarín)

- **HOPPER / Saltarín (3.74.0; `types/enemies/hopper.lua`, protocol v48 = new entity type)**: the user's pick, design B
  "Muelle" (a ball with a face on a spring). It never walks: 'idle' (rests `jumpEvery` s, faces the nearest player in
  `range` tiles × difficulty `sense`) → 'crouch' (`WINDUP` 0.35 s = the telegraph, hopWind) → 'hop' (ballistic toward
  the player: `jumpH` tiles high — higher if the player is above, cap `MAX_H` —, at most `jumpDist` tiles; hopJump) →
  lands (hopLand) → idle. Nobody in range = small hops in place. `careful` (default): it shortens the jump to where
  there is floor under BOTH its edges (`groundAt`; above the level everything reads solid → the probe starts at y 8).
  It stays inside its editor ROUTE (`patrol`; every entity gets a default one a few tiles around its cell — the test
  needed a wide one). Player rules = the defaults (`onTouch = 'hurt'`, stompable on the ground or in the air, 15
  points); lands on spikes / lava → `dieBurst`. Everything drawn comes from state + deadTimer. SKINS per island: prop
  `skin` 'auto' (by `level.background`; snowy level → nieve) | pradera | costa | fortaleza | nieve | cueva | volcan —
  `assets/images/enemies/hopper/<isla>-Sheet.png` (4 frames 16x21: idle, crouch, air, flat) from
  `tools/art/enemies/make_hopper_sprites.py --apply`, which builds them from the pixel maps in `tools/art/enemies/make_enemy_designs.py` (HOP,
  ISLES, HEAD: same shape, own palette, spots and head feature per island). Sounds `enemies/hopper/` from
  `tools/sounds/hopper.py`. Test arena `tools/levelgen/arenas/saltarines.json` (one per skin); harness `mechanics
  saltarin`, `online_smoke LEVEL=<that arena> WATCH=hopper`. NOT placed in any real level yet (waiting for the user).
  Not done: glow of the cave lure / volcano eyes in dark levels (`renderGlow`).

- HOPPER: (a) with nobody near it ROAMS — random hops (lower, shorter, quieter) inside its route; no route (`patrol = false`) = anywhere (`careful` still keeps it out of pits); default `movement = 'walk'` ONLY so the editor shows the route (it never walks). (b) its art faces LEFT (the face sits 1 px to that side), so it is drawn mirrored when facing right — it used to turn its back on the player.

## Gloomy Crabby (dark levels)

- **Gloomy Crabby** (`types/enemies/gloomy.lua`, "Crabby lúgubre", Cancrocaeca xenomorpha; art `assets/images/enemies/gloomy/`
  = the user's pick, option B "Fantasma", 9 frames 26x15 at scale 4 + `glow-Sheet.png`, from
  `tools/art/enemies/make_gloomy_sprites.py --apply`: body hand-drawn, LEGS traced by code hip–knee–foot so every pose comes
  from the same legs; sounds `tools/sounds/gloomy.py`). ALMOST SILENT (the user found it noisy: silence is the
  level's tension): only a dry accelerating rattle before the leap (the first hiss "didn't fit the character") and the
  leap sound; what happens to it is an ICON floating over it (`gloomy/icons-Sheet.png`, 3 frames 7x9, thin, above it:
  the user PREFERRED these over a bigger/bolder version — reverted): "!" heard something, "?" searching, "…" lost the
  trail; `icon` in netPack. A different archetype: no route, never hides, never kills on touch (`onTouch = 'hurt'`),
  always a Crawler; in the dark only its two glow points show. NAVIGATION = PLAN, don't steer: `Gloomy:plan` simulates
  its own crawl (`Crawler.move` on a copy) in BOTH directions along the surface, up to `PLAN_MAX` or a full loop, keeps
  the one that passes nearest the goal and walks THAT whole path (`planLeft`) without changing its mind (re-steering
  every moment made it go back and forth and shake at corners and platforms: turning a corner flips which way is
  "closer"). At the closest point, or earlier if walking is a real detour (≥ 3 tiles and > 1.6× the straight line),
  it LEAPS to the goal when it is within `LEAP_MAX` 5 tiles with a clear line (ceiling → floor, wall → shelf); else it
  searches. States: 'walk' (wanders, random reversals, 'idle') → HEARS a noise → 'hunt' (to WHERE IT SOUNDED) →
  'search' (`searchTime` s around the spot: re-plans back when it strays > 2.5 tiles) → "…" → walk. SENSES a player
  within `senseRange` 2.6 tiles if moving (half if still) → 'crouch' (`leapWind` 0.45 s: glow blinks + rattle) →
  'leap' (ballistic; contact = 1 HP + recoil via `onHurtPlayer`; grabs whatever it touches, never sticks) → 'rest'.
  'taunt' (1.1 s push-ups, crouch ↔ idle frames, eyes blinking) after hurting a player, by leap or by touch. LIT by a
  flashlight → 'flee' (plans away from the light every `FLEE_PLAN` 0.6 s, ×2 speed; calms `calmTime` s after dark).
  NEEDS A GROUND POUND: class flag `needsPound` (generic, `Interactions.check`: a normal 'stomp' on such an entity
  becomes 'bounce'; the GP and its landing zone still kill; and contact from ABOVE such an entity never hurts — only
  from the side, or when `e:hurtsFromAbove()` says so = its own leap; after the bounce the player was still inside its
  box going up and took damage). Dies flung when the block it GRIPS breaks (floor, wall
  or ceiling: `Entity:standingOnCell` now handles crawlers, which have no `onGround`). Doesn't walk through other
  enemies: `Crawler.entityAhead(e, level)` (generic, shared with Crabby) → turns round and drops its plan.
  Net: {surface, turn, modeT, icon}. Can be a RESERVE minion (`makeReserve`). Test
  arena `tools/levelgen/arenas/cueva_oscura.json`. Harness `gloomy_rules` (cases `navega`, `marca`, `burla`...).

- (9) GLOOMY PATHFINDING (`src/world/entities/base/GloomyNav.lua`, sim only): A* over what it can really do — CRAWL 48 px along its surface (the real `Crawler.move` on a copy), LEAP to a perch (floor / wall / ceiling of a nearby cell, ≤ 5 tiles, clear line + arc) and LET GO (drop from a ceiling / wall to the floor below) — bounded to 600 expansions, weighted (`GREED`); returns steps the 'hunt' state follows (`Gloomy:findPath/followPath/repath`): waits when another enemy blocks it (then searches there), re-plans (≤ 4) when it ends off the path, keeps its path for a new noise at the same spot. No path → the old one-surface plan. ~5 ms per search in templo_del_eco. Harness `gloomy_rules parkour` (floating platform, platform stairs, ceiling → island, three at once, cost).

## Pufferfish

- **Pufferfish** (`types/enemies/pufferfish.lua`, sheet `assets/images/enemies/pufferfish/
  puffer_fish-Sheet.png`, 16x16 frames facing RIGHT: swim 1-2, half 3, full 4; scale 5):
  water-only enemy on a plane IN FRONT (moves through everything, `renderFront` = drawn
  after the players in SP and online). It explores its SWIM AREA: prop `area` (kind
  `points`, 3-24 cell centres = any polygon, concave OK; editor shows it filled via
  `love.math.triangulate`): picks random targets reachable in a straight line INSIDE the
  polygon (`segInside`), usually the farthest of 8 candidates (so it reaches the ends of
  every arm), sometimes rests; `px/py` = position without the bob. Swim frames swap at
  `SWIM_FPS` 2.5 (animation only; the swim speed is `speed`). States walk(swim) → warn (a player IN WATER within `range` tiles;
  pufferWarn) → inflated (hazard box = body ×0.85, `effect='hurt'`; pufferInflate + fx
  puffer_pop) → deflate (pufferDeflate) → `cooldown`. Not killable (not stompable, not
  an obstacle, can't be knocked/launched). Prick: `Interactions.run` calls
  `e:onHurtPlayer(pa)` only if the hurt really took HP → pufferPrick + `pa:recoil`.
  Placed in `mina_inundada` (3, one crossing walls). Sheet restyled by
  `tools/art/enemies/make_puffer_redesign.py --apply` (a separate spike ring was tried and dropped).

## Bombs (living bomb and bomb object) and explosions

- **Bombs** (`types/enemies/bomb.lua` living bomb, Enemigos; `types/items/bombobject.lua` Bomba objeto,
  Objetos; shared `entities/base/BombCore.lua`; effects `src/world/systems/Explosions.lua`). Sprites
  `assets/images/enemies/bomb/`: the BODIES are **the user's, hand-drawn** (2026-10-08, over Claude's redesign of the
  same day — dark round body, metal collar, white eyes, boots; do not regenerate): `bomb-Sheet.png` (6 bombs: idle,
  blink, walk 1-2, about-to-explode 1-2; 135x18, NOT on a fixed grid — the swollen ones are 13 px wide) and
  `bombObject-Sheet.png` (4: idle, blink, about-to-explode 1-2; the last two touch each other). The **rope is no
  longer inside the body**: `tools/art/enemies/make_bomb_fuses.py --apply` measures each bomb in those sheets (its
  13x16 crop and where its collar is) and writes `bomb-rope-Sheet.png` / `bombObject-rope-Sheet.png` (the unlit
  rope for each body frame), `bomb-fuse-Sheet.png` / `bombObject-fuse-Sheet.png` (the burning rope, shorter, with a
  4-frame spark, for each frame that can burn) and the animations of the set `enemies/bomb`: body `idle` / `walk`
  (walk 1, idle, walk 2, idle) / `lit`, `rope_<body>` (same steps as the body) and `fuse_<body>_<step>`. `BombCore`
  draws the body, then the rope of that same step, or the burning one when lit; sparks come from the fuse frame's
  `tip`. The bombs stand on the bottom of their hit box (their art reaches the last row of the frame). **Run the
  script again whenever the body sheets change.** `explosion-Sheet.png` (10 frames 48x48) is from
  `make_bomb_redesign.py`. Earlier sheets are in `FlappyMonster_originals/…/bomb/`. Not yet judged by the user. Sounds bomb_ignite/fizz/blast/kick
  (`tools/sounds/bomb.py`; the blast is in the harness `LOUD` list, up to −4 dBFS, RANGE 4; the kick is metallic). Living bomb
  walks/flies like a Gummy (no helmet, breathes when idle), NO contact damage and NEVER lit by
  proximity: touching it KICKS it in the player's walking direction (`touchKick`, cooldown
  `KICK_CD`); stomping it = the player bounces (`'bounce'` + `e:onBounced(pa)` hook in
  Interactions) and it is kicked; a GP shove (`knockback`) kicks too. A kick (`Core.kick`)
  leaves the route and lights the fuse. States
  'lit' (physics, flashes frame 4↔1 faster and faster = `Core.litFrame`, turns red, fuse
  overlay + `fuse_spark` particles, bombFizz every 0.5 s) → 'exploding' (`Explosions.blast`,
  explosion sprite scaled to the hurt radius, fx `bomb_blast` + shake) → dead/gone. Bomb object:
  physics only (falls, bounces off walls, trampolines), lights on contact, harmless when still;
  FALLING (vy > 260) or THROWN (`throw(vx, vy, lit, fuse)`, for a future boss) → `'hurt'` 1 HP +
  `onHurtPlayer` stun; a kick never hurts the kicker. Launched onto spikes = it lights (short).
  **Explosions.blast(level, x, y, {kill, hurt, push} tiles, source)** — authoritative (SP +
  server): players (distance to their box) kill → `die()`, hurt → 1 HP + push, push → push
  only (`launch`, weaker farther; invulnerability protects); enemies ('Enemigos') hurt →
  `dieFling`, push → `knockback`; other bombs → `onBlast` (kick + short fuse = chain);
  breakable blocks within the hurt radius break, ON/OFF Activators toggle. Clients get all of
  it from snapshots/tile+fx+sound events. Editor overlay: the 3 radii (+ trigger range).
  Harnesses `mechanics` (bomba_*), `online_smoke WATCH=bomb` (arena `bombas.json`).

## History and decisions (dated notes)

Kept because they record WHY things are the way they are and what was tried and rejected. Where a note
conflicts with the sections above, the sections above describe the current behaviour.

- STILL OPEN — third round of mockups, `FlappyMonster_pruebas/enemigos/variantes_v3.png` (maps `V3_*`): Cave Gummy A pear / B gem with crystal ears / C low and wide; Fortress Gummy (square wind-up toy, approved concept) with feet A Gummy / B boots / C pistons and the brass KEY turning with the walk (tall → medium → thin); River Crabby A stocky / B claws up / C slim; Lava Crabby with claws 1 sides-inward / 2 raised / 3 maces / 4 tongs. USER'S RULES for all variants: legs 1 px wide with only the foot wider (like the Gummy), SYMMETRIC faces (body an odd number of pixels wide, eyes mirrored), claws that read as claws and point inward.

- CAVE CRABBY (proposal, WAITING for the user's pick; `FlappyMonster_pruebas/enemigos/crabby_cueva.png`, maps `V5` /
  `sheet_v5` in `tools/art/enemies/make_enemy_designs.py`): for the REGULAR cave levels (cavernas_cristal, nivel01, mina_inundada still
  use the white Crabby; the Gloomy is only for the dark-level mechanic). USER'S RULE for this one: NO separate claws
  like the icy / lava / river ones — none, or drawn INTO the sprite like the Gloomy's. Lilac + crystals (the Cave
  Gummy's family). A geode shell with a crystal cluster, no claws · B two crystals held up as its "claws" · C wide and
  flat, three-crystal crest, glowing eyes, no claws · D small pincers that are part of the body + one crystal.

- SECOND ROUND of variants (3.74.0, WAITING for approval; `FlappyMonster_pruebas/enemigos/variantes_v2.png`, maps `V2`
  in `tools/art/enemies/make_enemy_designs.py`): the user's picks, redrawn as DIFFERENT SPECIES ("like the Icy Crabby vs the Crabby: other
  body shape, proportions, silhouette — not a recolour"): Cave Gummy = lilac PEAR with cut crystals; Magma Gummy =
  little VOLCANO with a lit crater (flat top: still stompable-looking); Fortress Gummy = square steel WIND-UP toy with
  a brass key; River Crabby = tall mossy river-stone shell with small claws (olive-brown, A × C); Lava Crabby = wide
  basalt rock crab with raised claws and glowing cracks; Fortress Crabby = riveted TURRET dome with a grille and
  piston legs. Only one idle frame each so far; walk / hide / dead frames come after approval.

- ENEMY DESIGN PROPOSALS (3.73.0, WAITING for the user's picks — nothing is in the game yet):
  `tools/art/enemies/make_enemy_designs.py` → `FlappyMonster_pruebas/enemigos/*.png`: 3 options each for Cave Gummy, Magma
  Gummy, River Crabby (meadow, freshwater), Lava Crabby, the Fortress pair (steel / rust / guard with red plume), all
  = the exact base sprite with another palette + a 1-3 px detail; and the HOPPER ("Saltarín", the next enemy: jumps in
  an arc at the player) in 3 designs (A frog, B spring-ball, C hare) × 3 frames (sit, crouch, air) × 6 islands (palette
  + spots + a head feature per island: sprout, shell, plume, snow cap, angler lure, flame).

- 3.82.1 (user's review of the enemy gallery): (1) HIDDEN base Crabbies (normal, fortress) left a 1-art-px gap under
  the spike: their `hid.png` is one EMPTY row and only the sinking skins had `sk.inset[sk.hid] = 1`; now every skin
  does, so `Crabby:headH` = 0 when hidden (drawing, hazard box and trampoline box sit on the surface). (2) FORTRESS
  GUMMY key: the Gummy art faces RIGHT (drawn unflipped when walking right), so the wind-up key goes on the LEFT = its
  back (`back()` in `make_variant_skins.py`; it stuck out in front). 3.82.2: the SAME drawing mirrored, 1-px stem
  included (3.82.1 dropped the stem to fit and the user wanted it back): body and feet moved one column right (cols
  3-13), key in cols 0-2; `helmetDx = 1` (new generic Gummy field) keeps the helmet on its head. (3) **DARK EDGE for dark enemies** (generic):
  class field / trait `darkEdge = { r, g, b, a }` → the `EntityTypes` render wrapper draws the entity's OWN silhouette
  in that flat colour 1 screen px around it (`Silhouette.around`: the body's render called 8 times shifted, under a
  flat-colour shader; `self._edgePass` = skip render side effects such as `Crabby:renderDig`), then the normal drawing —
  colours untouched. Only where it is dark: `Silhouette.dim(level, y)` = dusk + everything `Silhouette.on` covers
  (dark levels, night, caves, under the surface line), with `Silhouette.level` set by both level states while drawing
  (nil elsewhere: editor, map). A pure function of level + position: same in SP, online and for bots. Not when frozen.
  On: `gummy_magma`, `crabby_lava`, `crabbytramp_lava` (warm light grey, thinner than the player's white edge). Drawn
  before the darkness (it dims with the scene). Harness `mechanics tapa_base`; `level_shots` shows it.

- 3.82.3: WALK frames of the Cave and Lava Crabby redrawn (`tools/art/enemies/make_crab_species.py`, only crab2 / crab3; crab1 = the
  approved standing pose): they barely moved (cave: one foot, 1 px; lava: the middle legs never). Cave = the base
  Crabby's three gestures one column to the right (open → all four tucked in → off-step with the hip shifted). Lava (six
  legs): one side OPENS (hip out, feet 0-3-8) while the other gathers straight, and frame 3 is its mirror. The user was
  HAND-EDITING `assets/images/enemies/gummy_fortress/*.png` at that moment: don't re-run `make_variant_skins.py --apply` over
  them without porting their edits first.

- 3.83.0 (user): the Fortress Gummy sprites and the Lava Crabby's legs (crab1-3) are now HAND-EDITED by the user —
  don't re-run `make_variant_skins.py` / `tools/art/enemies/make_crab_species.py` over them without porting the edits first. ICY CRABS
  SMALLER (user: slightly smaller than they were, still bigger than the other Crabbies): the pixel scale is now PER
  CLASS — small Crabby `artScale` (class field, default `GUMMY_SCALE` 4; read by `Entity.create` for the sprite size and
  by crabby.lua for body, claws, sinking and the stuck pose): Icy Crabby 3.5 (63x45 px, was 72x52; a non-integer
  scale: art pixels are 3 or 4 screen px); its COVERS (ice spike, icicle, snow mound, trampoline) keep their size.
  Mega: class field `MS` (Mega 10, Icy Mega 9 = 162x117, was 180x130; `self.MS` in size and drawing) and
  `Mega:smallK()` (`smallPx` = the scale of its small crab when it deflates and flees). Head spike, claw offsets (art
  px) and hitbox fractions follow the body. Harness `icecrabby_rules` measures with each crab's own scale.
