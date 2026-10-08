# How to add an enemy (or any entity) without touching the engine

> **First check the visual route:** an enemy that walks / flies, chases, attacks, leaps or shoots can be made
> entirely in the [enemy editor](enemy-editor.md), with no Lua. Write a type by hand (this page) when it needs
> something the behaviour catalog cannot express — or add that as a new behaviour.

A new enemy is **one file** in `src/world/entities/types/<category>/<name>.lua` plus **its name** in the `TYPES`
list of `src/world/entities/Entities.lua` (as `'<category>/<name>'`; categories: `enemies`, `bosses`, `traps`,
`mechanisms`, `items`, `directors`). The editor, the server and the client pick it up by themselves.

Everything that is "base behaviour" (moving, colliding, dying, making noise, being a minion…) already exists: the type
only **switches it on** with a trait or a table. If your enemy needs a change in `Entity.lua`, `Interactions.lua`,
`Level.lua`…, a base rule is missing: add it there, generic, and switch it on from the type. Never copy code from
another enemy.

For a BOSS also follow [how-to-add-a-boss](../bosses/how-to-add-a-boss.md).

## 1. The skeleton

```lua
local Entity = require 'src/world/entities/base/Entity'
local Bug = Entity.extend(Entity, {
    hitbox = { outerW = 0.8, outerH = 0.9, innerW = 0.6, innerH = 0.7 },   -- × the sprite size
})
function Bug.loadAssets() ... end          -- images (files in assets/, never drawn by code)
function Bug.sizePx() return 64, 64 end    -- or sizeImage()
function Bug:init() ... end
function Bug:updateCustom(dt, level) ... return true end   -- true = "I moved myself"
function Bug:render(camX, camY) ... end

return {
    name = 'bug', label = 'Bicho', category = 'Enemigos', class = Bug,
    description = 'What the editor palette shows (Spanish: the editor is in Spanish)',
    defaults = { speed = 70, points = 15 },
    props = { ... },                          -- editable properties (entities/base/Props.lua)
    editor = { sprite = 'assets/images/enemies/bug/idle.png' },
}
```

## 2. What the type definition switches on (no code)

| Type field | What it does | Where the rule lives |
|---|---|---|
| `traits = { ... }` | Traits (table below): copied onto every instance | `Entity.create` |
| `noises = { mySound = tiles }` | That sound of its own is also NOISE the Gloomies hear (and a distraction) | `Noise.SOUNDS`, `EntityTypes.register` |
| `noise = tiles` | (pickups) how loud picking it up is | `Interactions.run` |
| `pickup = { score, lives, heal }` / `checkpoint = true` | It is collected / it is a checkpoint | `Interactions` (`pickupEffect`) |
| `summons = function(placement) ... end` | RESERVE placements the level creates for it (minions) | `Level.fromData` |
| `activatable = true` | Can be linked to an ON/OFF Activator (prop `id`) | `Level:signal`, editor |
| `category`, `description`, `variant`, `hide`, `placement`, `ceilingOnly` | Editor: palette, inspector, placement | `EntityTypes`, editor |
| `boss = { title }` | It is a boss (bars, zone) | `Boss.lua`, `BossZones` |
| `pace = false` / `pace = '<modifier>'` | Opt out of / choose the difficulty time scale | `Difficulty.dt` |

### Traits (`traits`, or a class field when it applies to the whole type)

| Trait | Effect |
|---|---|
| `needsPound = true` | TOUGH: a normal stomp bounces; only a ground pound kills it. Touching it from above never hurts (unless `hurtsFromAbove()` says so: its own attack) |
| `diesWithBlock = true / false` | Dies (flung) when the block it stands on / grips breaks. Default: category Enemigos yes |
| `solidFull = true` | Solid like a block (sides, top, head bump). Needs `isSolidBody()` |
| `renderFront = true` | Drawn in front of the players |
| `wantsLevel = true` | Gets `levelRef` when the level loads (to draw according to the terrain) |
| `freezeFloats = true` | Frozen, it stays where it is (does not fall) |
| `darkEdge = { r, g, b, a }` | Dark sprite: draws a thin outline of that colour around it where the level is dark |

(Classes share `def` when one file returns several definitions with the same class: traits that differ per definition
do not work there; use subclasses.)

Class fields that are also generic switches: `artScale` (pixel scale of the sprite, default `GUMMY_SCALE`), and for
Gummies `artDir`, `helmetDx`, `helmetDy`.

## 3. What is inherited (hooks of `Entity`, all with a default)

- Movement: `props.movement` = walk / fly / static; routes (`patrol`), edges, pauses, free flight
  (`flyMode = 'free'`, `entities/base/FreeFlight.lua`). Walkers turn round at another entity (`isObstacle()`), spikes
  and edges; boxed in, they stay idle.
- CRAWLER (floor ↔ walls ↔ ceiling): `Crawler.mixin(Class)` gives the rotated boxes, the normal for the stomp,
  letting go and not falling while attached; move it with `Crawler.move(self, level, px)` and ask
  `Crawler.entityAhead(self, level)` so it does not walk through others.
- Player ↔ entity: the normal rules are in `Interactions.defaultCheck` (stomp, contact by `props.onTouch`, hazard
  boxes `getHazardBoxes()` with `effect = 'hurt' | 'freeze'`…). Own rules: `interact(pa)` (side-effect free: the
  client uses it to predict) and the notifications `onStomp`, `onBounced`, `onHurtPlayer`, `onLaunch`,
  `onHelmetBounce`.
- Deaths: `stomp()`, `dieFling(dir)`, `dieBurst()`, respawn (`props.respawn`).
- Freezing (`canFreeze`), being launched by trampolines (`canBeLaunched`), the ground-pound shove (`knockback`).
- Reserve MINION: any entity can be one (`Entity:makeReserve`; hook `onMakeReserve`).
- Network: `netPack()` / `netApply(a, b, f)` for its own data; `netAtRest()` / `netRest()` so it is not sent while
  it sits in its usual state.
- What shows in the dark: `renderGlow(camX, camY)`; what gives light: `lights()`.
- Hit areas that are not the standard boxes: `debugBoxes()` (so F1 shows them).
- Sounds: `Sound.play('name')` from its update is already attenuated by distance and, if listed in `noises`, is noise.

## 4. Other pieces that are "one file + one name"

- Tiles: `src/world/tiles/types/` (recipe in `Tiles.lua`). Decorations: `src/world/decorations/types/` (with
  `light = { r, color, a, dy }` they give a faint light in dark levels). Modes: `src/world/modes/`.
- Sounds: a file in `assets/sounds/<group>/` + one `load(...)` line in `src/audio/Sound.lua` (and its generator in
  `tools/sounds/`). Folders: `player/`, `enemies/<enemy>/` (shared: `enemies/common/`), `bosses/<boss>/`, `items/`,
  `mechanics/`, `traps/`, `water/`, `ambience/`, `jingles/`, `ui/`.
- Images: `assets/images/enemies/<enemy>/`, lower case; bosses in `assets/images/bosses/<boss>/`; what bosses share
  (stun stars, anger symbols, target mark) in `assets/images/bosses/common/`, drawn with `src/fx/BossFx.lua`.

## 5. Before handing it over

- Harness: a case in an existing `tools/tests/` harness (or a new one) + its row in `tools/tests/README.md`;
  `tools/tests/run.sh all`.
- `tools/tests/run.sh docs_reference` (regenerates the entity table) and a paragraph in
  [enemies](enemies.md) (or the matching doc).
- If what travels over the network or the rules with the player change: `Protocol.VERSION` and `version.txt`.
