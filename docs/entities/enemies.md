# Enemies

The regular enemies. Every island has its own Gummy and its own Crabby (same class, other art, sometimes other
shape); dark levels have the Gloomy Crabby; plus the Hopper, bombs, the pufferfish, the mortar, the Mole (every island), and the
jungle's Rhino Beetle, Piranha and Carnivorous Plant. Types, files and
props: [reference/entities](../reference/entities.md). Base behaviour: [overview](overview.md).

| Island | Gummy | Crabby (spike / trampoline) | Hopper skin |
|---|---|---|---|
| Meadow | `gummy` | `crabby_river` / `crabbytramp_river` | pradera |
| Coast | `gummy` | `crabby` / `crabbytramp` (the originals) | costa |
| Fortress | `gummy_fortress` (wind-up toy) | `crabby_fortress` / `crabbytramp_fortress` (steel) | fortaleza |
| Summits | `gummy_ice` | `crabby_ice` (4 covers: ice spike, icicle, snow mound, trampoline) | nieve |
| Caves | `gummy_cave` | `crabby_cave` / `crabbytramp_cave`; dark levels: `gloomy` | cueva |
| Volcano | `gummy_magma` | `crabby_lava` / `crabbytramp_lava` | volcan |
| Jungle | `gummy_jungle` (tree frog) | `crabby_jungle` / `crabbytramp_jungle` (Halloween crab) | jungla |

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

- **Jungle variants** (0.5.83, the 7th island `jungla`; the user approved the proposal of
  `tools/art/enemies/make_jungle_skins.py`, previews in `FlappyMonster_pruebas/jungla/variantes/`): **Gummy de la jungla**
  (`gummy_jungle`: the Gummy's every pixel in leaf green, two bulging TREE-FROG eyes on top of the head — rows 0-1, empty
  in the Gummy —, dark spots on back and sides, never on the face, orange feet; `assets/images/enemies/gummy_jungle/`,
  variant `jungle` of the anim set `enemies/gummy`) and **Crabby de la jungla** (`crabby_jungle` + `crabbytramp_jungle`,
  Crabby skin `jungle`: a Halloween land crab — purple shell with two yellow spots behind the eyes, long splayed ORANGE
  legs with the River Crabby's silhouette and walk, MAGENTA 5x5 claws placed like the lava ones (x 5.4, y −1.6), sinks
  in 5 rows like the River Crabby; anim set `enemies/crabby_jungle`). Types from `CrabVariant.defs('jungle', …)` and the
  usual Gummy subclass; `Isles.FAMILIES` maps `jungla` to them. Tests: `mechanics islas` / `islas_arte` (every island's
  family types spawn, walk, die and use their own art), `tapa_base`; test arena `tools/levelgen/arenas/islas.json` (from
  `make_islas.py`: each island's Gummy, Crabbies, Hopper, food and Geyser side by side). Not checked: the helmet over the frog eyes (they may peek
  out from under it), and how they read on the jungle's own sky and tiles (made by other agents at the same time).

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
  `skin` 'auto' (by `level.background`; snowy level → nieve) | pradera | costa | fortaleza | nieve | cueva | volcan | jungla —
  `assets/images/enemies/hopper/<isla>-Sheet.png` (4 frames 16x21: idle, crouch, air, flat) from
  `tools/art/enemies/make_hopper_sprites.py --apply`, which builds them from the pixel maps in `tools/art/enemies/make_enemy_designs.py` (HOP,
  ISLES, HEAD: same shape, own palette, spots and head feature per island). Sounds `enemies/hopper/` from
  `tools/sounds/hopper.py`. Test arena `tools/levelgen/arenas/saltarines.json` (one per skin); harness `mechanics
  saltarin`, `online_smoke LEVEL=<that arena> WATCH=hopper`. NOT placed in any real level yet (waiting for the user).
  Not done: glow of the volcano eyes in dark levels.

