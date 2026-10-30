# Story mode: worlds, saves, lives, results, shards

Story mode is a thin layer of DATA and bookkeeping around `AdventureState`: seven worlds (islands) of levels ending in
a boss, three save slots, lives that persist, a results screen with grades and rewards, difficulties with unlocks, and
the mirror shards (one per boss + the Mirror's: `assets/story/shards.json`). The lore is in [story](story.md).

**Files** (`src/story/`)

| File | Role |
|---|---|
| `Worlds.lua` | the story as data: ordered worlds `{ id, levels, boss, bonus, secrets, epilogue, films, outros }` (`secrets`: the optional secret levels, [below](#the-secrets-secret-exits-splinters-the-groove-and-the-mashup)). Reordering the game = editing this table |
| `Collect.lua` | the COLLECTIBLES catalog (`assets/story/collectibles.json`: the splinter pieces and the disco ball), their state in the save, which boss drops which |
| `Save.lua` | 3 slots + global unlocks (see [save-data](../architecture/save-data.md)) |
| `Run.lua` | the open slot: node states, `complete(id, result)`, lives, Game Over, rewards, unlocks, bonus results, shards |
| `Score.lua` | scoring as data: weights, par time, grades, rewards |
| `Shards.lua` | the shard catalog (`assets/story/shards.json`: which boss drops which shard, story order); the in-level drop and pickup |
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

- **The worlds today:** 1 `pradera`, 2 `costa`, **3 `jungla`** (0.5.99: `senda_del_dosel`, `rio_revuelto`,
  `templo_de_los_pesos`, `la_estampida`, boss `templo_escarabajo`, bonus `claro_de_la_balanza`), 4 `fortaleza`,
  **5 `nieve` = the FROZEN MOUNTAINS** (`cumbres_escarcha`, `el_teleferico`, `torre_viento`, `ladera_del_alud`, boss
  `lago_helado` — the Snowball Boss, no longer a mid-island boss —, bonus `la_cima`), **6 `costa_helada` = the FROZEN
  COAST** (0.5.100; `fabrica_criogenica`, `tempanos_a_la_deriva`, `bahia_de_las_mareas`, `bajo_el_hielo`, boss
  `glaciar_cangrejo`, bonus `lago_de_cristal`; the new levels since 0.5.102),
  7 `cuevas`, 8 `final`. The split (the user, 2026-10-29): "there are 8 bosses and 7 islands" — the Snowball and the
  Icy Mega Crabby shared the ice island; now every island has one boss and one shard, with no new shard. Music: the
  old ice set (`nieve_*`, `map_nieve` → `map_costa_helada`) goes to the Coast; the Mountains get a new set (pending).

- **A WORLD INSERTED OR SPLIT (an expansion) — `Save.VERSION` 3, `Save.WORLDS`, `Save.migrate`.** Saves store
  the current world by POSITION (`world`) and the world grades by position (`worldReward[w]`). `Save.WORLDS[v]` lists
  the worlds of each save version as `{ id, boss that closed it then }` (1 = the six worlds before the jungle, 2 = with
  it, 3 = the ice island split). On load, a save of an older version is translated step by step: `world` and the
  `worldReward` keys are remapped by id to today's positions, and every world that WAS OPEN in the old version (the
  first one, or the old previous world's boss beaten, or already `open`) stays open (`open[id] = true`) when today's
  previous boss is not beaten. (0.5.99's first rule — "open the world after a new one" — would have opened the Caves
  for a save that had beaten the Snowball but not the Icy Crabby after the split; replaced in 0.5.100.) `Run.worldOpen(w)` = the previous boss beaten OR `open[W.id]`;
  `Run.gameOver` on `restartGame` (Xtra) clears `open` with the rest. The user's decision (0.5.99, asked how old saves
  should get the jungle): **"Keep their progress, jungle open"** — a save already past the Coast keeps the Fortress and
  everything after it open, and the jungle appears open for it; new saves must beat the jungle boss to open the
  Fortress. To add worlds: `Save.VERSION` + 1 and its list in `Save.WORLDS`. Harness `story_flow` `migrar_mundos`.

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

## The secrets: secret exits, splinters, the Groove and the Mashup

Built 2026-10-29 from the user's design (`FlappyMonster_pruebas/secretos/diseno.md`) and lore decisions
([story](story.md#the-secrets-the-splinters-the-groove-and-the-true-ending)). Everything is data; a new secret is one
line in `Worlds.lua`, its branch in the map generator and, if it gives something, one entry in `collectibles.json`.

- **Secret levels** — `Worlds.LIST[w].secrets = { { level, from, exit, after, collect, scene } }`. On the map: a red
  node with a keyhole on a branch from `from` (a level, `'bonus'` or another secret). Locked = it does not exist on the
  map. It opens when everything it asks for holds: `exit` (its secret exit was used: `found[level]`), `after` (levels
  done), `collect = kind` (every collectible of that kind owned, in any state), `scene` (that map scene seen:
  `films[scene]`; the scene plays by itself when the rest holds). They are OPTIONAL: not progress, not needed for the
  next world, replayable. `Run.secretState(e[, noScene])`, `Worlds.secrets(w)`, `secretExitOf(level)`,
  `secretOf(level)`, `allSecrets()`. Today: Coast `guarida_cangrejo_rey` (from `arrecife_globo`, exit), Caves
  `gruta_lugubre` (from `templo_del_eco`, exit), Final `isla_del_groove` (from the bonus; after `ruta_del_espejo`,
  every `splinter`, scene `groove`) and `mashup_cangrejos` (from the Groove; after it, scene `regrow`), plus the Final's
  `epilogue = { after = 'mashup_cangrejos', scene = 'disco' }`. The old single `secret` field is gone.
- **Island of a level** — `Worlds.worldOf(id)` → the world the level BELONGS to and where it comes from: `'story'`
  (levels, boss, bonus, secrets of `Worlds.LIST`) or `'table'` (`Worlds.MEMBERS = { [level] = world | false }`: the
  levels OUTSIDE the story — Free Play / online arenas — with their island; `false` = none, e.g. `EnemyTest`). A new
  non-story level = one line in `MEMBERS`. Used by the editor's Island filter ([editor](../levels/editor.md)).
- **Secret exits** — tile `secret_exit` (id 44, `src/world/tiles/types/secret_exit.lua`, art
  `tools/art/world/make_secret_exit.py`: a red plate with a keyhole). Touching it ends the level like the finish
  (`AdventureState` → `win()`, `result.secretExit = true`; results as usual). In the story, `onFinish` then calls
  `Run.findSecret` with the secret that `Worlds.secretExitOf(level)` names — saved together with the level in
  `Run.complete` (rule 7). Out of the story it is just another finish; online modes don't use it
  (`ModeTypes.hiddenTriggers`: not drawn, inert). Where they are:
  - `arrecife_globo` (140, 24): at the bottom of the underwater pocket behind the fake wall (cols 127-134, rows 20-21)
    that already held an extra life — one tile edited. Reachability: `run.sh level_solve GOAL=secret_exit VENTS=1 --
    assets/levels/arrecife_globo.json` (the air bubbles of the vent at col 120 are needed: `VENTS=1`).
  - `templo_del_eco` (75, 24): the low tunnel (rows 23-24) that ends at col 71 with an apple now goes on through a
    fake wall at col 72 into a 3-cell chamber. The tunnel is entered through breakable blocks (ground pound):
    `run.sh level_solve GOAL=secret_exit BREAK=1 -- assets/levels/templo_del_eco.json`. (Behind the finish was tried
    first: unreachable without touching the finish — it is 3 tiles tall.)
- **Collectibles** — `assets/story/collectibles.json` (ids `astilla_crabby` = the Shell Crown, `astilla_gloomy` = the
  Gloomy Amulet, kind `splinter`; `bola_disco` = the Disco Ball, kind `trophy`). Save `data.collect[id]`: nil = not
  yet, `true` = owned, any other value is a state (`'stolen'` today); every state counts as EARNED (`Collect.has`,
  `hasAll` — the Groove gate counts owned-or-stolen). A collectible with `source.boss` is DROPPED by that boss like
  a shard (`Shards.drops` `collect` / `onCollect`: the same floating piece, drawn with its icon; only the boss of that
  type drops it; a level with one ends by itself when the boss falls — `auto` — as do all secret levels). One without
  a boss is given when the level is FINISHED (`Collect.onFinish`: the Disco Ball at the end of the Mashup). Both only
  reach the save in `onFinish` (rule 7). A boss already beaten whose piece is owned does not drop it again.
- **Event levels keep their finish** — `AdventureState` no longer removes the finish (nor auto-wins) on a level with
  `event = true` (the Mega Mashup ends at its own exit, with its own script). A boss that never drops anything (the
  Groove: `shardDrop` false) now counts as cleared when it dies (`Drops:cleared`): `isla_del_groove` could not end in
  the story before (its finish was removed and nothing ended it).
- **Save version 4** (`Save.UPGRADE[4]`): `collect` and `found` start empty; the levels a secret exit leads to stop
  being done (an old save that played the Mega Crabby's lair when it was the Coast boss, or outside the story, gets
  nothing: it has to find the exit). `Save.WORLDS[4]` = version 3's worlds. Xtra's whole-game restart also clears
  `collect` and `found`. Harness `story_flow` `migrar_secretos`.
- **The map scenes** (`src/states/story/StoryMapScenes.lua`, a part of `StoryMapState`): `groove` (the theft),
  `regrow` (the three crabs grow again) and `disco` (the true ending) — see [world-map](world-map.md#the-secret-nodes)
  and [story](story.md#the-secrets-the-splinters-the-groove-and-the-true-ending).
- **Online:** nothing in the shared simulation changed (the tile has no collision and no online mode uses its trigger;
  the drops are single player). `Protocol.VERSION` unchanged by this work; the level files changed, so they travel with
  the next update.
- **Harness** `story_flow`: `salida_secreta`, `astilla`, `secreto`, `mashup`, `migrar_secretos`.

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
into an old mirror in the volcano, which broke into SHARDS (8 today); its REFLECTION (the Mirror boss) walked out and stole
the flap, so the adventure is on foot with only the double jump (the little magic left). Whoever finds a shard grows
huge and furious = "LA FURIA DEL ESPEJO" / "The Fury of the Mirror" (every boss; the Evil Ship's pilot found one
like the rest). Each boss drops its shard; all of them restore the mirror, the bosses shrink back and the monster flaps
again. No dialogue or text: animation + music.

- **Shards** (3.68.0): images `assets/images/story/mirror/` from `tools/art/story/make_mirror_shards.py --apply` (`frame.png`,
  `glass.png` whole, `shard_<id>.png` — Gummy King 1, Giant Pufferfish (was Mega Crabby) 2, Giant Rhino Beetle 8 (0.5.99), Evil Ship 3,
  Snowball 4, Icy Mega 5, Giant Hopper (was Mega Gloomy) 6, Mirror 7 = the CENTRE piece; story order 1 2 8 3 4 5 6 7 — and
  `shard_<n>a/b.png` for Xtra Extreme; all on one 48x64 canvas so they assemble). **Catalog `assets/story/shards.json`**
  (0.5.99: the single list, in story order; ids are saved, never renumbered — see [story](story.md#the-shards)). Logic
  `src/story/Shards.lua`: `LIST`, `ORDER` (ids in story order), `LEVEL[level] = id`, `BOSSES` (all but the final),
  `TOTAL`, `FINAL`; `pending(level, data)`, `owned/count(data)` (`TOTAL`, or twice as many halves when the difficulty
  has `bossExtra`), `migrate` (old saves: shards of beaten bosses granted; halves of a save whose difficulty no longer has `bossExtra` become the whole shard).
  In a level (STORY + single player only, not part of the shared sim): `AdventureState` `args.shards = { ids, onGet,
  final }` → `Shards.drops`: every boss that dies (or `releasesZone()`) drops the next id (with `bossExtra` — no difficulty today —: original 'a', copy
  'b'); it rises and hovers, is picked up by touch (after 5 s it homes to the player; touching the finish collects
  it), saved at once (`Run.addShard`; save field `shards`), popup `hud.shard`. `final` (the Mirror's): on pickup the
  player is frozen + invulnerable, the screen fades to white (`ENDING_TIME`) and `onFinish(result)` gets
  `result.ending = true` WITHOUT touching the finish → the map plays the ending film, then the usual results. The
  world map shows a card with the mirror (owned shards in place) and "n / 8" (`story.shards`). The jungle boss's drop
  is checked by `story_flow` `fragmento_jungla` (shard 8 dropped, picked up, saved when the level ends). Xtra's game-over
  restart also clears the shards.

## The collection

The secrets' collectibles (catalog `assets/story/collectibles.json`, logic `src/story/Collect.lua`, saved in
`data.collect[id]` only when the level is finished) have their own screen and art. The user's design (2026-10-29): each
secret crab WEARS its mirror splinter mounted and decorated, and the collectible is that piece.

- **Art** — `tools/art/story/make_collectibles.py --apply` (character maps + automatic outline in the material's own
  dark tone; previews in `FlappyMonster_pruebas/coleccion/`): `assets/images/story/collectibles/astilla_crabby.png`
  (the SHELL CROWN: sand shells, red coral, the splinter set upright as its jewel, sandy-red glass),
  `astilla_gloomy.png` (the AMULET: the splinter, purple glass, hanging from a cord with a clasp), `bola_disco.png`
  (the Groove's DISCO BALL: tiles of the mirror's blue glass plus a few of each splinter's tint) and `locked.png` (the
  "???" silhouette, a dark splinter that gives nothing away). One image is both the card icon and the piece the boss
  drops in the level (~16 art px, drawn at 4 like the mirror shards). The splinters differ from the 8 big shards by
  their tint (each its boss's) and their thin sliver shape.
- **Worn pieces** — separate overlay layers, never the bosses' own (hand-edited) sprites:
  `assets/images/bosses/megacrabby/wear_crown.png` and `megagloomy/wear_amulet.png`, at the boss's pixel scale. Generic
  in the boss base: `Cls.WEAR = { { image, anchor, ax, ay, frames = { [n] = { dx, dy } | false }, glint } }` and
  `Boss:drawWear(anchor, x, y, s, frame, flip[, glow])`, called by the type inside its own transform where the anchor
  is — the Mega Crabby at the base of its spike (`drawLocal`: follows every pose, wall, ceiling, flip), the Gloomy under
  its shell (`drawAmulet`: per-frame offsets, hidden on the dead frame; in the dark its splinter's pixel blinks in
  `renderGlow`). `Boss.WEAR_PROP` (editor bool `wear`, default on) takes it off; the Icy Mega has `WEAR = false`. Once
  the boss drops its loot (`Boss:shardDrop()`) it no longer wears it: the dropped piece is that one. Drawing only: the
  same in single player and online (props travel with the level).
- **The Collection screen** — `src/states/story/StoryCollectionState.lua` (`story_collection`), pushed over the world
  map: `{alt}` (the light button, [F] / [Y]) or tapping the mirror-shard card (which now also shows "Colección n/N").
  One card per catalog entry: owned → icon, name, kind, `desc` and `how`; missing → "???" silhouette and `hint` (texts
  `story.collect.<id>.name|desc|how|hint`, `story.collect.kind.<kind>`). Details in
  [menus](../architecture/menus.md). A new collectible = one catalog line, its icon (a block in the generator) and its
  four texts in both language files; the screen needs no change.
- **Other save states** (`data.collect[id]` other than `true`; `Collect.state`): an entry may override things per
  state in the catalog, `"states": { "<state>": { "icon": "…" } }` (`Collect.stateDef`, `Collect.iconPath(id, state)`,
  `Collect.image(id, state)`). Today `'stolen'` (the Groove pulls the splinters out during the `groove` map scene; the
  `disco` scene after the Mashup sets them back to `true`): the card shows the EMPTY piece
  (`astilla_crabby_empty.png` = the crown with an open setting, `astilla_gloomy_empty.png` = the cord and an empty
  bezel; same canvas as the full ones), the tag `story.collect.state.<state>` ("ROBADA" / "STOLEN") and the text
  `<keys>.<state>` instead of the "how"; it still counts as won. A new state = its catalog override (if any) and those
  two keys; no code.
- Harness `collection` (texts in every language, open from the map, cards owned / "???", grid navigation, touch, back
  to the same map spot, 960 / 1280 / 1600 captures, the worn pieces drawn, the `stolen` state: empty icon, tag, text).
- Not judged by the user yet: the look of the three pieces (full, empty, worn and as icons); the crown's size on the
  Mega Crabby.

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
