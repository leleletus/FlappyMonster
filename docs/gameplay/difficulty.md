# Difficulty: the generic modifier framework

A difficulty is **a table of named modifiers** in `src/core/Difficulty.lua` (`easy`, `normal`, `hard`, `extreme`,
`xtra`). Base code never asks "which difficulty is this?"; it asks for a modifier: `Difficulty.k('airTime')`
(multiplier, 1 when absent), `Difficulty.flag('hazardHurt')`, `Difficulty.dt(entity, dt)` (time scale by entity
category), or `Difficulty.of(id, name, default)` when there is no level. The difficulty is a property of the LEVEL
being simulated (`level.difficulty`; `nil` = neutral, the game as it was), bound with `Difficulty.bind(level)` by
whoever steps the simulation — so single player, the server (several rooms) and the client always agree.

**Where it is chosen:** a story save picks it when created (`StorySlotState`; Extreme and Xtra Extreme must be
unlocked); Free Play has a ◀ ▶ selector (key F or tap either half); online, the room's host has a ◀ ▶ selector with every difficulty (`set_difficulty`; `docs/architecture/menus.md`,
"Online screens") and it reaches clients in `game_init`. The Flappy mode's `DIFFICULTIES` in `settings.lua` are an unrelated, older table.

**Modifiers today**

| Modifier | Scales | Read in |
|---|---|---|
| `enemyPace`, `trapPace`, `bossPace` | the whole update of entities of that category (speed, telegraphs, cooldowns, projectiles) | `Difficulty.dt` in the entity loops; a type opts out with `pace = false` |
| `bossHp`, `pairHp` | boss health; health of each boss of a pair (`bossExtra`, which no difficulty sets) | `Boss:startFight` |
| `playerHp`, `invuln`, `airTime` | player HP, invulnerability time, air under water | `PlayerAdventure` |
| `hazardHurt` | spikes and lava take 1 HP + a hop instead of killing — also the hazard boxes of entities (hanging / falling spikes, spike rain, the Crabby's spike, mortar fire; `Interactions` marks them `'hazard'`, since 0.5.11) | `pa:hazardHit()` |
| `sense` | every enemy detection range (sight below, hearing, Gloomy sense, mortar, pufferfish, Hopper) | the entity types, `Noise.heard` |
| `ventDelay` | delay between oxygen bubbles | `Level` vents |
| `bossExtra` | TWO allied bosses per arena — kept for the future: NO difficulty sets it since 0.5.24 (harness: `sp_boss DIFF=xtra PAIR=1`, `difficulty_rules` `doble` switch it on) | `src/world/systems/XtraBosses.lua` |
| `bossFury`, `bossFuryPace` | bosses START ANGRY until their own angry phase: reddish pulse, light shake, anger symbols, × pace (Xtra Extreme, 1.2; a type may set `FURY_PACE`) | `Boss:furyActive` / `renderLive`, `Difficulty.dt`, `BossFx.fury` |
| `bossFood`, `bossLives` | (since 0.5.62: the MINIMUM seconds between two) FOOD / EXTRA LIVES falling from the sky inside a boss zone while it fights, only when NEEDED (the smart director, item 8); before: seconds on average at random (Extreme food 15.12; Xtra Extreme food 13.98 + lives 70 — the user: 0.5.6 1 % fewer than 11 / 9 / 30; 0.5.24 Extreme food 2 % fewer, Xtra lives 5 % fewer; 0.5.25 Xtra lives 54 % fewer, 31.9 → 70 s: "incredibly easy, up to 8 extra lives in one boss"; 0.5.26 food 25 % fewer on Extreme, 35 % fewer on Xtra) | `src/world/entities/types/directors/bossdrops.lua` |
| `livesStart`, `restartGame`, `scoreMult` | story lives, what a Game Over restarts, points multiplier | `src/story/Run.lua`, `Score.lua` |
| `botRest`, `botChase`, `botCount` | the KOTH bot's hostility | `src/ai/Bot.lua`, `src/story/BonusMatch.lua` |

**To add a modifier:** add the name with its values to the tables in `Difficulty.lua` and read it with
`Difficulty.k / flag` at the BASE point it affects (never inside one enemy). **Harnesses:** `difficulty_rules`,
`sp_boss DIFF=xtra`, `online_smoke DIFF=easy|xtra`.

## Details and values

- **Stage 2 ✔ — DIFFICULTY = generic modifier framework** (`src/core/Difficulty.lua`): each difficulty id (`easy, normal,
  hard, extreme, xtra`) is a table of NAMED modifiers; base code asks `Difficulty.k('airTime')` / `flag(...)`, never
  the difficulty's name. It is a property of the level being simulated: `level.difficulty` (nil = NEUTRAL: everything
  1 = the game as it was — Free Play, editor, harnesses, online rooms without one), bound with
  `Difficulty.bind(level)` (AdventureState enter/exit, server `initRoomSim` + every `stepRoom`, client on `game_init`).
  PACE = time scale per entity category: `Difficulty.dt(e, dt)` in the entity update loops (SP + server) scales the
  whole entity (walk, fall, telegraphs, cooldowns, projectiles) — `enemyPace` (Enemigos), `trapPace` (Trampas),
  `bossPace` (Jefes); a type opts out with `pace = false` or picks one with `pace = '...'`. No boss was retuned by
  hand. Others: `bossHp` (`Boss:startFight`), `playerHp` (`pa:applyDifficulty()`, called by whoever creates the player
  after binding), `invuln` (hit / respawn), `airTime` (drowning), `hazardHurt` (spikes and lava: `pa:hazardHit()` =
  1 HP + a hop instead of death), `bossExtra` (stage 6). Values: easy .8/.8/.7 pace, boss hp .75, 4 HP, invuln 1.3,
  air 1.4, hazardHurt; normal = boss pace .85, hp .9 (levels as today); hard = enemies/traps 1.1, air .9 (bosses as
  today); extreme 1.25/1.3/1.2, boss hp 1.15, invuln .75, air .8. Online: `set_mode { difficulty = id | 'none' }` →
  `room.difficulty` → `game_init.difficulty` (no room UI yet; additive, no protocol bump). Story: a NEW save asks the
  difficulty (`StorySlotState` picker; Extreme / Xtra locked until `Save.global().unlocked`); `AdventureState` takes
  `args.difficulty`. Harness `difficulty_rules`; `online_smoke DIFF=easy`.

