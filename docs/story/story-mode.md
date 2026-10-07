# Story mode: worlds, saves, lives, results, shards

Story mode is a thin layer of DATA and bookkeeping around `AdventureState`: six worlds (islands) of levels ending in a
boss, three save slots, lives that persist, a results screen with grades and rewards, difficulties with unlocks, and
the seven mirror shards. The lore is in [story](story.md).

**Files** (`src/story/`)

| File | Role |
|---|---|
| `Worlds.lua` | the story as data: ordered worlds `{ id, levels, boss, bonus }`. Reordering the game = editing this table |
| `Save.lua` | 3 slots + global unlocks (see [save-data](../architecture/save-data.md)) |
| `Run.lua` | the open slot: node states, `complete(id, result)`, lives, Game Over, rewards, unlocks, bonus results, shards |
| `Score.lua` | scoring as data: weights, par time, grades, rewards |
| `Shards.lua` | which boss drops which shard; the in-level drop and pickup |
| `BonusMatch.lua` | the King-of-the-Hill match against the bot ([bonus-and-bot](bonus-and-bot.md)) |
| `Film.lua`, `Stage.lua`, `films/` | the cinematics ([cinematics](cinematics.md)) |

States: `src/states/story/StorySlotState.lua`, `StoryMapState.lua` ([world-map](world-map.md)),
`StoryResultsState.lua`, `StoryFilmState.lua`.

**Flow:** slot → (new save: difficulty + intro film) → map → level (`AdventureState` with `lives`, `difficulty`,
`onFinish`, `onLeave`, `onGameOver`, `shards`) → results → map, standing on the cleared node while the next opens.

**Rules:** every story level needs a finish; nothing gained in a level is saved until it is finished; a Game Over
restarts the world (the whole game on Xtra Extreme); beating the last boss on Hard unlocks Extreme, on Extreme unlocks
Xtra Extreme. **Harness:** `story_flow` (the real game end to end; many named cases).

## Worlds and saves

- Menu: Aventura → HISTORIA (`story_slots`) / ONLINE / JUEGO LIBRE (PRUEBAS) (`free_play` stays as the debug hub).

- `src/story/Worlds.lua` = the story as DATA: ordered worlds `{ id, levels = {...}, boss }` (stage 7 order; every
  story level needs a FINISH — hunt-only levels have none). `Worlds.nodes(w)`, `levelName(id)`.

- `src/story/Save.lua`: 3 slots `story1..3.sav` + global `story.sav` (unlocks) in the save dir — Lua tables loaded
  without an environment; never a `.lua` name. `src/story/Run.lua`: the open slot; `state(w, k)` = done / open /
  locked (levels open in order, the next world when the boss is beaten), `complete(id, result)` saves, `frontier()`.

## Finishing a level

