# Plan: Gust, Scale, Box and Seed (design stage)

Approved by the user on 2026-10-27 (0.5.67): the **Gust** (enemy), the **Scale** (mechanism), the **Seed** (item) and,
as the Scale's companion, a pushable **Box**; then two hazards the user added: the **Blizzard** (random wind) and the
**Geyser**. **Status: in the game (0.5.68), not yet in real levels — test arena `tools/levelgen/arenas/cajas.json`.** Tick a step (`[x]`) in the same commit that does it.

| Thing | Generator | Previews (outside the repo) |
|---|---|---|
| Gust | `tools/art/enemies/make_gust_sprites.py` | `FlappyMonster_pruebas/nuevos/soplon/` (`vista_previa.png`, `anim_<isla>.gif`) |
| Scale + Box | `tools/art/world/make_scale_box.py` | `FlappyMonster_pruebas/nuevos/balanza_caja/` |
| Seed | `tools/art/world/make_seed_plants.py` | `FlappyMonster_pruebas/nuevos/semilla/` |
| Blizzard + Geyser | `tools/art/world/make_wind_geyser.py` | `FlappyMonster_pruebas/nuevos/ventisca_geiser/` (`geiser_<isla>.gif`, `ventisca_torre.gif`) |
| Sounds | `tools/sounds/props.py` | `FlappyMonster_pruebas/nuevos/sonidos/*.wav` |

