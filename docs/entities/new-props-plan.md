# Plan: Gust, Scale, Box and Seed (design stage)

Approved by the user on 2026-10-27 (0.5.67): the **Gust** (enemy), the **Scale** (mechanism), the **Seed** (item) and,
as the Scale's companion, a pushable **Box**. **Status: DESIGN — sprites, animations and sounds as previews for the
user to approve; nothing in the game yet.** Tick a step (`[x]`) in the same commit that does it.

| Thing | Generator | Previews (outside the repo) |
|---|---|---|
| Gust | `tools/art/enemies/make_gust_sprites.py` | `FlappyMonster_pruebas/nuevos/soplon/` (`vista_previa.png`, `anim_<isla>.gif`) |
| Scale + Box | `tools/art/world/make_scale_box.py` | `FlappyMonster_pruebas/nuevos/balanza_caja/` |
| Seed | `tools/art/world/make_seed_plants.py` | `FlappyMonster_pruebas/nuevos/semilla/` |
| Sounds | `tools/sounds/props.py` | `FlappyMonster_pruebas/nuevos/sonidos/*.wav` |

Every generator writes previews by default and the game assets only with `--apply` (after the user's approval).

## The designs

- **Gust** (`Soplón`): a little CLOUD with a face (three lobes, flat underside — a round body with a tuft read as the
  Bomb). 16×16 ×4, looking left: 1-2 floating, 3-4 breathing in (swells, eyes squeezed, puffed cheeks), 5-6 blowing
  (round O mouth, deflates), 7-8 bursting (a ring of air). Wind particles 8×8 × 3 frames per island. Islands: meadow
  dandelion puff (sprout and seeds) · coast sea foam (bubbles) · fortress chimney soot (rising wisps) · snow cloudlet
  (a snowflake) · cave pale dust (glowing motes) · volcano ash (embers, glowing eyes).
- **Scale** (`Balanza`): a pan 48×8 (3 cells, a ring in its centre), a rope 4×8 that repeats (braided rope; a chain in
  the fortress and volcano), a pulley 16×16 with a fork to hang from the ceiling, 2 frames (it turns). Islands: planks
  with grass · driftwood tied with rope · riveted iron tray · ice slab with frost · stone slab with a glowing crystal ·
  basalt with lava cracks.
- **Box** (`Caja`): 16×16 + 4 pieces for breaking. Islands: wooden crate with an X brace · driftwood crate with a rope
  · iron box with rivets and a plate · ice block · stone block with a glowing rune · basalt with a lava crack.
- **Seed** (`Semilla`): the seed 12×12, a 3-frame sprout, a base, a stem that repeats and, ON TOP, a 3-cell platform
  (the plant is a T: leaves halfway up made a cross, and the ice one a sword). Islands: bean → beanstalk with a leaf
  canopy · kelp pod → kelp with floats · bolt → chain with a hooked bar · ice shard → ice pillar with a crystal ledge ·
  glowing spore → glowing mushroom (its cap is the platform; it gives light) · obsidian pebble → basalt column.
- **Sounds** (12, not listened to by me): `gust_inhale`, `gust_blow`, `gust_pop`, `scale_creak`, `scale_launch`,
  `box_push`, `box_land`, `box_break`, `seed_pickup`, `seed_plant`, `seed_grow`, `seed_wilt`.

## Behaviour agreed (from the proposals)

- **Gust**: floats; breathes in (~1 s warning), blows a 5-6-cell horizontal gust that PUSHES (no damage) players and
  light objects; stomped while breathing in it bursts; stomped while blowing it bounces you; a ground pound always
  pops it; its body is harmless from the side. Island twists: coast pushes toward the water, snow leaves frost
  (slide), caves its gust is a noise, volcano the gust burns after 2 s inside it.
- **Scale**: weight lowers a pan and raises the other; a ground pound on one catapults what is on the other; enemies,
  boxes and bombs count as weight; works in co-op.
- **Box**: pushed by walking into it (falls off ledges, stops at walls), solid to stand on, counts as weight on a
  Scale. (Whether a ground pound breaks it: to decide — the art includes the pieces.)
- **Seed**: carried one at a time; planted with a ground pound on a plantable block; grows in ~1 s, 4-6 cells; climb
  it, stand on its top; wilts after ~20 s or when another one is planted. Coast kelp also underwater with air
  bubbles; cave mushroom gives light; volcano basalt stands over lava.

## Steps

- [ ] 1. Designs approved by the user (sprites, animations, sounds) — iterate on the previews.
- [ ] 2. `--apply` the approved art and sounds.
- [ ] 3. Box + Scale in the game (entities, physics, network, editor, harness).
- [ ] 4. Gust in the game.
- [ ] 5. Seed in the game.
- [ ] 6. Levels that use them; docs reference; release.