- **Level complete now exists in single player** (it didn't: reaching the finish did nothing): `AdventureState`
  detects the `finish` trigger → `win()` (fanfare, banner `hud.level_clear`, invulnerable) → after `WIN_TIME` calls
  `args.onFinish(result {score, time, lives})` or goes to `returnTo`. The story passes `onFinish`; Free Play and the
  editor just return.

- **3.83.2 — NOTHING GAINED IN A LEVEL IS SAVED UNTIL IT IS FINISHED** (user's rule, after an exploit: enter, grab the
  extra life, leave by the pause menu, repeat forever). `AdventureState.finished` (set when `onFinish` is called: the
  finish or the final shard); `exit()` → `onLeave(lives)`: finished = the player's lives; left halfway = the lives it
  ENTERED with minus its deaths (never more than it has, never below 1 — 0 lives is the Game Over, handled apart): lost
  lives count, picked-up ones don't. Mirror SHARDS: `onGet` only notes them (`gotShards` in `StoryMapState`) and
  `Run.addShard` runs in `onFinish` (they used to be saved at once on pickup). Points, grades and rewards were already
  saved only by `Run.complete`. Any NEW thing a level gives must follow the same rule. Harness `story_flow`
  (`game_over`: −1 life +2 pickups then quit → only the loss is saved; `fragmento`: picked up, not saved).

## Lives and Game Over

- **Stage 3 ✔ — lives and Game Over.** Lives belong to the ADVENTURE (save field `lives`), not to the level: start =
  `livesStart` (3 on Easy/Normal/Hard, 4 on Extreme, 6 on Xtra Extreme — the user's numbers; `Difficulty.of(id, name,
  default)` reads a modifier without a level). `AdventureState` args `lives`, `onLeave(lives)` (called from `exit()`
  however the level is left — finished, pause → exit — so lost lives always count; never on 0 lives), `onGameOver()`
  + `gameOverNote`: with them the Game Over overlay has no "retry", only CONTINUE. `Run.gameOver(world)`: lives back to
  the start value and the WORLD restarts (its nodes are no longer done; `best` records stay); with the modifier
  `restartGame` (Xtra Extreme) the whole game restarts. The map shows the lives and a notice after a Game Over.

## Results, grades, rewards

- **Stage 4 ✔ — results, grades, rewards.** `AdventureState` keeps level stats (`self.stats`: kills of non-boss
  enemies, killable total from `Modes.entityInfo`, stars / total, deaths, hits = HP lost) and passes them in the
  `onFinish` result. `src/story/Score.lua` = the scoring as DATA: weights (time 30 vs a par of 0.75 s per tile of level
  width, min 40 s, zero at 3×par; lives 25; hits 10; kills 15; stars 20) → rating 0-100 → grade S ≥95, A ≥85, B ≥70,
  C ≥50, D; world grade = average of the best rating of each node. `Run.complete` stores best rating / grade / points
  (× difficulty `scoreMult`: easy .8, hard 1.2, extreme 1.5, xtra 2), total points, and gives REWARDS: the first time a
  level reaches S → +1 life, A → +500 points (`Score.LEVEL_REWARD`); clearing a world's boss the first time, by the
  world grade S +2 lives, A +1, B +1000 points (`WORLD_REWARD`, once per world: `worldReward`). `StoryResultsState`
  is based on `OnlineResultsState` (the user asked for its life: bouncing title, light rays, youWin music ducked while
  counting, tick sounds) adapted to ONE player: a single pedestal (height + colour by grade) the monster lands on,
  rows slide in and count up, TOTAL /100 and points, then the grade is stamped on the pedestal (S/A: confetti +
  fireworks, B: confetti, D: sad trombone); then record / rewards / world grade. First ENTER skips the animation,
  the next returns to the map. The MONSTER (user's request: it was hard to see and lifeless) stands in a spotlight
  with a light outline (silhouette shader drawn at 4 offsets) and REACTS: falls onto the pedestal, NERVOUS while the
  rows count (foot taps, looks left/right, little hops, tremble); after the grade: happy jumping (S A B), standing
  sighing (C), sad crouched with its back turned (D), and below 25/100 a comic DEATH (the game's death sprite with X
  eyes, jumps and falls out, then drops back in sad) — visual only. Confetti and fireworks are a shared module, `src/ui/Celebration.lua` (also used by
  the online results). The map shows each cleared node's grade and the world grade.

- (2) TIME TARGET PER LEVEL: JSON `"parTime"` (s; editor Nivel → General → "Tiempo objetivo (s)", 0 = automatic by width as before) → `level.parTime` → `result.par` → `Run.complete`; the results row shows "time / target". laberinto_submarino = 300 s.

## The mirror shards

The monster could FLAP (Flappy mode) — by a MAGIC of its own: it has NO WINGS, never draw or mention wings. It crashed
into an old mirror in the volcano, which broke into 7 SHARDS; its REFLECTION (the Mirror boss) walked out and stole
the flap, so the adventure is on foot with only the double jump (the little magic left). Whoever finds a shard grows
huge and furious = "LA FURIA DEL ESPEJO" / "The Fury of the Mirror" (every boss; the Evil Ship's pilot found one
like the rest). Each boss drops its shard; all 7 restore the mirror, the bosses shrink back and the monster flaps
again. No dialogue or text: animation + music.

- **Shards** (3.68.0): images `assets/images/story/mirror/` from `tools/art/story/make_mirror_shards.py --apply` (`frame.png`,
  `glass.png` whole, `shard_1..7.png` in story order — Gummy King, Mega Crabby, Evil Ship, Snowball, Icy Mega, Mega
  Gloomy, Mirror = the CENTRE piece — and `shard_<n>a/b.png` for Xtra Extreme; all on one 48x64 canvas so they
  assemble). Logic `src/story/Shards.lua`: `Shards.LEVEL[level] = n`, `pending(level, data)`, `owned/count(data)`
  (7, or 14 halves when the difficulty has `bossExtra`), `migrate` (old saves: shards of beaten bosses granted).
  In a level (STORY + single player only, not part of the shared sim): `AdventureState` `args.shards = { ids, onGet,
  final }` → `Shards.drops`: every boss that dies (or `releasesZone()`) drops the next id (Xtra: original 'a', copy
  'b'); it rises and hovers, is picked up by touch (after 5 s it homes to the player; touching the finish collects
  it), saved at once (`Run.addShard`; save field `shards`), popup `hud.shard`. `final` (the Mirror's): on pickup the
  player is frozen + invulnerable, the screen fades to white (`ENDING_TIME`) and `onFinish(result)` gets
  `result.ending = true` WITHOUT touching the finish → the map plays the ending film, then the usual results. The
  world map shows a card with the mirror (owned shards in place) and "n / 7" (`story.shards`). Xtra's game-over
  restart also clears the shards.

## Tests

- Harness `story_flow` (real game: slots, locked nodes, clearing levels, save reloaded from disk, world 2 unlock,
  delete; screenshots at 1280 / 960 / 1600, plus a tour with every world open: `story_world_<n>.png`).