Every generator writes previews by default and the game assets only with `--apply` (after the user's approval).

## The designs

- **Gust** (`Soplón`): a little CLOUD with a face — v2 (the user: "more cloud-like, its body changing in the
  animations, more transparent and rounded; the blowing mouth doesn't read as a mouth"): five round puffs that move and
  grow / shrink from frame to frame, a semi-transparent rim and body with opaque highlights along the top-left, pink
  cheeks when it swells, and a real O mouth (round lips, a dark hole, the air coming out) with the face leaning back
  while it blows; when it pops it breaks into loose puffs. (v1: three lobes, flat underside — a round body with a tuft
  had read as the Bomb.) 16×16 ×4, looking left: 1-2 floating, 3-4 breathing in (swells, eyes squeezed, puffed cheeks), 5-6 blowing
  (round O mouth, deflates), 7-8 bursting (a ring of air). Wind particles 8×8 × 3 frames per island. Islands: meadow
  dandelion puff (sprout and seeds) · coast sea foam (bubbles) · fortress chimney soot (rising wisps) · snow cloudlet
  (a snowflake) · cave pale dust (glowing motes) · volcano ash (embers, glowing eyes).
- **Scale** (`Balanza`) — **APPROVED** by the user ("perfect"): a pan 48×8 (3 cells, a ring in its centre), a rope 4×8 that repeats (braided rope; a chain in
  the fortress and volcano), a pulley 16×16 with a fork to hang from the ceiling, 2 frames (it turns). Islands: planks
  with grass · driftwood tied with rope · riveted iron tray · ice slab with frost · stone slab with a glowing crystal ·
  basalt with lava cracks.
- **Box** (`Caja`): 16×16 + 4 pieces for breaking. Islands: wooden crate with an X brace · driftwood crate with a rope
  · iron box with rivets and a plate · ice block · stone block with a glowing rune · basalt with a lava crack.
- **Seed** (`Semilla`) — v3, REAL PLANTS (the user: the fortress, ice and lava ones "looked like structures, not
  plants", and all needed more leaves and BIG intermediate leaves to climb): the seed 12×12, a 3-frame sprout (two
  little leaves), a base with roots, two stem tiles that alternate small leaves left / right, a BIG LEAF 32×10 (flipped
  for the other side) every 2 cells, and the CROWN on top 48×16. Islands: bean → beanstalk · kelp pod → kelp with
  fronds and floats · thorny seed → castle IVY (bramble with thorns and purple berries) · snow pod → FROST FERN with a
  white SNOW FLOWER on top · glowing spore → glowing mushroom with BRACKET FUNGI as the big leaves (it gives light) ·
  ember seed → FIRE LILY (dark leaves with glowing veins, a flame-like flower). (v1: chain / ice pillar / basalt
  column; v2 moved the platform to the top — a T — because leaves halfway up made a cross and the ice one a sword.)
- **Seed v4** (the user on v3: "very repetitive and a bit strange, not the typical plant you'd expect — especially the
  lava, meadow and coast ones; the others are passable"): those three are now DRAWN WHOLE, no stacked 16-px tile — a
  curving stem, leaves of different sizes at irregular heights (seeded random: always the same image), one image per
  height (4, 5, 6 cells; the game reveals it from the bottom as it grows); the big leaves / arms stay at 2 and 4 cells
  (right, left) and the crown on top, where the game puts the platforms. Meadow: a textbook BEANSTALK (two twisting
  strands, heart leaves, curly tendrils, a bean pod). Coast: golden-brown GIANT KELP (wide wavy fronds, air bladders; the
  big fronds float on a bladder). Volcano: a LAVA CACTUS of black obsidian with glowing veins — its ARMS are the
  platforms, a fire flower on top. Fortress ivy, frost fern and glowing mushroom keep v3.
- **Seed v5** (the user on v4: meadow, coast and fortress fine; ice, cave and volcano "a bit strange"): drawn whole
  too — snow: a FROST FERN (teal-green fronds with leaflets slanting to the tip, white frost on their tips; the big
  fronds are flat on top to stand on; a white snow flower on top) · cave: a real GLOWING MUSHROOM (a thick curving foot
  that widens at the base, bracket fungi on its sides as platforms, a big domed cap with glowing spots, little mushrooms
  at its foot) · volcano: an EMBER VINE (charred twisted stems, black heart leaves with glowing edges and veins, little
  flame flowers, a fire flower on top) — the lava cactus of v4 looked geometric.
- **Blizzard** (`Ventisca`): wind streaks 32×8 × 3 frames, semi-transparent, carrying each island's bits (snowflakes
  in the tower), rotated by the game for up / down; the WARNING is an arrow 16×16 × 2 frames blinking at the screen
  edge the wind will come from.
- **Geyser** (`Géiser`): a vent 16×8 per island (rock with grass, sand with a shell, an iron grate, an icy hole,
  crystals, a fumarole), a warning 3 × 16×8 (bubbles / puffs, more and more), a column 16×16 × 3 frames that repeats
  upward (semi-transparent, stripes rising) and a crest 16×16 × 3 frames. Meadow and coast WATER (strong blue with an
  opaque darker edge: a pale blue vanished against the sky) · snow WATER THAT FREEZES (an ice pillar 16×16, its top
  16×8 to stand on, 2 crack frames before it breaks) · fortress STEAM · cave GLOWING steam (white sparks) · volcano
  SMOKE with embers.
- **Sounds** (18, not listened to by me): `wind_warn`, `wind_gust`, `geyser_rumble`, `geyser_burst`, `steam_hiss`,
  `ice_freeze`, `gust_inhale`, `gust_blow`, `gust_pop`, `scale_creak`, `scale_launch`,
  `box_push`, `box_land`, `box_break`, `seed_pickup`, `seed_plant`, `seed_grow`, `seed_wilt`.

## Decisions added during the build (0.5.68, the user)

- **Carrying** is a general mechanic: UP picks up (also crouching) and throws; crouch + UP puts down carefully
  beside; a tooltip with the device's UP button shows over carryable things. UP no longer jumps. Carryable: the bomb
  object (unlit until thrown), a new SMALL BOX, the Seed.
- **Small box**: carried, also pushed (light); thrown, breaks only on a strong impact; respawns. The big box is much
  heavier to push and breaks on spikes, lava and big falls (a Scale launch), never carried.
- **Bomb object**: respawns (prop `respawn`), lights on a hard impact; it replaces every standing live bomb.
- **One island module** (`Isles`) for all types: art per island and island families of enemies.

## Behaviour agreed (from the proposals)

- **Gust**: floats; breathes in (~1 s warning), blows a 5-6-cell horizontal gust that PUSHES (no damage) players and
  light objects; stomped while breathing in it bursts; stomped while blowing it bounces you; a ground pound always
  pops it; its body is harmless from the side. Island twists: coast pushes toward the water, snow leaves frost
  (slide), caves its gust is a noise, volcano the gust burns after 2 s inside it.
- **Scale**: weight lowers a pan and raises the other; a ground pound on one catapults what is on the other; enemies,
  boxes and bombs count as weight; works in co-op.
- **Box**: pushed by walking into it (falls off ledges, stops at walls), solid to stand on, counts as weight on a
  Scale. A ground pound BREAKS it (its pieces) and, so no level can soft-lock, it REAPPEARS at its original spot after a
  while (the user).
- **Seed**: carried one at a time; planted with a ground pound on a plantable block; grows in ~1 s, 4-6 cells; climb
  it, stand on its top; wilts after ~20 s or when another one is planted. Coast kelp also underwater with air
  bubbles; cave mushroom gives light; volcano basalt stands over lava.

- **Blizzard** (proposed): an area / level setting (`windzone`: its rectangle, which directions it may blow, how often,
  how strong, how long). Every few seconds at random: a ~1 s WARNING (the arrow blinks at the screen edge the wind
  comes from + `wind_warn`), then 2-3 s of wind (`wind_gust`, streaks) that pushes players, enemies and everything with
  physics left, right, up or down — up helps you fly, down drags you. First in `torre_viento` (all FOUR directions),
  reusable anywhere. The user approved the 1 s warning, 2-3 s of wind and a random gap.
- **Geyser** (proposed): a vent placed on the floor; every few seconds it bubbles (~1 s warning: `geyser_rumble`) and
  erupts a column 4-6 cells high for ~2 s that pushes UP everything with physics (players, enemies, boxes, bombs,
  seeds…), then falls back. Snow: the column FREEZES into an ice pillar you can stand on for a few seconds, then it
  cracks and shatters. Cave: the glowing steam lights the dark around it. Volcano: the smoke ONLY PUSHES, like the
  others (the user: "for continuity and not to confuse players").

## Open — to do next (the user, 2026-10-28)

- [ ] **Air pushing a box into the player**: player on the LEFT of a box, a Gust blowing from the right towards the
  left → instead of the box pushing the player along, the player is TELEPORTED to the right side of the box and only
  then pushed. Wanted: the box (moved by the air) pushes the player in front of it. (Today `Box:moveAndCollide` only
  refuses to move into a player, and the player's overlap resolution can still pick the far side.)
- [ ] **Geyser and weight** (the user's clarification): it already lifts heavy things slower. Missing: (1) the
  weight must be the TOTAL of what it lifts, everything stacked on it included (more boxes, a player on top), like
  the Scale; (2) the jet must STOP at the underside of what it is lifting: drawn only up to that object, and pushing
  nothing above it (today the column keeps going through it to its full height and pushes what is higher up).

## Steps

- [x] 1. Designs approved by the user (sprites, animations, sounds) — iterate on the previews. Scale: approved
  (0.5.67); Gust v2, Blizzard and Geyser APPROVED; sounds kept as they are until the user can listen (they will say);
  Seed: meadow, coast and fortress approved, v5 of cave and volcano APPROVED, snow simplified in v6
  (the v5 fern, with 1-px leaflets and frost on every tip, looked over-detailed): ALL DESIGNS APPROVED.
- [x] 2. `--apply` the approved art and sounds.
- [x] 3a. The generic systems: moving bodies and body parts, air (`Push`), carrying (`Carry`, UP = grab, tooltip),
  islands (`Isles`) — [carry-and-push](../gameplay/carry-and-push.md). Box and small box in the game; the bomb object
  carryable, respawning, lit by hard impacts; standing live bombs replaced in the levels.
- [x] 3. Scale in the game (entities, physics, network, editor, harness). The user, testing it: the pan hitbox was
  thicker than the plank (things floated) and stacked things did not weigh — both fixed.
- [x] 4. Gust in the game (only pushes in every island, like the volcano Geyser).
- [x] 5. Seed in the game (carried, planted with a ground pound; platforms measured on the drawings).
- [x] 5b. Blizzard and Geyser in the game (not yet placed in `torre_viento` or any level).
- [ ] 6. Levels that use them; docs reference; release.
