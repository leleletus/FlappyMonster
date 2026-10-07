# The boss system (zones, intros, phases, walls, pairs)

A boss is an entity derived from `src/world/entities/base/Boss.lua` placed inside a **boss zone**. The zone walls
players in, runs the intro, starts and ends the fight, moves the camera and the respawn point, and owns the music.
Recipe for a new boss: [how-to-add-a-boss](how-to-add-a-boss.md).

| Boss | Type id | Doc | Story level | Shard |
|---|---|---|---|---|
| Gummy King (Rey Gummy) | `megagummy` | [megagummy](megagummy.md) | `reino_gummy` | 1 |
| Mega Crabby | `megacrabby` | [megacrabby](megacrabby.md) | `guarida_cangrejo_rey` | 2 |
| Evil Ship (Nave Malvada) | `miniboss1` | [miniboss1](miniboss1.md) | `fortaleza_malvada` | 3 |
| Snowball Boss (Gran Bola de Nieve) + Verity | `snowboss` | [snowboss](snowboss.md) | `lago_helado` (mid-island) | 4 |
| Icy Mega Crabby | `megacrabby_ice` | [megacrabby-ice](megacrabby-ice.md) | `glaciar_cangrejo` | 5 |
| Mega Gloomy Crabby | `megagloomy` | [megagloomy](megagloomy.md) | `gruta_lugubre` | 6 |
| The Mirror | `mirror` | [mirror](mirror.md) | `ruta_del_espejo` | 7 |
| Mirror chase (not a fight) | `mirrorchase` | [mirror-chase](mirror-chase.md) | `huida_del_espejo` | — |

**Files:** `src/world/systems/BossZones.lua` (zones + the fight controller), `src/world/entities/base/Boss.lua`
(health, hits, i-frames, stun rule, generic intro and death, ally turns, `strike`), `src/ui/BossHud.lua` (bars,
intro cinema bars, "RUN!"), `src/fx/BossFx.lua` (stars, anger symbols, target mark),
`src/world/systems/PhaseBlocks.lua`, `src/world/systems/XtraBosses.lua` (two bosses on Xtra Extreme),
`types/mechanisms/bosswall.lua`, `bossglass.lua`, `phaseblock.lua`.

**Level data:** `bossZones: [{id, col, row, w, h, music}]`; the boss, its walls and its glass are entities with a
`zone` prop (0 = nearest). **Network:** snapshot `bz` = per zone `{stateCode, arrived, needed, phase}`.

**Design rules shared by all bosses:** every attack is telegraphed; one clear vulnerable window (stomp 1, ground
pound 2, one hit per opening); outside it, landing on the boss bounces you off sideways; damage to players goes
through `Boss.withPlayer` / `Boss.strike`; everything drawn derives from `state + deadTimer + x, y + netPackExtra`.
Online, levels with bosses are Race-only.

**Harnesses:** `boss_sim`, `boss_intro`, `boss_frames`, `sp_boss` (`DIFF=xtra`, `MOBILE=1`, `RETRY=level`),
`online_boss`, plus one `<boss>_rules` per boss; test arenas in `tools/levelgen/arenas/`.

## Zones, the fight controller and the intro

Files: `src/world/systems/BossZones.lua` (zones + fight controller),
`src/world/entities/base/Boss.lua` (base class), `src/world/entities/types/bosses/mirror.lua`
(MirrorEnemy), `src/ui/BossHud.lua` (segmented HP bars, banners).

