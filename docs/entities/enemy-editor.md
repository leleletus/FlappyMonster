# The enemy editor and data-driven enemies

An enemy can be made **without writing code**: its definition is a JSON file edited visually, its art is an
[animation set](../art/animation.md), and its behaviour is assembled from a catalog of pluggable pieces. Such an
enemy registers like any other entity type: it appears in the level editor with all the common props and works in
single player, on the server and online.

```
love . --enemy [id]       open (or create) an enemy
```

**Files**

| File | Role |
|---|---|
| `src/editor/EnemyEditor.lua` | the tool |
| `src/editor/AnimPanel.lua` | the animation editor embedded in its "Animaciones" tab |
| `src/world/entities/base/DataEnemy.lua` | the generic class: builds a type from the data, runs behaviours, health, projectiles, drawing, network |
| `src/world/entities/behaviors/Behaviors.lua` + one file per behaviour | the behaviour catalog |
| `assets/enemies/index.json` | the list of data enemies (palette order); `assets/enemies/<id>.json` = one enemy |
| `assets/anim/<id>.json` | its animation set |

## The editor, step by step

The tabs are numbered in the order you work; a line under them says what the current step is for.

1. **Dibujos** — the full animation editor on the enemy's set: its frames and its animations. A yellow note lists
   the animations its states still need, with a button to create them.
2. **Cómo es** — *Enemigo normal* or **JEFE**; label, description, category; scale, "art faces left", breathing
   when idle, a light outline for dark sprites; the hit boxes drawn live over the sprite (orange = where it is
   touched / stomped, yellow = where it hurts); health; **how it moves** (walks, flies, stands still, or CRAWLS on
   walls and ceilings); the default values of the common props, which each level can still override; traits.
3. **Qué hace** — add, order and tune behaviours. With none, it just moves. When several could take over, the one
   higher in the list wins.
4. **Estados** — which animation each state shows (usually nothing to change: a state shows the animation with
   its own name).
5. **Avisos** — what is missing.

Top right: **Deshacer** (Ctrl+Z; Ctrl+Y redoes — everything, including the animation editor), **Guardar** (Ctrl+S),
**Probar** (F5: saves and drops the enemy into a test room inside the real game, F10 returns; a boss gets an arena
with its boss zone) and **Borrar** (asks first; refuses while any level places the enemy; its drawings in
`assets/images` are never deleted).

**Starting from drawings:** if `assets/images/enemies/<id>/` already has PNGs when you create enemy `<id>`, they are
taken as frames and sorted into animations by file name (`…idle…` → idle, `…dead…` / `…muert…` → dead, `…hurt…`,
`…attack…` / `…ataque…`, `…run…`, `…special…`, `…shot…`; everything else → walk).

## Behaviours available

