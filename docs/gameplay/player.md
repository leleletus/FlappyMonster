# The player (`PlayerAdventure`)

One class holds the player's physics and is shared by single player, the server and the client's prediction — and by
everything that needs "a body that moves like a player": the KOTH bot, the Mirror boss's copied body, the films.

**Files** (`src/player/`)

| File | Contents |
|---|---|
| `PlayerAdventure.lua` | tuning constants, hitboxes, actions (`hurt`, `bounce`, `knockback`, `launch`, `squash`, `freeze`, `die`, `respawn`, invulnerability), the flashlight, `update(dt, level)` |
| `PlayerCollision.lua` | `moveAndCollide`: tiles, one-way platforms, solid bodies, arena walls, spikes, low steps ([below](#low-steps-step-up)); `moveSteps` cuts a long move into ≤ 30 px pieces (at low FPS a 75 px ground-pound step went through a 1-tile floor; 0.5.9, harness `mechanics` `pocos_fps`) |
| `PlayerAir.lua` | drowning, the countdown, splashes, the air bar; FREEZING WATER (`updateFrost`, `frostT`, the frost meter: [water-and-floods](water-and-floods.md#freezing-water-flood-prop-cold-level-key-coldwater)) |
| `PlayerGroundPound.lua` | the ground pound and being frozen in ice |
| `PlayerGulp.lua` | being SWALLOWED by a Carnivorous Plant: mashing out, the bites, the mash prompt (0.5.97) |
| `PlayerFlight.lua` | FLIGHT in Flappy levels ([below](#flight-flappy-levels)) |
| `PlayerRender.lua` | sprites and drawing |
| `OnlinePlayer.lua` | draws the OTHER players from snapshot data (tint, name tag) |
| `DeadEyes.lua` | the X eyes |

The part files are loaded by `PlayerAdventure.lua` and add methods to the same class (see
[project-structure](../architecture/project-structure.md#split-files)).

**Moves:** walk, jump + double jump, crouch (and crouch jump), ground pound (crouch in the air), swimming, the
flashlight in dark levels, carrying (UP: pick up / throw; crouch + UP: put down carefully — [carry-and-push](carry-and-push.md)).
**Action poses** (0.5.190; designed by an art agent from the user's frames and the rhythm-duel poses, every one
approved by the user — `tools/art/player/make_monster_actions.py` → `assets/images/player/actions/`, anims `act_*` in
`assets/anim/player.json`): the pose NUMBER (`frame`, it travels online) 6 hard landing, 7 free (it was a curled ground-pound sprite; the user removed it, the ground pound shows the classic jump frame 2), 8 throw, 9 push, 10 look
up (UP held standing still 0.6 s), 11 crouched looking down (DOWN held crouched 0.6 s, the camera look), 12 long idle
(5 s still: blink, antennae), 13 victory (on winning the level). Built and then removed in play (the user: "it does
not quite work"): skid, hurt. Chosen by priority at the end of `PlayerAdventure:update`
(`actionPose`); drawing only. Walking and running keep the idle / jump frames (the user: part of its essence); the
ledge pose and the swim / carry / double-jump ones were rejected. **Eyes** are separate overlay sprites
(`assets/images/player/actions/eyes/`: normal, blink, happy — the Mirror's laugh eyes, same size and gap —,
sparkle), drawn by `PlayerSprite.draw` at half a sprite pixel from each frame's `eye`, `ex`, `ey`, `esep`, SYMMETRIC by
construction (the right eye is the mirror image of the left around the pair's centre, in screen pixels: rounding each
one apart had shifted the `^ ^` a quarter pixel — the user saw it). One-shot anims start from their first frame
(`PlayerSprite.recOf`: the time since that object's pose changed). Cutscene actors keep the basic poses
(`basicPoses`). Online: remote players see what the server's simulation picks; look up shows only on your own screen
(the held UP is not in the input bits). Harness `mechanics poses` (`LOOK=1` → `<save>/poses.png`, every frame drawn
by the game).

**Hard landing** (0.5.193): landing faster than `LAND_HARD_VY` 1000 px/s (about 4.9 tiles of fall; a double jump from the same floor lands at about 800) shows pose 6, stops the monster for its 0.28 s (`landStopT`, own state: no walking, no jumping) and plays `landHard`, louder and deeper the higher the fall (`tools/sounds/land.py`). Bots and actors (`moveK`) don't stop. The user: it used to fire even after a double jump.

**Walking and running** (0.5.190; the user: "by default a bit slower, and with a button it runs, a bit faster than
now"; testers complained it could not run): walking `ADV_MOVE_SPD × PlayerAdventure.WALK_K` (0.9 → 216 px/s), holding
RUN `× RUN_K` (1.11 → 266 px/s; the user asked for 1.1 and then "1 % more"), on the ground and in the air (also the crouch jump's take-off); running on the ground leaves `run_dust` behind the feet (2-3 motes every 0.06 s at 70 % opacity; made bigger after the user's first try, "I don't notice it"; drawing only). Harness `mechanics polvo_correr`. No new animation: it
keeps moving with its idle / jump frames (the user: that is part of its essence). Buttons: Shift (both) on keyboard
(the flashlight is F only now), the controller's top face button (Nintendo **[X]**, Xbox / SDL `y`; the flashlight keeps
SDL `x`, Nintendo [Y]), on touch a held button left of the jump button (not in Flappy levels:
`TouchControls.update(active, extra, run)`; art `tools/art/ui/make_run_button.py` → `ui/touch/run-Sheet.png`).
Online: input bit `IN_RUN` = 256 (held, inside `IN_HELD_MASK`; `IN_MAX` 511, protocol 115). **Speed override**
`pa.moveK` (a fixed factor, no running): the bots (menu demo, bonus, the planner's simulations — their moves and the
saved graphs `assets/nav/` were made at 240 —), cutscene actors (choreographed at 240) and the Mirror (its own speed
multiplier was tuned on 240) keep exactly 240. Harness `level_solve` runs by default (`WALK=1`: walking); see the
history below for which levels need running.

**Game feel (0.5.188, the user approved the round in [gamefeel-round-2026-11](../design/gamefeel-round-2026-11.md)):**
- **Variable jump height:** releasing JUMP while rising cuts the jump to `JUMP_CUT` (0.45) × its take-off speed
  (held 1.5 tiles, released after 4 frames 0.8). Only when the button was SEEN held after the jump
  (`jumpHeldSeen`): what only "presses" (cutscene actors, bots that press for a frame) jumps in full as before. Online
  the held bit already travels in the input; `jumpV0` / `jumpHeldSeen` are own-state indices 43-44 (protocol 114).
- **Corner correction:** rising, if only one edge of the head would hit a ceiling corner and the centre is free, the
  player slides up to `CORNER_PX` (12) sideways and keeps rising (`cornerNudge` in `PlayerCollision.lua`).
- **Coyote time: not needed.** Walking off a ledge keeps both jumps (`jumpsLeft` is only reset on the ground, falling
  does not spend it), so a late jump already works.
- **Landing / skid:** landing faster than `LAND_DUST_VY` (420 px/s) raises `land_dust` (the floor's colour); faster
  than `LAND_SQ_VY` (650) a short squash (`landSq`, 0.16 s, feet kept on the ground: `PlayerRender`); turning round at
  speed on the ground, `skid_dust`. Drawing only.
- **Camera lead:** running, the camera moves `CameraLook.LEAD` (0.1 × the screen width) ahead in the running
  direction and eases back when stopped (`CameraLook.lead`, single player and online; not in boss zones, Flappy levels,
  the menu demo).
- **Rumble:** see `src/core/Rumble.lua` — the controller vibrates on the player's ground-pound landing, on damage and
  with every screen shake (explosions, boss stomps, roars; the same distance fall-off as the shake); a phone without
  a controller vibrates for the strong ones. Option Settings → VIBRATION (on by default, `Settings.rumble`).
- **Hit-stop** (`src/ui/HitStop.lua`): ONLY WHEN DYING — the game freezes `HitStop.DEATH` (5) frames, music and
  sound keep playing. Single player: `AdventureState:update` does not advance; online it is visual only, on your own
  screen (the camera stays put and `SceneLayers.draw(..., reuse)` shows the previous frame's scene), nothing in the
  simulation changes. `COOLDOWN` 0.15 s between two. Option Settings → HIT-STOP (`Settings.hitStop`). History: 0.5.188
  also froze on ground pounds (enemy or ground), boss hits and damage; the user (2026-11-10): "it does not convince me
  on ground pounds, better only on dying. Nothing else" → 0.5.189.
- Bots and the credits fight hold JUMP through the whole rise (`Bot.holdJump`): their moves and the saved navigation
  graphs (`assets/nav/`) were recorded when the hold length did not matter, so their jumps stay exactly as before.
- Harness `mechanics` `salto_variable`, `esquina`, `mirar`, `hitstop`. Not judged by a person: every number above (feel).

**Looking up / down** (0.5.187, the user: "a player does not know what is above or below a blind jump; like Sonic 1,
holding crouch a while moves the camera down A LITTLE, without overdoing it; the same with up"): standing still on the
ground and holding CROUCH (or UP, the `grab` action) for `CameraLook.HOLD` (0.6 s), the camera glides
`CameraLook.LOOK` (0.28 × the screen height, ~200 px at 720) that way and glides back on release or on moving
(`src/ui/CameraLook.lua`, camera only — nothing in the simulation). The same in single player
(`AdventureState:updateCamera`) and online (the client's own predicted player). Off in the menu demo, Flappy levels
and boss zones (the camera is the zone there); not while walking, in the air, stunned, swallowed or frozen. On a
one-way platform holding down drops through it, as before. Harness `mechanics mirar`. Not judged by a person: the
distance and the wait.
Input is read from the global `Input` (`jump`, `crouch`, `move_left`, `move_right`, `light`, `grab`); the server and
the bot feed it through a stub. Since 0.5.68 UP (arrow, W, D-pad up) is `grab` and no longer jumps (the user). The
player also rides moving bodies (`standBody`) and is dragged by the air (`windVx`, systems/Push).

**Health:** 3 HP (4 on Easy), lives belong to whoever launched the level (the story, Free Play…). One
invulnerability system (`invT`) for hits and respawns.

**When you add a field that changes physics:** add it to `Protocol.packOwnState / applyOwnState / isValidOwnState`
and bump `Protocol.VERSION`, or reconciliation desyncs. **Harnesses:** `mechanics`, `step_rules`, `level_solve`
(searches with the real physics), `difficulty_rules`.

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
  'move_left','move_right'). Ground pound = press crouch in the air. Its impact crushes what is right under the feet and pushes only what is ON
  THE GROUND within 1.5 tiles of the epicentre, enemies and other players alike (`Interactions.poundReaches`; the user,
  2026-11-02: it was 170 x 110 px, airborne ones included, "es enorme"). The Mirror's copied pound and the chaser's dive
  wave use the same rule. Jump buffer: jump pressed in the air with no jumps left is remembered 0.1 s and fires on landing
  (`JUMP_BUFFER`, in the own state online; needs a person to judge the feel).

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

**Damage sources (0.5.205, [design](../design/damage-sources.md)).** `hurt(n, src)`, `die(drown, force, src)` and
`hazardHit(src)` take where the hit came from: `src = { what, part }` (`src/player/DamageSource.lua`): `what` = an entity
type, a tile (`danger` = lava) or a cause (`spikes`, `drown`, `time`, `crush`, `explosion`, `fall`); `part` = `body`,
`spike`, `projectile`, `claw`, `bite`, `dash`, `slam`, `pound`, `wave`, `ice`, `fire`, `shock`, `beam`… A hit that lands
leaves it in `pa.lastHit` (a shield or invulnerability keeps the previous one; `respawn` clears it). The shared contact
rule (`Interactions.run`) builds it from the entity and the touched hazard box's `part` (or `body`); tiles, causes and
every direct call pass theirs (a `mechanics` check scans the code: no `:hurt(` / `:die(` / `:hazardHit(` without one).
`src/player/DeathCause.lua` reads `lastHit` first ("Te derrotó: Proyectil de Pez globo", `death.part` +
`part.<part>`), and only guesses from the surroundings when there is none. Online it travels in the own state (index 46,
protocol 119).
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

## Low steps (step-up)

The user (2026-10-29): "cuando en frente tenga un escalón menor a cierta altura, podrá pasarlo sin necesidad de saltar
(es una mecánica típica de muchos juegos)". Stepping off a cable car cabin onto its station needed a small hop: the deck
sits 4 px below the station floor.

- **Rule:** on the ground and moving sideways (walking, but also carried by a deck, a conveyor or the wind) into
  something solid whose top is at most `PlayerAdventure.STEP_MAX` (**16 px**) above the feet, with room for the
  standing box at the new height, the player is lifted onto it — same speed, no jump. Tiles (solid and one-way, mini
  blocks included) and solid bodies (`solidFull`: boxes, decks, pans, sleds…) count. A solid thing higher than that is a
  wall (stops as before); a one-way one higher than that is passed through as before.
- **Why 16:** tile tops are on a 32 px grid (mini blocks are 32 px), so no step made of tiles changes — a mini block
  and a full tile still need a jump, a mini-block staircase is still a staircase, the solver (tiles only) gives the same
  results. It only covers off-grid seams between moving bodies and the ground (the cable car deck: 4 px). ≈ 1/5 of the
  monster's box (75 px). NOT covered on purpose: a Scale plank resting on the floor (24 px) and an empty floating Iceberg
  (≈ 19 px over the water): they keep their hop / push. Raising it to 24 would make those walkable, and walking into a
  low Iceberg from the shore would climb it instead of pushing it.
- **Not** while airborne or rising (`vy < 0`), crouching, in water, dropping through a platform, ground-pounding, in an
  ice block (`iceT`), swallowed, or frozen at a boss intro (`canStepUp()`). The body being ridden (`rideBody`) does not
  count as a step (it moves the rider itself).
- **Smooth:** the lift happens once the leading edge is `STEP_FOOT` (4 px) over the step — the landing probes are
  inset 4 px, so lifting earlier made the player drop back. Until then the step does not block (the box overlaps its
  corner by < 4 px). The sprite is drawn `stepVis` px lower and catches up at `STEP_EASE` 320 px/s (16 px in 3 frames);
  render only (`Predictor` keeps it out of the re-simulation: `VISUAL_FIELDS`).
- When both a tile and a body (or two bodies) hold the feet, the HIGHEST wins — before, riding a deck 4 px below its
  station pulled the player back down onto it.
- **Code:** `src/world/level/StepUp.lua` — `StepUp.lift(level, x0, x1, head, foot, dir, maxH, bodies, back, skipA,
  skipB)` → `lift, face` (a box already moved sideways; generic: any walker could use it; enemies don't yet).
- **Network:** a pure function of state that already travels (position, `onGround`, `vy`, crouch, water, GP, ice…);
  no new own-state field, but it changes predicted physics: it needs `Protocol.VERSION` + 1 and `version.txt` at the
  next release.
- **Harness:** `step_rules` (heights 4/8/16 vs 20/24/32, bodies, tiles, head room, the real cable car, the Scale, the
  excluded states, client prediction parity).
- History: 2026-10-29 first version (agent). No user verdict yet on the feel (threshold, the 3-frame ease).

## Swallowed by a Carnivorous Plant

The Triple Strike Scorpion's pincer catches the same way (`swallow(..., kind)`, `gulpKind` = 1: its sounds; in the own state, index 41), but the player is still drawn.

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

## Flight (Flappy levels)

0.5.164, step 2 of [flappy-prequel](../design/flappy-prequel.md). In a level with `"flappy": true` the player FLIES
(`pa.flight`, set from the level in `update` like `peaceful`; `PlayerFlight.lua`, called from `_update` before the
ground pound):
- JUMP flaps: `vy = FLY_FLAP` (-450) with its own `FLY_GRAVITY` (1350), any number of times; falls at most 900 px/s.
  No crouch, ground pound, carrying or double jump.
- Left / right at will: on screen `FLY_SPD` (330 px/s) forward and `FLY_SPD` + the window's speed backward (530 at
  200 px/s), so going back covers on screen what going forward covers in the world. With the level's auto-scroll running the
  monster moves WITH the window (like a scrolling shooter): no input = it keeps its place on screen. The right wall is
  the window's (AutoScroll arena); the left edge carries it along (if a block is in the way, AutoScroll's usual rule —
  left behind = dies — applies).
- PILLARS (tile `pillar`) are not solid: touching one costs 1 HP and the hit's invulnerability lets it fly through.
- NO FLOOR (Plan 5d): a Flappy level has nothing solid below it (`Level.openBottom` = `flappy`: `getRaw` returns air
  under the last row). Falling through the level's BOTTOM EDGE
  costs 1 HP through the normal `hurt` (then invulnerable: never a chain) and bounces it back up into the level
  (`EDGE_HOP` -560). The trigger is NOT the level edge but what the screen shows (user, 2026-11-08, "more margin"):
  the player sinks until only the top of its head (antennae + crown, `EDGE_SHOW_PX` = 3 art px) is still visible above the
  bottom of the screen. The screen is taller than the level (720 vs 704), so the visible bottom is
  `max(heightPx, WINDOW_H)`; the centre is held at `PlayerAdventure.flightEdgeDepth(level)` = visible bottom - 3 art px +
  half a sprite = `heightPx` + 46 px in the standard view (it stays inside a boss zone that reaches the bottom). Tests:
  `flappy_flight fondo`, `netcopter_rules fondo_pelea`. Landing on anything SOLID (a
  net-launcher's `mount`, a tunnel's floor) does the same. Ceiling and walls only stop it.
- NO CONTROL (Plan 5d): while `frozen` (a boss intro, a finished game) a flying player AUTO-HOVERS: it keeps the height it
  had (clamped to one tile above the bottom edge) with small automatic flaps (`HOVER_FLAP` -170, the sprite keeps
  flapping), so it neither falls to the bottom edge nor takes damage. Generic in `updateFlight`, not the Net-Copter's.
  Test: `netcopter_rules intro_planea`.
- Respawn: `AutoScroll.respawnPoint` in a Flappy level = in the air at a third of the window, the free cell closest to
  mid-height (never inside a pillar): `Level:flightSpot(x, minRow, maxRow)`. In a Flappy boss fight
  `BossZones.respawnPoint` uses the same rule at a third of the zone (away from the bottom edge).
- Shared simulation (golden rule 1): nothing new travels online yet (Flappy levels are listed in no online mode).

- FACING in flight: the last non-zero horizontal input (`inX`; starts right, kept while stunned or with no input; the
  window's own speed does not count). The sprite flips with it. Before 0.5.178 it was forced to the right.
- CHARGE and the SPECIAL ATTACK (0.5.169): `pa.charge` (0..`CHARGE_MAX` 5, `addCharge`), `fireSpecial` /
  `updateBursts` / `renderBursts`, `pa.bursts` — see [flappy-campaign](flappy-campaign.md#charge-special-attack-cages-walls-food-hud-plan-4-05169).
  The burst leaves towards `facing` (`b.dir`), the same rule `systems/Carry` uses for throws (the user, 2026-11-08:
  it only went right, so it missed the Net-Copter once it changed side); entities get `onSpecialHit(power, pa, dir)`
  and enemies are flung that way.

- POWER-UPS (0.5.172): `PlayerPowerups.lua` — the shield in the hurt / die path, `effects` timers, `sizeK`, ghost,
  magnets ([powerups](powerups.md)).

**Feel: not judged yet** — waiting for the user (debug menu → FLAPPY FLIGHT (TEST)). Harness `flappy_flight`.

History: 0.5.164 used the old Flappy's `GRAVITY` 1800 / `FLAP_VELOCITY` -480 and 330 px/s both ways on screen. The
user: the gravity "is stronger than it should be", and going left "everything feels heavier and slower". 0.5.165:
`FLY_GRAVITY` 1350, `FLY_FLAP` -450, and backward = `FLY_SPD` + the window's speed.

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