- **THE MOTH: cave Hopper in a DARK level (0.5.38, protocol 65; the user's pick "Polilla" of three, 2026-10-26)** —
  the opposite of the Gloomy (blind, hunts by sound): it hunts by LIGHT. Only when `level.dark` and its skin resolves
  to `cueva` (`Hopper:isMoth`; `Hopper.skinId` = the skin without looking at loaded sheets, the server has none);
  in lit levels and with any other skin it is the normal Hopper (the user's call). It SEES a player only if lit and
  in a clear line: flashlight on (`lightOn`) within `range` × `sense`, or anyone inside its own lantern (`LANTERN_R`
  2.5 tiles). Lost from sight → hops to where it last saw them for `MEMORY` 3 s (`seenX/Y`, `memT`; `Hopper:goal`).
  A LOUD noise (radius ≥ `LOUD` 6 tiles: switch, hit, broken block, hurt, kill, ground pound, trampoline, bomb...;
  not a pickup or its own landing, 4) heard on the ground → state `scared`: lantern off (`lightOff` / `lightOn`
  sounds), crouched and shaking, still for `SCARE_T` 2.2 s (a new loud noise restarts it) = the window to stomp it
  in the dark. Flashlight = bait, noise = weapon. NO Hopper sound is a noise (0.5.39; `hopLand` was 4): the Gloomies went to every landing and piled up around it (the user). Its lantern gives light (`Hopper:lights()`, warm, flickers in the
  crouch telegraph, off when scared). Arena `tools/levelgen/arenas/saltarines_oscuras.json`; harness `mechanics`
  case `saltarin_cueva`. Placed (0.5.39, replacing floor Gloomies: they were too many): cripta_del_silencio 2, gruta_lugubre 2, templo_del_eco 8. Waiting for the user's verdict after playing; it is the base of the Giant Hopper
  ([new-bosses-plan](../bosses/new-bosses-plan.md)).

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
  `tools/art/enemies/make_puffer_redesign.py --apply` (a separate spike ring was tried and dropped). REDESIGNED
  (0.5.29) for the Giant Pufferfish (the coast's new boss, [new-bosses-plan](../bosses/new-bosses-plan.md)): the user
  picked design A "Arena" of `tools/art/enemies/make_pufferfish.py --apply A` — sand yellow, brown spots, cream
  belly, forked orange tail that flaps between the swim frames, spines that are PART of the sprite (short half
  inflated, long inflated; not a separate ring); B "Arrecife" and C "Coral" stay in the script. Same 4 frames 16x16,
  no code change. The old restyle script is retired (`FlappyMonster_originals/herramientas_retiradas/`).
  (0.5.31, the user) CHUBBIER (swim ry 4.5), the pectoral fin swings up / down with the tail between the swim
  frames, and the eye is one colour (black 2x2, no white).
  (0.5.33, the user: deflated it "looked very puffed", and the spines "looked dirty") DEFLATED IT IS A NORMAL FISH:
  swim frames long and low (rx 5.6, ry 3.1, lowered to cy 9.4 so the belly stays where it was: the stranded boss
  still lies on the floor) and narrowing towards the tail (`taper`); only frames 3-4 are round.
  Spines redone: straight in the 8 directions (no 30° rays with jagged steps), none at the back (tail), each one
  outline-coloured with a light tip (1 px half inflated, 2 px inflated; shortened to fit the frame), diagonal ones
  joined to the body by one outline pixel. Not reviewed by the user yet in game.
  **Out of water** (0.5.31, the same physics as the Giant Pufferfish): it follows the water level — if the surface
  drops below its back it swims down (`SINK_SPD`, only towards more water, never into a block), and never picks a dry
  target; if it ends up dry (a flood falling faster than it, or an area leaving the water) it FALLS with collisions
  ('dry_fall'), flops wildly on the ground in random hops that tire ('dry_flop'; no hazard), swims again if it lands in
  water, and after `dryTime` s (prop, default 5) DIES ('dry_die': belly up, fades, `alive=false`). Inside a block counts
  as wet (its area may cross blocks). Drawn from state + deadTimer: the same online.

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

## Gust (`gust`, 0.5.68)

A little cloud with a face (`types/enemies/gust.lua`; art `assets/images/enemies/gust/<isle>-Sheet.png` + `wind-Sheet.png`
from `tools/art/enemies/make_gust_sprites.py`; one look per island through `Isles`, prop `isle`). It floats (no
wings: class field `noWings`). When it sees a player in front of it at its height (within `reach`) it turns, INHALES
for 1 s (swells: the warning) and BLOWS for 1.6 s a horizontal gust (`reach` × `width` tiles) that PUSHES players and
everything with physics without damage (`pushAt`, [carry-and-push](../gameplay/carry-and-push.md)), then rests 1.2 s.
Stomped while inhaling or floating it pops; stomped while blowing it only bounces you; a ground pound always pops it;
its body never hurts. Every island only pushes (the user's rule for the Geyser: continuity); its blow is also a noise
(`noises`) for the Gloomies. Harness `mechanics` `soplon`.


## Rhino Beetle (`beetle`, 0.5.76) — jungle only

`types/enemies/beetle.lua`; art `assets/anim/enemies/beetle.json` (22x20 frames at ×4, facing RIGHT; design D chosen by
the user, legs retouched by hand: `tools/art/enemies/make_beetle.py` never rewrites the sheet). Its giant is the
jungle boss ([giantbeetle](../bosses/giantbeetle.md)). Approved design (2026-10-28):
- Walks (base walk, 4-frame tripod cycle) and turns at walls and edges. Sees a player IN FRONT at its height within
  `SEE` 6.5 tiles with no wall in between → 'windup' (`WIND_T` 0.45 s, scraping) → 'charge' (`CHARGE_V` 380 px/s, ≤ 2.4 s;
  stops at an edge) → hits a wall: 'daze' (0.9 s) and turns. `COOLDOWN` 1.2 s between charges.
- Touching it from the side: 1 HP (`onTouch` 'hurt', fixed). STOMP → ON ITS BACK ('onback', `BACK_T` 3 s, harmless,
  legs flailing) → it rights itself ('righting') and goes on. Stomped again on its back, or any ground pound → dies. The
  push of a nearby ground pound also flips it.
- On its back it is CARRYABLE (`systems/Carry`, weight 1): thrown ('thrown'), it knocks down the enemies it hits
  (`dieFling`) and breaks boxes, then lands on its back again.
- Falls in LAVA, on SPIKES or into the VOID (walking, on its back or thrown): it EXPLODES (`dieBurst`; the user). The
  void = landing on the bottom border of the level at the bottom of a pit (`Entity:inVoid`: outside the level is solid,
  so `fellOut` never happens).
- Network: nothing of its own (state, deadTimer, frame, facing). Drawing: each frame with its lowest pixel on the
  ground (`Set:footGap`, measured from the image; the user: legs floated in some frames) PLUS 1 px: the front legs are
  1 px longer, so the back legs touch the ground and the front ones sink 1 px into it (the user).
- 0.5.78 (the user): (1) its ROUTE stopped the charge like an invisible wall (it got dazed against nothing) → charging,
  thrown, carried or on its back it ignores the route (`freeOfRoute`) and charges to the real wall, then walks back
  into its route; (2) thrown outside its route it flew back towards it → now it flies where it is thrown; (3) the bounce
  of the stomp that flipped it landed on it again and killed it → flipping pushes you SIDEWAYS and it can't be stomped
  for `INV_FLIP` 0.4 s (you bounce off); (4) carried it froze → it keeps kicking (`whileCarried`), TREMBLES for its
  last `WARN_T` 0.9 s and, if you still hold it, breaks free beside you and takes 1 HP; (5) its box is its BODY (no
  horn), centred: the drawing is shifted 2 px (`BODY_DX`).
- 0.5.79 (the user): (1) carrying and throwing one about to right itself restarted its count → thrown, its on-back
  count (`deadTimer`) goes on, so it rights itself soon after landing; (2) charging, it went THROUGH the player →
  `chargeHits`: a player in front is pushed out of its box in the charge direction (even while invulnerable), takes 1
  and recoils (`PUSH_CD` 0.35 s); pinned against a wall, the beetle stops there and is dazed; (3) charging, it sweeps
  what it meets once per charge: `canBeKnocked` entities get `knockback` (enemies stunned, bombs kicked AND lit, other
  beetles flipped), carryable light things are flung (`onThrow`, `SWEEP_VX/VY`), bosses never; (4) dead it vanished →
  a SQUASHED frame (`assets/images/enemies/beetle/dead.png`, made by the generator from the user's walk frame, the
  sheet untouched), fading out.
- 0.5.80 (the user): (1) only the IMPACT pushes: a player who can be hit loses 1, is moved out of its box and recoils
  almost flat (with the normal recoil hop they landed on it and stomped it by accident); invulnerable — including right
  after that hit — the charge goes THROUGH them ("more comfortable and readable"); enemies, once per charge; (2) a charge
  that ends without hitting anything (time out, or an edge) no longer stops dead → 'brake' (`BRAKE_T` 0.4 s): skids to a
  halt (never off an edge) with dust and a scrape (`boxPush`), leaning on the charge frame.
- 0.5.86 (the user: "it camouflages too well in the jungle"): new colours, same shape — METALLIC BLUE (chosen among
  blue, red/black, gold and violet; `make_beetle.py --recolor` previews them, `RECOLORS` / `SMALL_PAL`). `--apply`
  recolours the user's retouched `beetle-Sheet.png` tone by tone (the brown/green original is kept in
  `FlappyMonster_originals/`), and `dead.png` / `fly-Sheet.png` follow. The giant keeps its colours.
- **Flying Rhino Beetle** (prop `wings`, 0.5.79; the Giant Rhino Beetle's minions, like the King Gummy's flying
  guards): flies with its own wings (`fly` anim, `assets/images/enemies/beetle/fly-Sheet.png`; free flight, `flyArea`
  set by whoever spawns it) and never charges. A stomp (or any knock) drops it ON ITS BACK like the walking one
  (carryable, a second stomp kills); when it rights itself it opens its wings and flies again. What is drawn comes from
  `state` + the prop (`Beetle:winged`), so online looks the same.
- Tests: `mechanics escarabajo`, `escarabajo_lanzado`, `escarabajo_ruta`, `escarabajo_manos`, `escarabajo_arrolla`;
  `giantbeetle_rules voladores`.

## Mole, Piranha and Carnivorous Plant (0.5.96) — the user's designs

Three enemies designed with the user on 2026-10-29. Art: `tools/art/enemies/make_jungle_enemies.py` (two designs each, A
and B; the mole's in the 7 islands; previews in `FlappyMonster_pruebas/enemigos_nuevos/`). The user's brief after the
first round: "not so detailed — many differently coloured pixels at this resolution do not read — and not so chubby:
slimmer, more original shapes even if they stand out a little from the rest; if everything is the same, there will never
be anything new". So: SIMPLE FLAT COLOURS (3 tones per part: outline, shadow, mid; no highlights or specks), one
ornament per island, slim long silhouettes; B was always the bolder option. Chosen: mole **A «Periscopio»** (B
«Gusano», a long worm-like mole, stays in the script), piranha **B «Aguja»** (A «Mandíbula», all head with a red jaw),
plant **B «Cepo»** (A «Cuello», a small flytrap on a long neck). Sounds: `tools/sounds/jungle_enemies.py`
([sound](../audio/sound.md)). Test arena: `tools/levelgen/arenas/nuevos_enemigos.json` (`make_nuevos_enemigos.py`).
Tests: `mechanics topo`, `topo_culetazo`, `topo_suelo`, `pirana`, `pirana_pisar`, `planta`; `SHOT_JUNGLA=1` →
`mechanics_jungla.png` (every pose). NOT placed in any real level yet; feel, timings and sounds not judged by a person.

### Mole (`mole`, «Topo») — every island

`types/enemies/mole.lua`; sheets `assets/images/enemies/mole/<isle>-Sheet.png` (14 frames 22x20 at ×4, facing RIGHT,
feet on the bottom row: mound ×3, emerge ×2, idle ×2, bite ×2, dive ×2, dizzy ×2, dead), anim set
`assets/anim/enemies/mole.json` with one VARIANT per island; `isleArt` = the editor prop `isle` (Auto = the level's
island). Each island: its fur, nose and claws + at most ONE ornament (coast: a conch shell; fortress: a sapper's bronze
helmet; snow: a red scarf; cave: a miner's helmet with its lamp; jungle: a leaf hat; meadow and volcano — black fur,
fiery nose and claws — none), and the MOUND is its island's earth (grass cap on the meadow and the jungle, ash cap on the
volcano).
- States: `under` (only a MOUND moves along the ground surface; harmless, body off, cannot be stomped) → `tell`
  (`TELL_T` 0.45 s, the mound shakes) → `emerge` (0.14 s) → `bite` (0.45 s) → `look` (prop `lookTime`, 0.9 s: the
  window to stomp it) → `dive` (0.25 s) → `under` with `COOLDOWN` 1 s before it can emerge again.
- Under ground it goes towards the nearest player within `range` tiles sideways (default 6 × difficulty `sense`) whose
  feet are on or up to `UP_SEE` 3 tiles above its ground, at `speed` (110 px/s; the player runs at 240). It emerges
  when the player is within `REACH` 0.3 tiles sideways and the player's feet no higher than `REACH_UP` 1.5 tiles. Nobody
  near: it wanders slowly (`WANDER_V` 35 px/s) back and forth.
- Above ground (emerge / bite / look): touching it = 1 HP (`onTouch` hurt, fixed) and a recoil; a stomp kills it
  (squashed `dead` frame, 20 points); the push of a nearby ground pound makes it dizzy.
- GROUND POUND (`onPound`): landing within `POUND_RX` 2.5 tiles sideways of its mound, at the height of its ground
  (`POUND_RY` 1 tile), knocks it OUT: `dizzy` (`DIZZY_T` 3 s, a hop out of the hole, `BossFx.stars` ring, `stunned`
  sound), harmless and stompable; then it dives again.
- Its GROUND (decided here): it only travels over soft soil — material field `diggable` (dirt, grass, jungle grass,
  sand, snow, packed snow, ash, mud) — with air above (no wall, no spikes) and inside its route. NOT stone, deep stone,
  basalt, ice, wood, temple brick, lava. Exception per island (`EXTRA_DIG`): the fortress mole also digs stone and the
  cave mole stone and deep stone (those islands are nearly all stone). At an edge / a wall / undiggable ground it waits
  there while chasing and turns round while wandering. Placed on undiggable ground it stays where it is (still bites
  whoever stands on it). Lava, spikes, the void: bursts (`dieBurst`).
- Network: nothing of its own (state, deadTimer, x, facing). Whether the mound rolls is drawn from how x changes.

### Piranha (`piranha`, «Piraña») — jungle (any water level can use it)

`types/enemies/piranha.lua`; `assets/images/enemies/piranha/piranha-Sheet.png` (9 frames 22x20, facing RIGHT, the fish
centred: swim ×3, leap ×2, bite ×2, fall, dead belly-up), anim set `enemies/piranha`. Design B «Aguja»: long and thin
like a spear, a beak of teeth, teal back, magenta fins.
- `swim`: side to side inside its water (turns where the water ends, at a block or at its route's limit), at its home
  depth but always under the surface (it follows a falling water level), a 4 px bob.
- A player OUT of the water, above the surface, within `range` tiles sideways (4.5 × `sense`) and up to `LEAP_MAX` 5
  tiles above the surface → `aim` (`AIM_T` 0.35 s: rises to just under the surface, trembling) → `leap`: a ballistic arc
  whose top reaches the player (min 1.5 tiles, ≤ 380 px/s sideways), `piranhaBite` near the top; shortened so that it
  always falls back into ITS water (never onto the bank: both ends of its body must land in water). Back in the water →
  `swim` with `cooldown` (1.4 s). A player SWIMMING within range → after the same warning, a straight `lunge` under
  water (330 px/s, 0.45 s).
- Touching it = 1 HP + recoil. It can be STOMPED only in the AIR (leaping): dies belly up and, in water, floats up to
  the surface. In the water a stomp is turned into a hurt (no stomp in water).
- Dry (it lands on dry ground, or the water goes: a falling flood, `flop`): flops in random tiring hops, harmless and
  stompable; back in water it swims; after `DRY_T` 3.5 s it dies. Lava / spikes: bursts.
- Network: its netPack carries `apexT` (the time to the top of the leap), so the client picks leap / bite / fall frames.

### Carnivorous Plant (`carnivoreplant`, «Planta carnívora») — jungle

`types/enemies/carnivoreplant.lua`; `assets/images/enemies/carnivoreplant/plant-Sheet.png` (11 frames 26x24, base on
the bottom row: idle ×2, tell ×2, snap ×2, chew ×2, sleep ×2, withered dead), anim set `enemies/carnivoreplant`. Design B
«Cepo»: two toothed leaves lying flat with a bait flower; closed, an upright green pod.
- FIXED on the ground (static, not pushed / launched / knocked; an obstacle for walkers). `idle` (open) → a player in its
  TRIGGER box (`TRIGGER_HW` ±52 px, `TRIGGER_H` 1.2 tiles up: over it or right next to it) → `tell` (`TELL_T` 0.3 s,
  `plantRustle`) → `snap` (`SNAP_T` 0.15 s, `plantSnap`): a hazard box (`SNAP_HW` ±44 px, 0.9 tiles high) = 1 HP and a
  recoil (out of the pod). Running over it gets you bitten: you have to jump it.
- Then `chew` (prop `chewTime`, 2.4 s): ONLY now (or asleep) can it be stomped (dies, withered, 20 points); touching it
  shut does nothing. → `open` (0.35 s, the snap frames backwards) → `idle`, re-armed after `REARM` 0.4 s. Stomping it
  open does not kill it (it just springs it).
- FEEDING (decided here): anything whose class has `edible = true` — today the Rhino Beetle, thrown or walking /
  charging / on its back — entering its trigger box (or its snap box while closing) → it snaps on it, the beetle
  vanishes (`Entity:dieEaten`, `plantCrunch`) and it SLEEPS (prop `sleepTime`, 6 s; rising "z": `BossFx.sleepZ`, sprite
  `bosses/common/sleep_z.png`), harmless and stompable, then reopens. Other enemies are NOT eaten: walkers treat it as an
  obstacle and turn round.
- Network: nothing of its own; open and waiting it is not sent (`netAtRest`).

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