- **Zone** (`level.bossZones`, JSON `bossZones:[{id,col,row,w,h,music}]`):
  states `idle → waiting → fight → cleared`. While not cleared, any player whose
  center is inside is walled in (`Level:arenaAt` → clamp in
  `PlayerAdventure:moveAndCollide`; also clamps the boss body). The fight starts
  when ALL `level.players` are inside; bosses get `startFight(nPlayers)`;
  respawn points move into the zone. Camera: `BossZones.cameraTarget` via
  `cameraZone` — during a fight it also stays fixed for players BELOW the zone
  (fell through a broken floor: walls no longer hold them, camera must not follow).
  **Boss intro**: if a boss has `hasIntro()`, the zone goes `waiting → intro → fight`
  (state code 5, appended: codes are network ids). During 'intro' players inside are
  FROZEN (`Level:frozenAt` → `PlayerAdventure:update` feeds an all-false Input and
  zeroes vx; gravity still acts; identical SP/server/prediction since the zone state
  is in snapshots) and `BossZones.music` returns `BossZones.SILENCE` (states call
  `Sound.stopMusic()`). The boss runs `startIntro(level, players, z)` and the fight
  starts when every boss says `introDone()`. Event `boss_intro`. Harness `boss_intro`
  (any boss: `LEVEL=`). GENERIC intro in `Boss.lua`: a boss with `introLength` (s or
  function) gets states 'intro' → 'ready' (not active, not solid) and hooks
  `onIntroStart(level, players)`, `updateIntro(dt, level, t)`, optional `introFocus()`;
  everything drawn must derive from state + deadTimer + x,y (net). During 'intro' the
  camera centres on the boss (`cameraTarget` → `introFocus()` or its editor spot) and
  `BossHud.drawCinema(level)` draws letterbox bars (under the HUD) with the boss name
  typed in; the WHOLE HUD (score/time, lives, HP bars, pause, ping, mode panel, touch
  controls) fades out and back with the bars (`BossHud.fadeHud(fn)` renders a HUD piece via a
  canvas at `BossHud.hudAlpha()`; `TouchControls.draw(nil, nil, fade)`). MiniBoss1: descends from above the view braking + spike threat (3.4 s;
  without a zone the old 'intro_fight' descent). Mirror: jumps up from below the screen
  through the floor (`introPlan()` = pure function of zone + home, used by client for the
  laugh timing), lands, laughs (`laughTime()`). The Mega keeps its own states.
  Music: zone field `music` = any catalog track with `"boss": true` (options built
  from `Music.bossList` + 'level'; default 'boss'; editor: zone inspector). Prefer
  OGG for music (the updater ships it to every player).
  `BossZones.music(level)` → `Sound.setLevelMusic(track)` (so every
  `Sound.playMusic('level')` call plays the boss track during the fight).

- **Controller** (`BossZones.newController(level, entities)`) runs in
  AdventureState and on the server; returns events `boss_start`/`boss_clear`.
  Calls `boss:onPlayerDeath(pa)` when a participant dies inside.

## Network

- **Net**: snapshot `bz = {{stateCode, arrived, needed}, ...}` →
  `BossZones.netApply` on the client (drives arena prediction, camera, HUD).
  Boss entity extras: `netPack` = {hp, hpMax, inv*100, ...netPackExtra}.
  Sound events now carry `pitch`. Remote players' hurt flash = `PF_HURT` flag.
  Damage a boss does to a player is attributed with `Boss.withPlayer(pa, fn)`
  (server sets `Boss.asPlayer`), and the victim's client plays 'dies' via
  `Predictor.reconcile(...).hpDrop`.

## Boss base: health, hits, the stun rule, immune bounce

- **Boss base**: HP = props.hp + props.hpPerPlayer*(n-1); stomp = 1 dmg,
  ground pound on top = 2 dmg (`'pound'` result → `e:pound(pa)`); i-frames
  `INV_TIME` (red flash, stomps only `'bounce'`); body is solid sideways. Death: `dying_hold` (blasts, alternating
  'bossExplode'/'bossHurt') → `dying_fall` → `dead` (alive=false → zone cleared).
  `e:interact(pa)` must be side-effect free (client uses it to predict bounces).

