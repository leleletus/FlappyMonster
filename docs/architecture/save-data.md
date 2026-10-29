# What is saved, and where

Everything lives in LÖVE's save directory (identity `FlappyMonster`; on Linux
`~/.local/share/love/FlappyMonster/`). Files are plain Lua tables or small text files, loaded without an environment
(they cannot run code). **Never give a save file a name that shadows a game module** (`settings.lua`, `game.lua`…):
the save directory is searched before the game's own files.

| File | Written by | Contents |
|---|---|---|
| `options.cfg` | `src/core/Settings.lua` | language, last accepted online name (`onlineName`) |
| `<difficulty>_highscore.dat` (`SCORE_FILE`) | `src/states/flappy/PlayState.lua` | Flappy best score, one file per Flappy difficulty |
| `story1.sav` … `story3.sav` | `src/story/Save.lua` | one story slot each: difficulty, lives, per-level best (rating, grade, points, time), done nodes, shards, bonus results, world rewards, points, play time (`playTime`), Game Overs (`gameOvers`), pre-level films already seen (`films`), extra lives already taken per level (`taken`), worlds open without the previous boss (`open`, from a migration), `version` |
| `story.sav` | `src/story/Save.lua` | global: unlocked difficulties, cleared difficulties |
| `*.sav.bak`, `*.sav.damaged` | `src/story/Save.lua` | copy written before each save; a file found unreadable (with its copy) is kept here |
| `update/state.lua`, `update/slots/<version>/`, `update/boot.log` | `main.lua`, `src/update/Updater.lua` | downloaded versions (see [updates-and-release](updates-and-release.md)) |
| `recordings/*.csv` | `src/core/PlayRecorder.lua` | only with `FM_RECORD=1` (development) |
| `assets/nav/<level>.json` (in the save dir) | `src/ai/BotNav.lua` | bot navigation graphs rebuilt on the device when the shipped one is stale |
| `editor_playtest.json` | the editor (F5) | the level being play-tested |

**The story rule (user's rule, enforced by `story_flow`): nothing gained in a level is saved until the level is
finished.** Leaving through the pause menu keeps only what was LOST (lives); pickups, shards, points and grades are
written by `Run.complete` / `Run.addShard` from `onFinish`. Any new thing a level can give must follow it.

Old saves are migrated on load: `Save.migrate` (slot `version` < `Save.VERSION`, today 2: the world index and the
`worldReward` keys are remapped by id through `Save.WORLDS`, the per-version world lists; a world inserted in the
middle — the jungle, 0.5.99 — leaves the world after it open in `open[id]` for saves that had already reached it, the
user's "keep their progress, jungle open"; details in [story-mode](../story/story-mode.md#worlds-and-saves)), then
`Shards.migrate` (shards of bosses already beaten are granted).

Going to Google Play: cloud saves would wrap `src/story/Save.lua` and `src/core/Settings.lua` — both already funnel
every read and write through two functions each.

## Story slots

- `src/story/Save.lua`: 3 slots `story1..3.sav` + global `story.sav` (unlocks) in the save dir — Lua tables loaded
  without an environment; never a `.lua` name. `src/story/Run.lua`: the open slot; `state(w, k)` = done / open /
  locked (levels open in order, the next world when the boss is beaten), `complete(id, result)` saves, `frontier()`.
- Crash safety (0.5.8): every write goes first to `<file>.bak`, then to `<file>`, so one of the two is always whole;
  reading falls back to the `.bak`. With both unreadable the slot shows empty but the broken file is copied to
  `<file>.damaged` first (a new game there no longer destroys it). `Save.write` returns false when the write failed.
  Harness `story_flow` (`roto`). Lost lives are saved on every death, not only when leaving the level.
