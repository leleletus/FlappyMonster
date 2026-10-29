# Carrying, pushing, air and moving platforms

Four generic systems from 0.5.68 that the new props (Box, Scale, Gust, Seed, Blizzard, Geyser —
[new-props-plan](../entities/new-props-plan.md)) are built on. A type only **switches them on**; none of them names a
concrete type.

**Files**

| File | Role |
|---|---|
| `src/world/systems/Carry.lua` | CARRYING: pick up / carry over the head / throw / put down, the "grab" tooltip |
| `src/world/systems/Push.lua` | AIR: whatever blows pushes players and everything with physics, without damage |
| `src/world/entities/Entities.lua` (`solidBodies`) | BODY PARTS and MOVING BODIES (measures `stepDx/stepDy`) |
| `src/player/PlayerCollision.lua` | riding a moving body, one-way bodies, pushing a body (`pushBy`) |
| `src/world/systems/Weight.lua` | WEIGHT of what is on top of something, stacked included (Scale pans, what a Geyser lifts) |
| `src/world/level/Isles.lua` | which ISLAND a level is: art per island and island FAMILIES of types (see below) |
| `src/world/entities/types/items/box.lua` | the Box (`box`, pushed) and the small box (`smallbox`, carried) |
| `tools/art/ui/make_prompts.py` | the tooltip sprite `assets/images/ui/prompts/grab-Sheet.png` (keyboard, pad, touch); also `mash-Sheet.png`, the MASH prompt of a swallowed / frozen player ([player](player.md#swallowed-by-a-carnivorous-plant)) |

## Carrying (`Carry`)

- **Controls (the user, 0.5.68):** the new action **`grab` = UP** (Up arrow, W, D-pad up, stick up; on touch the
  D-pad's up). UP no longer jumps: jump is Space / the jump button only. Next to something carryable, a tooltip with
  the UP button of the device in use (keyboard key, D-pad, touch D-pad) bobs over it. UP picks it up (also while
  crouching) and carries it over the head; UP again THROWS it forward (farther while running); CROUCH + UP puts it
  down CAREFULLY beside the player (in front; behind if there is a wall; never touching the player: a bomb lights when
  touched) — "so nothing blows up". A ground pound while carrying: the PLAYER takes the impact and keeps carrying it (a box does not break, a bomb
  does not light: the user, 0.5.69); only a type with `onCarriedPound` uses it (the Seed is planted). Dying drops it.
- **A type switches it on** with `carryable = true` (class) and optional hooks `canBeCarried()`, `onPickUp(pa)`,
  `onThrow(pa, vx, vy)`, `onPutDown(pa)`, `onCarriedPound(pa)`, `whileCarried(dt, level)` (0.5.78: the Rhino Beetle keeps
  kicking and counting in the hands and breaks free). While carried: state `'carried'`, `e.carriedBy` (sim),
  `e.carrierIdx` (network), `Entity:update` only follows the carrier, no interactions, the air ignores it. A thrown
  object does not hit its thrower for 0.5 s (`thrownBy` / `thrownT`, checked in `Interactions.check`).
- **Carryable today:** the bomb object (picked up UNLIT, lit when thrown; put down carefully it stays unlit) and the
  small box and the Seed (`types/items/seed.lua`): carried, it is PLANTED with a ground pound on firm ground; a plant
  of its island grows in 1 s (4-6 tiles: what fits; fewer than 4, nothing) with big leaves and a crown to stand on
  (one-way body parts, positions measured on the drawing by `make_seed_plants.py` into `<isle>-plant<h>.json`); it wilts
  after `life` s or when its planter plants another, and the seed goes back to its spot. The cave mushroom gives light.
- **SP / server / client:** the player only records the request (`pa.grabReq`, `pa.grabCareful`); `Carry.step` runs
  after the players move (AdventureState, `stepRoom`). The input travels as `Protocol.IN_GRAB_P` (128). In
  snapshots a carryable entity has its carrier index at position 10 (its own `netPack` data starts at 11). The client
  draws what IT carries on its predicted player (`Carry.clientFollow`), the rest from snapshots.

## Pushing and weight (the Box)

- A body with `pushBy(pa, dx)` is pushed when a player WALKS into its side on the ground: it moves (its own
  collisions) by `dx × PUSH_K` and the player stays against its face without losing speed. Since 0.5.71 the speed
  is `0.8 ÷` the weight of the whole ROW of boxes being pushed with their stacks (big 0.4, small 0.8, big + small 0.27). Online the pusher's client moves it ahead (`predX`) while the server says it is the
  pusher.
- `weight` = what it counts on a Scale pan (big box 2, small box and a player 1).
- **Breaking** (both boxes; the user): a ground pound on it, spikes / lava, falling out of the level and a hard
  landing (`BREAK_LAND`: big 1000 px/s ≈ 5 tiles of fall — a Scale launch, a cliff —, small 650: a throw on flat
  ground survives, from a ledge it breaks); the small one also against a wall (`BREAK_WALL` 500). Every broken box
  REAPPEARS at its starting spot after `respawn` s (no level can soft-lock).
- The bomb object lights on a hard impact too (`IMPACT_V` 850 px/s, ground or wall) and can now respawn (prop
  `respawn`); the levels that used a standing LIVE bomb for that (`pradera_explosiva`, `cantera_dinamita`,
  `caldera_roja`, two credits sets) now use a respawning bomb object.

## Moving bodies and body parts

- `bodyParts()` on an entity → extra solid bodies (tables with `getOuterBounds`, `solidFull`, `alive`, optional
  `oneway` = only from above, `moves`). The Scale pans and the Seed's leaves are parts.
- `moves = true`: `Entities.solidBodies` measures how far the body moved since last time (`stepDx`, `stepDy`; once per
  step in SP / server, once per frame on the client). A player standing on it (`pa.standBody`) moves with it the next
  step (`rideBody`): it can go up and down without the player falling through or floating. Entities standing on
  something that moves are carried by whoever moves it (the Box rides another box; the Scale moves what is on its pans).
- The BOT's nav graph has nodes on top of moving bodies too (0.5.99); an owner whose body moves along a known range
  exposes `navPoses()` / `navPose(p)` (the Scale: one pose per tile of `travel`) so the graph is recorded at each pose:
  [bonus and bot](../story/bonus-and-bot.md#zones-that-ride-a-moving-body-0599).

## Air (`Push`)

- An entity that blows declares `pushAt(x, y)` → wind velocity `(wx, wy)` px/s at that point; `Push.collect` gathers
  them into `level.pushers` next to `solidBodies` (SP, server, and the client's prediction from snapshot state, so
  the player's prediction matches).
- Sideways the air DRAGS (added to the player's movement with a little inertia, `pa.windVx`); upward it slows the fall
  and lifts towards `wy`; downward it accelerates down. Entities: `Push.canPush` (enemies and objects with physics;
  not bosses, fixed pickups, reserve, carried or clinging ones) × `windK` (big box 0.4: heavy).

## Islands (`Isles`)

One generic module for everything that changes with the island (the user: one method for everything):
- `Isles.of(level, forced)` = the level's island from its background (`Isles.BY_BACKGROUND`; snow / ice spikes win;
  none = meadow). Used by the Hopper (prop `skin`), the food, the boxes and every new prop.
- A type with `isleArt = true` gets the editor prop `isle` (Auto / an island) and loads `<folder>/<isle>-….png`.
- FAMILIES (`Isles.FAMILIES`: gummy, crabby, crabbytramp → the type of each island) get the prop `isle` with `self`
  by default (nothing changes in old levels); `auto` or an island swaps the placement for that island's type when
  the level loads (`Isles.resolveAll` in `Level`, same in SP / server / client). A new family = one line.
- Islands (`Isles.IDS`, in this order — it is also the row order of `enemies/gust/wind-Sheet.png`): pradera, costa,
  fortaleza, nieve, cueva, volcan, jungla. What changes by island: the Gummy / Crabby / trampoline Crabby families, the
  Hopper (`Hopper.SKINS` + its anim-set variant), the food (`apple.lua` `FILES`), and every `isleArt` type — Box and small
  Box, Scale, Gust (+ its wind row), Seed, Blizzard, Geyser (`KIND`: water / steam / smoke; jungle = water), the Mole
  (0.5.96: its anim-set variant `enemies/mole` + the stone of its island it can dig, `EXTRA_DIG`).
- **A new island** = its id in `Isles.IDS` / `NAMES` / `BY_BACKGROUND` / `FAMILIES`, then the ART by name in every
  folder above (`<isle>-….png`), the anim sets that list per-island images (`enemies/hopper.json` frame + variant,
  `items.json` food frame, `enemies/gummy.json` variant, a new `enemies/crabby_<skin>.json`), `Hopper.SKINS`, `apple.lua`
  `FILES`, `geyser.lua` `KIND` and the editor options (`skinOpts`). `mechanics islas_arte` fails while any of it is
  missing. The jungle (0.5.83) was added this way: `tools/art/enemies/make_jungle_skins.py --apply` (box tied with
  lianas, mossy temple-slab scale with a liana rope and carved pulley, misty gust with a leaf and petals, leafy
  blizzard gusts, turquoise spring geyser in a mossy stone rim, cacao-pod seed growing into a liana with monstera
  leaves and a magenta flower, bananas).

## Weight (`Weight`)

`Weight.stack(base, level, except)` → players standing on `base` (or on the stack), entities resting on it, and their
total weight; `Weight.total(o, level, isPlayer)` = `o` + its stack. A player weighs 1 + what they carry; an entity its
`weight` (1 by default); flyers, carried things, bosses and ghosts nothing. Used by the Scale pans and the Geyser.

## Tests

`mechanics`: `caja_empuje`, `caja_rota`, `caja_borde`, `cajas_golpes`, `cargar`, `bomba_reaparece`, `islas`, `islas_arte` (every
island has its art in everything above), `viento`,
`cuerpo_mueve`, `balanza`, `balanza_tope`, `balanza_impacto` (a hard landing on a pan fires the other one),
`escarabajo_lanzado` (the Rhino Beetle on its back is carried and thrown).

## History and decisions

- 0.5.71 (the user): boxes in a ROW are pushed together (a small box beside a big one blocked it like a wall), at
  `0.8 ÷` the weight of the whole row with what each carries (big alone 0.4, small 0.8, big + small 0.27; the push
  factor travels in the Box netPack so the pusher's client predicts it); bombs break boxes in their damage radius
  (`onBlastHit`; the Seed is immune); the Geyser jet became a real simulated column (see traps-and-mechanisms).
- 0.5.70 (the user): the air pushing a box against a player teleported the player to the box's far side → a box moved
  by something else SHOVES the player along (their own collision; a wall stops both). `pushAt(x, y, o)` gets WHO it
  pushes and may return a 4th value `true` (its weight already counted: no × `windK`). The Geyser lifts the first thing
  in its column slower the heavier it is with its stack, and its jet is cut at that thing's underside.
- 0.5.69 (the user, after trying it): a box made its push sound just by standing next to it → only walking TOWARD
  it pushes (`inMoveX`); the carried object a bit higher (10 px); the Geyser was slow → `pushAt` may return a third
  value, how SHARP the push is (× the rate it reaches the air speed; Geyser 10 with 1050 px/s: explosive), plus more
  foam and steam; Scale pans went through the floor → they stop on blocks, platforms and boxes (enemies pass
  through); `dropThrough` on one-way bodies lets a crouching player drop through one (supported, but the pans do NOT
  use it: the user, boxes have to be placed on them carefully). Box ↔ player collisions healed (the user: teleports,
  squashes, appearing on the other side): a box never moves INTO a player (falling it rests on their head; the air,
  pushing and the Scale stop at them), it does not respawn on an occupied spot, and a player overlapping a solid body
  steps on top when only the feet are in, otherwise leaves by the shallowest side. A ground pound while carrying keeps
  the object (the player takes the impact).

- 0.5.68 (the user): UP picks up / throws (it used to jump too — the user thought it was free; chosen: UP only
  grabs); bomb picked up unlit, lit when thrown; crouch + UP = put down carefully instead of throwing; a small box
  that can be carried and breaks depending on the impact; bomb objects respawn and light on a hard impact; the big box
  also breaks on spikes, lava and big falls, and is much heavier to push than the small one; one generic island module.
- 0.5.76 (the user): the scale's catapult is GENERAL — anything heavy landing hard on a pan fires what the other pan
  carries, by weight and speed (not only a ground pound or a boss): `Scale.impactPower` ([traps-and-mechanisms](../entities/traps-and-mechanisms.md)).
  A first threshold (500 px/s, power 0.45) made a box dropped one tile onto a pan jolt it and split a stack: raised to
  750 px/s and 0.6. The Rhino Beetle on its back is a carryable (`carryable`, thrown = it knocks enemies down and breaks
  boxes; it explodes in lava, on spikes or in the void).