- **Stage 6 ✔ — unlocks and the extremes.** Beating the game (the LAST world's boss) on a difficulty unlocks the next
  one for all 3 saves: `Difficulty.UNLOCKS` = { hard → extreme, extreme → xtra } → `Run.unlockAfter` → global
  `story.sav` {unlocked, cleared}; the results screen says "NEW DIFFICULTY: X" (`summary.unlocked`). Extreme =
  faster + `sense` 1.3 (Easy 0.8): × every enemy detection range — `Entity:seesPlayerBelow` (ceiling droppers,
  falling spikes), `Noise.heard` (hearing), Gloomy `senseRange`, mortar and pufferfish `range`. XTRA EXTREME = Extreme
  + `bossExtra` (UNTIL 0.5.24 — since then Xtra is ONE enraged boss, item (7); the mechanism is kept, off): TWO bosses per arena (`src/world/systems/XtraBosses.lua`, applied by `Level.fromData(lvl, difficulty)` — the
  difficulty is now known WHILE building, `Level.new(path, difficulty)`; AdventureState, server `initRoomSim` and the
  client `_buildWorld(lv, data.difficulty)` all pass it, so indices match): the level's JSON `"xtraBosses": [...]` or,
  by default, each boss in a zone mirrored across the zone centre (≥ `MIN_SEP` 5 cells apart, `point`/`points`/
  `patrol` props mirrored, the def's `xtraStrip` props removed — the Snowball Boss's `icicles` belong to the arena);
  both get `props.xtraPair` → hp × `pairHp` 0.65 (`Boss:startFight`). Their reserve minions double too. The pair
  starts SYMMETRIC (original at a third of the zone, the copy mirrored; `props.xtraCopy`). ALLY RULE (Boss base,
  generic): a boss may only START an attack when its ally isn't attacking nor just did (`ALLY_GAP` 0.8 s) and the copy
  waits `ALLY_START` 2.5 s — `Boss:mayAttack(level)`, asked by each type where it decides to attack; each type lists its
  attack states in its tuning `ATTACKS = {...}` (the Mirror's perch is positioning, not attack: it waits perched). That's
  ALL on purpose: allies move at their own pace and pass through each other — pushing/separating them (charges cut) and
  slowing the waiting one (floated in slow motion) were tried and the user preferred simple turns. One SHARED health
  bar for the pair (`BossHud.drawZone`, title "NAME ×2", also in the intro cinema). Bosses ignore other bosses' slam
  noises (`Noise.emit(..., from='boss')`, `Noise.heard(..., ignore)`: a Mega Gloomy charged at its ally). Tests don't
  pause when the window loses focus (`run.sh` exports `FM_TEST=1`, `game.lua love.focus`). Also fixed:
  a world reward was skipped when the level gave none (`ipairs` stopped at the nil). Harnesses: `difficulty_rules`
  (`sentidos`, `doble`), `story_flow` (`desbloqueo`), `sp_boss DIFF=xtra` (prints the bosses + "Aliados": fails if both attack at once
  > 0.5 s), `online_smoke DIFF=xtra` (the client has both).

- (3) VENTS: `Difficulty` `ventDelay` × the delay between oxygen bubbles (easy 0.8, hard 1.15, extreme / xtra 1.35).

- (4) DIFFICULTY PICKERS: Free Play — chip top-right, key F (action `light`) or tap; ORIGINAL (none) → easy → … → xtra; remembered. Online — the HOST's room selector "◀ DIFICULTAD X ▶" (0.5.0; before, a button that only cycled forward), over none + every id of `Difficulty.ORDER`, colours `Difficulty.COLORS` (`set_difficulty { difficulty }`, admin only, WAITING), `room_update.difficulty`, shown to everyone on the game card; it reaches the match in `game_init` as before. Verity is the same Snowball class, so the difficulty applies to it too.

- (5) BOSS-FIGHT HELP (0.5.5, the user: "on Xtra Extreme, food and extra lives should randomly fall from the sky inside
  the boss zone during boss fights; on Extreme only food — otherwise it's practically impossible"). Modifiers
  `bossFood` / `bossLives`. When the level's difficulty has either, `Level.fromData` APPENDS (after everything else:
  same indices on server and clients) an invisible director `bossdrops` (category Directores, `editorHide`: never
  placed by hand) and its reserve pickups (2 food `apple`, island skin auto; 1 `extralife`; `summonKey 'bossdrops'`).
  While a zone is in 'fight' the director picks a column of the zone with real ground below — no water, lava or spikes
  on the way, nothing solid above — and the pickup falls from the zone top (`Entity:dropFromSky`, state 'skyfall',
  0.3 × gravity, max 420 px/s: it is seen coming); a pickup is reused once taken, so at most 2 food + 1 life lie
  around at once. Server-simulated online (they are ordinary entities in the snapshots; the director is never sent).
  What a life gives is saved at the end of the level, like every pickup. Harness `difficulty_rules` case `ayuda`.
  Not judged yet: the rates (how much easier it gets).

- (6) THE WAITING ALLY STEPS ASIDE (0.5.23, the user: on Xtra Extreme the two Mega Crabbies were "incredibly hard,
  tedious and horrible" — while one attacked, the other kept chasing the player, trapping them between the two
  (jumping over it made it turn so you landed on its spike), and when the attacker ended stuck and vulnerable the
  chaser stood in the way, so it could not be hit). Boss base: `OPENINGS` (states open to hits after an attack;
  Mega: `stuck`) count as the boss's turn, so the ally does not attack then either; `Boss:allyBusy(level)` = the ally
  attacks, has just attacked (`ALLY_GAP`) or is open; `Boss:waitMove(level, target)`: while busy, go to the zone side
  farther from the player (`WAIT_EDGE` 2.5 cells from the wall), sway slowly there (±`WAIT_SWAY` 1 cell) facing the
  player, never walk toward the player when they are in the way, step back if they come within `WAIT_DIST` 4 cells
  (if the wall allows). The Mega uses it in its chase (0.7 × speed at first; its normal speed since 0.5.24, the user). Harness `sp_boss DIFF=xtra`: the waiting one
  walks toward the player (within 3 cells) ≤ 5 % of its waiting time (0 % after, 7 % before against the harness's
  standing player). Not judged yet: how the fight feels.

- (7) XTRA EXTREME = ONE ANGRY BOSS (0.5.24, the user: "instead of 2 bosses, only one, BUT it must start angry" —
  not from its phase 2: a GENERIC anger that only adds the red tint, shake, anger symbols and more speed and
  cadence; on entering its second phase the normal multipliers apply and the generic anger goes; bosses without
  a harder / angry second phase keep it, but the King Gummy fight must stay possible). `bossExtra` is off for
  every difficulty (the ally system — turns, `allyBusy`, `waitMove` — is KEPT for future uses, the user), so
  Shards.isXtra is false: every difficulty uses the whole shard and the normal films (the 14-halves code and the
  Xtra film variant are KEPT for the future; `Shards.migrate` turns halves already collected into the whole
  shard). Modifier `bossFury` (+ `bossFuryPace` 1.2): `Boss:furyActive()` = flag and active and not
  `Boss:angryPhase()`; types: Mega Crabby / Ice = `rage()`, Mega Gloomy = phase ≥ 2, Snowball Boss = phase ≥ 2,
  data bosses = `bossPhase() == 2`; King Gummy, the Mirror and the Evil Ship never (whole fight; the King with
  `FURY_PACE` 1.1: its phases already harden it — `boss_sim DIFF=xtra` on its arena: the scripted player still
  clears it, 1 death, as on Extreme). Pace through `Difficulty.dt` (server / SP); the look through
  `Boss:renderLive` → `BossFx.fury` (a tint shader multiplying everything the boss draws, 1 px shake now and then,
  `BossFx.anger` symbols over its box), called by the SP and online draw loops — the client derives it from the
  difficulty and the hp / phase in the snapshots. Mega Crabby's ally waiting walks at its normal speed (the user).
  Harness `difficulty_rules` `enfado`. Not judged yet: how hard / fair each fight feels.

- (8) 0.5.26, the user: the Snowball Boss keeps the generic anger's PACE in its phase 2 too (not in phase 3), and
  its LOOK (tint, shake, symbols) the whole fight: `Snow:angryPhase()` = phase ≥ 3 and `FURY_LOOK_ALWAYS` in its
  tuning (`Boss:furyLook()` = furyActive, or that flag; `renderLive` draws by furyLook). Food drops 25 % fewer on
  Extreme (11.34 → 15.12 s) and 35 % fewer on Xtra (9.09 → 13.98 s); to compensate, a Game Over on Xtra Extreme
  no longer restarts the whole game but the WORLD, like every difficulty (`restartGame` removed from Xtra; the
  modifier stays, no difficulty sets it). Harnesses: `difficulty_rules` `enfado`, `story_flow` `extremos`.
- (8) THE SMART HELP DIRECTOR (0.5.62, the user: drop food "when it is necessary, not randomly"; on Extreme / Xtra as
  before, and in EVENT levels on every difficulty, scaled — `Drops.EVENT_FOOD` / `EVENT_LIVES`: easy 8 / 40 s, normal
  11 / 55, hard 14 / 75 between drops). Food when a player in the zone is hurt AND low (≤ a third of max HP), or
  struggling (≥ 2 hits in 12 s, a death in the last 20 s, or 25 s hurt without the boss losing HP), or right before a
  hard part (`level.helpHint`: the event's seams and final swaps); an extra life at the last life while struggling.
  Never while one is already lying there. Spot: the best floor cell of the zone — away from the bosses and from where
  their attack will land (`markerX` / `markX`), 2-6 cells from the player who needs it, never on them, never on lava
  or water. `bossdrops.lua`; harness `difficulty_rules` (`ayuda`). The server's Sound stub gained `playAt` (the
  director's drop sound crashed the online room).
