# Difficulty: the generic modifier framework

A difficulty is **a table of named modifiers** in `src/core/Difficulty.lua` (`easy`, `normal`, `hard`, `extreme`,
`xtra`). Base code never asks "which difficulty is this?"; it asks for a modifier: `Difficulty.k('airTime')`
(multiplier, 1 when absent), `Difficulty.flag('hazardHurt')`, `Difficulty.dt(entity, dt)` (time scale by entity
category), or `Difficulty.of(id, name, default)` when there is no level. The difficulty is a property of the LEVEL
being simulated (`level.difficulty`; `nil` = neutral, the game as it was), bound with `Difficulty.bind(level)` by
whoever steps the simulation — so single player, the server (several rooms) and the client always agree.

**Where it is chosen:** a story save picks it when created (`StorySlotState`; Extreme and Xtra Extreme must be
unlocked); Free Play has a chip (key F or tap); online, the room's host has a button (`set_difficulty`) and it
reaches clients in `game_init`. The Flappy mode's `DIFFICULTIES` in `settings.lua` are an unrelated, older table.

**Modifiers today**

| Modifier | Scales | Read in |
|---|---|---|
| `enemyPace`, `trapPace`, `bossPace` | the whole update of entities of that category (speed, telegraphs, cooldowns, projectiles) | `Difficulty.dt` in the entity loops; a type opts out with `pace = false` |
| `bossHp`, `pairHp` | boss health; health of each boss of an Xtra pair | `Boss:startFight` |
| `playerHp`, `invuln`, `airTime` | player HP, invulnerability time, air under water | `PlayerAdventure` |
| `hazardHurt` | spikes and lava take 1 HP + a hop instead of killing | `pa:hazardHit()` |
| `sense` | every enemy detection range (sight below, hearing, Gloomy sense, mortar, pufferfish, Hopper) | the entity types, `Noise.heard` |
| `ventDelay` | delay between oxygen bubbles | `Level` vents |
| `bossExtra` | TWO bosses per arena | `src/world/systems/XtraBosses.lua` |
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
  + `bossExtra`: TWO bosses per arena (`src/world/systems/XtraBosses.lua`, applied by `Level.fromData(lvl, difficulty)` — the
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

- (4) DIFFICULTY PICKERS: Free Play — chip top-right, key F (action `light`) or tap; ORIGINAL (none) → easy → … → xtra; remembered. Online — the HOST's room button "DIFICULTAD: X" (`set_difficulty { difficulty }`, admin only, WAITING), `room_update.difficulty`, shown to everyone on the game card; it reaches the match in `game_init` as before. Verity is the same Snowball class, so the difficulty applies to it too.