| Id | Label | State | What it does | Main parameters |
|---|---|---|---|---|
| `chase` | Perseguir | `run` | sees a player nearby (no wall between) and runs at it; gives up after a while | range, height, speed ×, give-up time, careful at edges |
| `melee` | Ataque | `attack` | wind-up → a hit box in front that takes HP (optionally lunging) → rest → cooldown | range, wind-up, active, rest, reach, lunge, damage, cooldown |
| `leap` | Salto (acción especial) | `special` | every so often crouches and jumps in an arc at the player | range, every, wind-up, height, max distance |
| `shoot` | Disparo | `attack` | wind-up, then a straight projectile that takes HP and stops at walls; drawn with the set's `shot` sequence | range, wind-up, rest, speed, life, size, damage, cooldown |
| `hide` | Esconderse | `hide` | every so often (or when a player is near) hides for a while and comes back out: hidden it cannot be stomped or touched, and can show a cover that hurts or kills from above (like the Crabby's spike). Animations `hide`, `hidden`, `unhide` (missing ones fall back to `hide`, reversed for coming out). Works for crawlers too | every, near, in / stay / out times, cover |

Detection ranges are scaled by the difficulty's `sense`; the whole enemy is scaled by `enemyPace` like any other.

## Adding a behaviour (one file + one name)

Create `src/world/entities/behaviors/<name>.lua` returning
`{ name, label, description, states = {…}, params = {…}, think = fn, update = fn, hazards = fn }` and add its name to
`TYPES` in `Behaviors.lua` (the recipe is at the top of that file). It then appears in the editor with its
parameters. Rules: `think(e, cfg, dt, level)` runs while the enemy is in `walk` / `idle` and returns true after
calling `e:enter(state)` to take over; `update` runs each step while the enemy is in one of its states and ends with
`e:backToWalk()`; the time in a state is `e.deadTimer`; no drawing code and no state that drawing needs but the
network does not carry. Helpers on the enemy: `e:seesPlayer(level, tiles, height)`, `e:nearestPlayer(level)`,
`e:addShot(x, y, vx, vy, life, size, dmg)`, plus everything in `Entity` (`moveAndCollide`, `groundAhead`, `canGo`…).

## How it runs

- **Registration:** `Entities.lua` calls `DataEnemy.registerAll` after the Lua types; each id in `index.json` becomes
  a type (`DataEnemy.typeDef`): its own class, hit boxes, walk cycle from the set's `walk` sequence. A broken file
  is reported and skipped, never fatal.
- **Simulation** (single player and server): `DataEnemy:updateCustom` → cooldowns → `hurt` → the behaviour that owns
  the current state → otherwise each behaviour's `think` in order → otherwise the base walk / idle of `Entity`.
- **Client:** draws from `state` + `deadTimer` (+ `frame` for walking, `breatheT` for idle), which already travel;
  `netPack` adds health and projectiles (with stable ids for interpolation).
- **Player rules:** the defaults of `Interactions` (touch by `onTouch`, stomp, ground pound); behaviours add hazard
  boxes (`effect = 'hurt'`). With `hp` > 1 a stomp takes 1 and the enemy is untouchable while `hurt`.

## Crawlers

"TREPA" (`"crawl": true`, movement = walk) makes the enemy walk glued to floor, walls and ceiling, turning at
corners, with the same code as the wall-walking Crabby (`base/Crawler.lua`): rotated hit boxes, stomp from its open
side, it lets go when shoved and re-attaches on landing. While crawling only behaviours marked `crawlOk` run
(`hide`): the others need floor physics.

## Bosses

Switching "Qué es" to **JEFE** adds a `"boss"` block and the type is built by `src/world/entities/base/DataBoss.lua`
on top of the boss base class: health bar and zone, cinematic intro (it drops from the top of the zone), death with
explosions, turns with an ally on Xtra Extreme, network. Place it inside a boss zone in the level editor like any
boss.

- **Between attacks** it walks toward the nearest player at `walkSpeed` (animation `walk`).
- **Attacks** are the same behaviour pieces (melee, leap, shoot, hide…), tried in order every `attackEvery` seconds.
- **When it can be hit:** `vulnerable = "tired"` (default) — after each attack it is `tired` for `tiredTime`
  seconds, with the usual stun stars: stomp 1, ground pound 2, one hit per opening; otherwise landing on it bounces
  you off. `"always"` = any time.
- **Phase 2** below `rageAt` of its health: everything runs `ragePace` times faster.
- Touching it from the side takes `contact` HP and pushes.
- States: `dormant`, `intro`, `ready`, `fight`, its behaviours' states, `tired`, `dying_*`. Animations used: `idle`,
  `walk`, `tired` (or `hurt`), `dead` + those of its behaviours.

What a data boss cannot do (write a Lua boss, [how-to-add-a-boss](../bosses/how-to-add-a-boss.md), or add a
behaviour): minions, arena-specific mechanics, computed poses, more than two phases, its own death sequence. Its
name in the bar comes from its `title` / `title_en` (no language-file entry needed).

## Rules and limits

- **A NEW enemy is a new entity type.** Before it reaches players: add it (it is in `index.json` once saved), bump
  `Protocol.VERSION` and `version.txt`, run `tools/tests/run.sh docs_reference` and the battery. Ids are permanent
  once a level uses them.
- The id must not collide with an existing type; the editor refuses.
- Removing an enemy: the **Borrar** button (it checks that no level places it).
- What this system does NOT cover (write a Lua type instead, see
  [how-to-add-an-enemy](how-to-add-an-enemy.md)): dropping from ceilings on sight, covers that become trampolines,
  custom per-frame poses. New kinds of action are best added as a behaviour so every data enemy can use them.

**Tests:** `enemy_data` (registration, each behaviour, health, crawling, hiding, a whole boss fight, network,
validation, the index), `tool_editors TOOL=enemy` and `TOOL=enemy KIND=boss` (the real editor end to end, undo,
the play-test). Not covered: a data enemy in an online match with
a real server (none ships yet) — run `online_smoke LEVEL=<a level that places it> WATCH=<id>` with the first one.