- **Stun rule** (anti ground-pound spam): a ground pound on top of a stunnable
  boss (mirror) deals 2, leaves it KO ('ko') AND makes it invulnerable at once
  for `STUN_INV` (3 s > the 1.4 s KO): no follow-up hit while KO. If it's stunned
  by something else (knockback from a nearby GP), `isStunned()` takes ONE hit,
  then `endStun()` + `STUN_INV`. That "ghost" invulnerability blinks
  (`ghostAlpha`), keeps attacking, can't be stunned, and bosses/players pass
  through each other. Invulnerable players also pass through bosses (but not
  `solidFull` objects) and bosses can't hit them.

- **Immune bounce**: landing on a boss that can't be hurt returns
  `'bounce', vy, dirX` → `pa:bounce(vy, dirX)` pushes the player sideways
  (no riding bosses); predicted on the client via `recordBounce(vy, dir)`.

## Phases and phase blocks

- **Phase system** (generic, any boss): `Boss:bossPhase()` (default 1) → the controller keeps
  `z.phase` = the highest of its bosses (4th field of the `bz` snapshot) and calls `PhaseBlocks.update`.
  **Phase blocks** (`src/world/systems/PhaseBlocks.lua`, entity `phaseblock` "Bloques de fase", Mecanismos: rect
  `corner`, props `phase`, `zone`, `hiddenAs` = empty/ice/snow/stone/...): at load (SP, server AND client, not
  in the editor: `lvl._editor` from `EditorModel:buildLevel`) the cells are swapped for `hiddenAs`; when the zone
  reaches the phase, SP/server restore them ('set' tile events, hop + 'spawn' fx; an Activador also shows its
  spark trail; occupied cells wait). Any entity can do the same with a `phase` prop: the **Freezer** (`phase`,
  `zone`) is hidden, not solid and doesn't fire until then, then drops from the ceiling on its chains
  (`DESCEND_T` 1.1 s, sound `cryoDrop`, render clipped below the ceiling). Editor: everything shows as placed.

## Boss walls

- **Boss walls** (`types/mechanisms/bosswall.lua`, entity "Bloque de jefe", Mecanismos): rect of
  normal-looking blocks (cell = top-left, `corner` = bottom-right, `zone` id, 0 =
  nearest), hidden+passable → appearing (when its zone is in 'fight'; waits until no
  player is inside) → solid (`solidFull` body: blocks players/entities, climbable) →
  vanishing (zone no longer fighting) → hidden. State sent in snapshots (hidden =
  netAtRest). `BossZones.link` gives entities with `wantsLevel` the level (edges drawn
  like real blocks). Prop `material` (Piedra/Tierra/Césped/Arena/Nieve, default stone): drawn
  with that tile's real draw (grass cap, sand transitions), so walls can match the arena. Protocol v19.

## Respawning during a fight; solid bodies

- Boss-zone respawns: dying in a zone in 'fight' respawns at `BossZones.safeSpawn(level,
  z)` (via `respawnPoint`, SP + server): the best-scored standable cell of the zone
  (`Level:isStandable`) — far from the boss (its `markerX` while aiming; capped at 7
  tiles), no other enemy within 2.5 tiles, head out of water, below a flood's max
  level penalised, never inside a solid body (boss walls). Fallback: old spawn if it
  still has ground, else `Level:findGround`. Frozen players (boss intro) are
  invulnerable (`isInvulnerable` = invT or `pa.frozen`, no blink).

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

## Adding a boss

- **Adding a boss**: FOLLOW `docs/bosses/how-to-add-a-boss.md` (step-by-step guide + checklist: design,
  art, sounds, particles, entity skeleton, minions, net, lang, arena, real level, harnesses, docs, release;
  with the pitfalls already paid for). Short version: `types/<name>.lua` with `Entity.extend(Boss, …)`, def fields
  `category='Jefes'`, `boss={title=…}`, `hide=Boss.HIDE`,
  `props=Boss.props({hp=…, hpPerPlayer=…}, {extra props})`; implement
  `initBoss/updateBoss/render` (+ hooks listed at top of Boss.lua); add the name
  to `TYPES` in `src/world/entities/Entities.lua`. Place it inside a zone in the editor.
