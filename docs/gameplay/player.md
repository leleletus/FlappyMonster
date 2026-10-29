# The player (`PlayerAdventure`)

One class holds the player's physics and is shared by single player, the server and the client's prediction — and by
everything that needs "a body that moves like a player": the KOTH bot, the Mirror boss's copied body, the films.

**Files** (`src/player/`)

| File | Contents |
|---|---|
| `PlayerAdventure.lua` | tuning constants, hitboxes, actions (`hurt`, `bounce`, `knockback`, `launch`, `squash`, `freeze`, `die`, `respawn`, invulnerability), the flashlight, `update(dt, level)` |
| `PlayerCollision.lua` | `moveAndCollide`: tiles, one-way platforms, solid bodies, arena walls, spikes; `moveSteps` cuts a long move into ≤ 30 px pieces (at low FPS a 75 px ground-pound step went through a 1-tile floor; 0.5.9, harness `mechanics` `pocos_fps`) |
| `PlayerAir.lua` | drowning, the countdown, splashes, the air bar; FREEZING WATER (`updateFrost`, `frostT`, the frost meter: [water-and-floods](water-and-floods.md#freezing-water-flood-prop-cold-level-key-coldwater)) |
| `PlayerGroundPound.lua` | the ground pound and being frozen in ice |
| `PlayerGulp.lua` | being SWALLOWED by a Carnivorous Plant: mashing out, the bites, the mash prompt (0.5.97) |
| `PlayerRender.lua` | sprites and drawing |
| `OnlinePlayer.lua` | draws the OTHER players from snapshot data (tint, name tag) |
| `DeadEyes.lua` | the X eyes |

The part files are loaded by `PlayerAdventure.lua` and add methods to the same class (see
[project-structure](../architecture/project-structure.md#split-files)).

**Moves:** walk, jump + double jump, crouch (and crouch jump), ground pound (crouch in the air), swimming, the
flashlight in dark levels, carrying (UP: pick up / throw; crouch + UP: put down carefully — [carry-and-push](carry-and-push.md)).
Input is read from the global `Input` (`jump`, `crouch`, `move_left`, `move_right`, `light`, `grab`); the server and
the bot feed it through a stub. Since 0.5.68 UP (arrow, W, D-pad up) is `grab` and no longer jumps (the user). The
player also rides moving bodies (`standBody`) and is dragged by the air (`windVx`, systems/Push).

**Health:** 3 HP (4 on Easy), lives belong to whoever launched the level (the story, Free Play…). One
invulnerability system (`invT`) for hits and respawns.

**When you add a field that changes physics:** add it to `Protocol.packOwnState / applyOwnState / isValidOwnState`
and bump `Protocol.VERSION`, or reconciliation desyncs. **Harnesses:** `mechanics`, `level_solve` (searches with the
real physics), `difficulty_rules`.

**Sprite:** `src/player/PlayerSprite.lua` — the monster's animations come from the set `player`, by name; the pose
number that the simulation and the network carry (`frame`: 1 glide, 2 jump, 3 idle, 5 crouch; 4 = dead) is mapped
there to its animation. Used by the player, online players, Flappy mode and both Mirror bosses.

## Fields, input and moves

- Fields: `x,y` = sprite center; `vx,vy`, `onGround`, `facing`, `frame`
  (1..3 walk/fall anim, 2 = rising/GP, 5 = crouch; dying uses monstrito4),
  `puff` (squash scale), `hp/hpMax` (3), `lives`, `invT` (invulnerability), `hurtT`
  (red flash only),
  `gpPhase` nil|'windup'|'fall', `gpLanded` (true only the step it lands),
  `stunT`, `dying/alive/deathPhase` ('freeze'→'jump'→'fall', `alive=false`
  when off-screen → caller subtracts a life and respawns).

- `update(dt, level)` reads global `Input.pressed/down` ('jump','crouch',
  'move_left','move_right'). Ground pound = press crouch in the air.

- Crouch: on the ground can't walk but CAN jump (crouch jump; the held direction
  sets vx = ±ADV_MOVE_SPD at takeoff, air control while airborne). Stays crouched
  in the air while crouch is held; `canStand(level)` = headroom for the standing
  box — without it the player is ALWAYS crouched (1-tile-high tunnels). While
  crouched `moveAndCollide` and contact hazards use the crouched boxes (feet
  anchored); no GP without headroom; no 'headBump' sound while crouched.
  `crouching` is in own-state flags (protocol v14 for the new rules).

- `bounce(vy)`, `knockback(dirX)` (GP shove + stun), `die()`, `respawn()`.

- Sounds: 'jump', 'step', 'dies2' (death), 'dies' (non-lethal hit), 'gpStart',
  'gpImpact', 'stunned', 'headBump'.

## Damage, invulnerability, health

- `hurt(n)` = n damage (default 1), returns true if it killed; otherwise grants HIT_INV
  (1.6 s) invulnerability + red flash (`hurtT`). ONE invulnerability system for every
  cause (`invT`, `grantInvulnerability(t)`, `isInvulnerable()`): no damage, no deaths
  except drowning / `die(nil, true)`, no pushes (`isPushProtected()`: knockback, recoil,
  squash; the push of the SAME hit still applies via `hitNow`), bosses' solid bodies are
  passed through, and it BLINKS (`invulnAlpha`; others see `PF_INVULN`).

Player HP: 3 (`pa.hp/hpMax`), `pa:hurt(n)` = n dmg + invulnerability + red flash; 0 → die.
Respawn grants `SPAWN_INV` (2.5 s) of the same invulnerability (`invT`, see Player).
`die()` returns false when it was blocked. `invT` is own-state index 27 and others see
it via `PF_INVULN` (protocol v21: one system for respawn and hits).
Solid bodies: `level.solidBodies` (set each step from `Entities.solidBodies`,
i.e. entities with `isSolidBody()`, e.g. active bosses) block players sideways
in `moveAndCollide` (contact by movement direction, gentle separation if they
already overlap). A body can use `solidAgainst(level)` instead (the mirror's
body collides with `level.players`). The arena wall is looked up from the
position BEFORE moving, so no push can carry anything out of a boss zone.
Online camera freezes while the local player is dying (same as single player).

## Pushes and special states

- `pa:squash(dirX)`: flattened for `squashT` (1.8 s): crouch sprite squashed to
  `SQUASH_K` (0.55) anchored at the feet, hitbox 20 px, stunned, stars at the
  flattened head, sideways hop. Own-state index 28; others see it via `PF_SQUASH`.

- `pa:launch(vx, vy)`: sideways launches set `ctrlLockT` (no input, no
  friction, NO stun/stars) instead of stunT. Own-state index 29 (protocol v12; v13 = flood entity type; v14 = crouch jump).
  Side trampoline faces trigger at any push speed; top/bottom need 120 px/s.

## Swallowed by a Carnivorous Plant

(0.5.97, the user: "the plant can eat the PLAYER too, like the beetles, and the player has to MASH all the buttons
to get out; if they don't get out in time, the plant takes 1 HP every few seconds". `src/player/PlayerGulp.lua`; the
plant: [enemies](../entities/enemies.md#carnivorous-plant-carnivoreplant-planta-carnívora--jungle).)

- `pa:swallow(bx, by, nx, ny)` (called by the plant when its snap closes on the player; `canBeSwallowed()` = not dying,
  not invulnerable, not iced, not already swallowed): `gulped = true`, the player is put just in front of the plant —
  its box touching the face of the plant's block from outside (floor: feet on it; ceiling: head; wall: side) — and stays
  there: NOT drawn (others: `PF_GULP`), no movement, no control, touches nothing (`Interactions.run` skips it, what it
  carried is dropped) and nothing hurts it but the plant (`isInvulnerable()` is true while swallowed).
- MASH (`PlayerAdventure:mashPresses`, shared with the ICE block; 0.5.98, the user: "every button, absolutely every
  one except the flashlight"): every press of jump, crouch, UP (grab), and LEFT / RIGHT when they go down (only their
  held state travels: the up → down change is counted, `mashL/mashR` travel in the own state, index 39) adds one; the
  flashlight does NOT. Plant: `gulpMash`; at `GULP_MASH` (10) it is SPAT OUT along the plant's normal (`gulpNx, gulpNy`; 640 px/s, up
  from a floor plant, sideways and up from a wall), `ctrlLockT` 0.2 s, invulnerable `GULP_FREE_INV` 1.2 s; the plant is
  left shut (`chew`: stompable).
- BITES: every `GULP_BITE` (1.75 s, `gulpBiteT`) −1 HP with the red flash and `plantCrunch`, bypassing invulnerability
  (`gulpBite`); at 0 HP a normal death (`die(false, true)`, respawn as always). Immortal bots only flash. The story's bot
  rival mashes jump by itself (`Bot:think`).
- MASH PROMPT (`PlayerAdventure.drawMashPrompt`, local player only — `AdventureState` and the online render, next to the
  grab prompt): a button pressing and releasing fast over the swallowed player (below it under a ceiling plant), the one
  of the current device: `assets/images/ui/prompts/mash-Sheet.png` (6 frames 16x16: keyboard key, pad button, touch
  button — up / down; `tools/art/ui/make_prompts.py`, does not overwrite an existing PNG). The same prompt also shows
  while frozen in an ice block (the same mashing; it had none).
- Network: own state — flag `F_GULP` (256) in s[5] and indices 35-38 (`gulpMash`, `gulpBiteT`, `gulpNx`, `gulpNy`),
  protocol v91. The server swallows (the plant lives there); the client gets it with the reconciliation and predicts the
  mashing and the bites like the ice (`iceT`). Harnesses: `mechanics planta_traga` / `planta_colgada`, `online_smoke
  LEVEL=tools/tests/online_smoke/planta.json WANTGULP=1`.

## Network

- Any NEW field that affects physics must be added to
  `Protocol.packOwnState/applyOwnState/isValidOwnState` (and VERSION bumped),
  otherwise reconciliation desyncs.

## The white edge (visibility of the almost-black monster)

- **WHITE EDGE of the monster (3.68.6)**: `src/fx/Silhouette.lua` — the monster's own sprite, fully white, drawn
  BEHIND it shifted to the 8 sides by `Silhouette.WIDTH` (1/3 of an art pixel = 2 px at scale 6): an even thin white
  edge. HISTORY: a blue 4-offset rim (3.68.2) → the user's idea "same sprite scaled up, white, behind" (looked
  MISPLACED: on such a thin figure uniform scaling moves arms, legs and antennae away from the body by different
  amounts — don't scale) → offset copies at 1 art px ("much too thick") → 1/3. One helper for every place where the
  almost-black monster was lost: the cinematics (`Stage.monster` inside a set / `o.outline`), the results screen, and
  the LEVELS that are dark, at night, caves or under the surface line of a level with a depth (`Silhouette.on(level,
  y)`). PER CHARACTER (3.69.1): the states only say WHICH LEVEL is being drawn (`PlayerAdventure.lightLevel`) and each
  `PlayerAdventure` / `OnlinePlayer` (other players, the KOTH bot) asks `Silhouette.on(level, ITS y)` — it used to be
  one yes/no set from the local player's position, so standing in the dark lit everybody's edge. Nothing to send
  online: it is a pure function of the level and that character's position, which every client already has.
  Render only; drawn before the darkness, so it dims with the scene. Harness `mechanics filo_propio`.
