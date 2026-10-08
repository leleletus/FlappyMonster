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

## The editor, tab by tab

- **General** — label, description, category; scale, "art faces left", breathing when idle, a light outline for dark
  sprites; the hit boxes as fractions of the sprite, drawn live over it (orange = where it is touched / stomped,
  yellow = where it hurts); health (`hp` > 1 adds the `hurt` state); the default values of the common props (movement
  walk / fly / static, speed, what touching does, stompable, points, pauses, respawn…), which each level can still
  override; traits (needs a ground pound, drawn in front, stays in place when frozen).
- **Animaciones** — the full animation editor on the enemy's set, with a "create the missing ones" button for the
  sequences its states ask for.
- **Estados** — which sequence each STATE shows. Base states: `idle`, `walk`, `hurt`, `dead`; the rest come from its
  behaviours (`run`, `attack`, `special`…). A missing sequence falls back to the set's fallback.
- **Comportamientos** — add, order and tune behaviours. With none, the enemy just walks / flies / stands as its
  movement says. When several could take over, the one higher in the list wins.
- **Avisos** — what is missing.
- **Probar (F5)** — saves and drops the enemy into a test room inside the real game; F10 returns.

**Starting from drawings:** if `assets/images/enemies/<id>/` already has PNGs when you create enemy `<id>`, they are
taken as frames and sorted into sequences by file name (`…idle…` → idle, `…dead…` / `…muert…` → dead, `…hurt…`,
`…attack…` / `…ataque…`, `…run…`, `…special…`, `…shot…`; everything else → walk).

## Behaviours available

| Id | Label | State | What it does | Main parameters |
|---|---|---|---|---|
| `chase` | Perseguir | `run` | sees a player nearby (no wall between) and runs at it; gives up after a while | range, height, speed ×, give-up time, careful at edges |
| `melee` | Ataque | `attack` | wind-up → a hit box in front that takes HP (optionally lunging) → rest → cooldown | range, wind-up, active, rest, reach, lunge, damage, cooldown |
| `leap` | Salto (acción especial) | `special` | every so often crouches and jumps in an arc at the player | range, every, wind-up, height, max distance |
| `shoot` | Disparo | `attack` | wind-up, then a straight projectile that takes HP and stops at walls; drawn with the set's `shot` sequence | range, wind-up, rest, speed, life, size, damage, cooldown |

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

## Rules and limits

- **A NEW enemy is a new entity type.** Before it reaches players: add it (it is in `index.json` once saved), bump
  `Protocol.VERSION` and `version.txt`, run `tools/tests/run.sh docs_reference` and the battery. Ids are permanent
  once a level uses them.
- The id must not collide with an existing type; the editor refuses.
- Removing an enemy = delete its line from `index.json` (and its files) after making sure no level places it.
- What this system does NOT cover (write a Lua type instead, see
  [how-to-add-an-enemy](how-to-add-an-enemy.md)): wall crawling, hiding, custom per-frame poses, boss logic. New
  kinds of action are best added as a behaviour so every data enemy can use them.

**Tests:** `enemy_data` (registration, each behaviour, health, network, validation, the index), `tool_editors
TOOL=enemy` (the real editor end to end, including the play-test). Not covered: a data enemy in an online match with
a real server (none ships yet) — run `online_smoke LEVEL=<a level that places it> WATCH=<id>` with the first one.
