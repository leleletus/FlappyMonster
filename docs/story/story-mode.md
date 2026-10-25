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

States: `src/states/story/StorySlotState.lua` (the slots as cartridges: [menus](../architecture/menus.md)), `StoryMapState.lua` ([world-map](world-map.md)),
`StoryResultsState.lua`, `StoryFilmState.lua`.

**Flow:** slot → (new save: difficulty + intro film) → map → (the level's own film the first time, if its world
names one: `Worlds` `films`, [cinematics](cinematics.md)) → level (`AdventureState` with `lives`, `difficulty`,
`onFinish`, `onLeave`, `onGameOver`, `shards`) → results → map, standing on the cleared node while the next opens.

**Rules:** every story level needs a finish (boss levels show none in the story: they end when the boss is beaten and its shard picked up — `AdventureState` removes the finish cells when `args.shards` and the level has a boss zone, 0.5.27); nothing gained in a level is saved until it is finished; a Game Over
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

- **3.101.0 — BOSS LEVELS END BY THEMSELVES IN THE STORY** (the user: having to walk to the finish after the boss
  was wrong in the adventure; it stays so in Free Play and online). The story passes `shards.auto` for every level
  with a boss (`Shards.LEVEL`): `Drops:cleared()` = every boss of the level fell (or released its zone) and no shard of
  theirs is left to pick up (none, if the save already had them) → `AUTO_WIN_T` 0.8 s later `AdventureState:win()`
  (fanfare, "level clear", results). The Drops object now also exists with no shard to win when `auto` is set. The
  Mirror's shard keeps its own path (the ending). Harness `story_flow` `jefe_solo`.

- **3.101.0 — A LEVEL CAN RUN STRAIGHT INTO THE NEXT** (`Worlds.LIST` `outros = { [level] = col }`, `Worlds.outro(id)`;
  today only `huida_del_espejo`, col 182). In the story that level has NO finish: `src/story/RunOut.lua` (single
  player only, not shared simulation) removes the finish tiles and, when the auto-scroll camera reaches the column,
  starts a scene inside the level with its own music: the camera stops and STAYS there (`AdventureState:updateCamera`
  returns while it runs — the user saw it follow the player into the wall at the end of the level: with auto-scroll
  stopped the normal camera took over), `level.cinema` brings the boss-intro cinema
  bars and fades the HUD (`BossHud.drawCinema` / `fadeHud`), the player loses control and runs on by itself (scripted
  input: a jump with a double jump, another later; no pause), the chaser switches to its `outro` state and keeps
  chasing (see [mirror-chase](../bosses/mirror-chase.md)); when both are out of frame, a fade to black and
  `onFinish(result.outro = true)`. `StoryMapState` then completes the level WITHOUT the results screen or the map,
  puts the save on the next node, plays that node's film (`lair`, always in this link) and starts it. Harness
  `story_flow` `enlace`.

## Lives and Game Over

- **Stage 3 ✔ — lives and Game Over.** Lives belong to the ADVENTURE (save field `lives`), not to the level: start =
  `livesStart` (3 on Easy/Normal/Hard, 4 on Extreme, 6 on Xtra Extreme — the user's numbers; `Difficulty.of(id, name,
  default)` reads a modifier without a level). `AdventureState` args `lives`, `onLeave(lives)` (called on every death and from `exit()`
  when the level is left unfinished — so lost lives always count, even if the app is killed; never on 0 lives; NOT
  when finished: `Run.complete` already stored the lives plus the rewards, and calling it there overwrote them
  until 0.5.8), `onGameOver()`
  + `gameOverNote`: with them the Game Over overlay has no "retry", only CONTINUE. `Run.gameOver(world)` (called with the
  FRONTIER world, `Run.frontier()`, not the replayed level's world — since 0.5.8): lives back to
  the start value and the WORLD restarts (its nodes are no longer done; `best` records stay); with the modifier
  `restartGame` (no difficulty today; Xtra Extreme until 0.5.25) the whole game restarts. The map shows the lives and a notice after a Game Over.

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
  `glass.png` whole, `shard_1..7.png` in story order — Gummy King, Giant Pufferfish (was Mega Crabby), Evil Ship, Snowball, Icy Mega, Mega
  Gloomy, Mirror = the CENTRE piece — and `shard_<n>a/b.png` for Xtra Extreme; all on one 48x64 canvas so they
  assemble). Logic `src/story/Shards.lua`: `Shards.LEVEL[level] = n`, `pending(level, data)`, `owned/count(data)`
  (7, or 14 halves when the difficulty has `bossExtra`), `migrate` (old saves: shards of beaten bosses granted; halves of a save whose difficulty no longer has `bossExtra` become the whole shard).
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

- 0.5.14, the user (replay farming: replaying a level gave its extra lives and its points again, "vidas infinitas"):
  - Extra lives are taken ONCE per level and save: AdventureState gets `taken` (the placement indices already taken
    in finished runs, `d.taken[levelId]`), those lives are drawn see-through and give `Interactions.TAKEN_SCORE`
    points instead; the ones taken now travel in `result.taken` and `Run.complete` stores them (only when the level is
    finished, rule 7).
  - Story points: a level (and a bonus win) only adds what beats its own record (`summary.gain`); the results screen
    says so when replaying. Grade / world rewards were already once per grade. Replaying for a better grade and score
    still works. Harness `story_flow` (`repetir`).
  - Records belong to the SLOT (`best` in `story<i>.sav`), never to the game: "new best grade" (`summary.record`) is
    shown only when the level already had a grade in THIS slot. The user (after 0.5.27): a new Extreme game, level
    cleared for the first time, said "new best grade" as if it came from the old Hard game — it compared against
    "-1" (no record). Now the first clear shows neither the record nor the gain line (`repetir` checks it).
