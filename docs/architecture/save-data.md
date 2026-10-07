# What is saved, and where

Everything lives in LÖVE's save directory (identity `FlappyMonster`; on Linux
`~/.local/share/love/FlappyMonster/`). Files are plain Lua tables or small text files, loaded without an environment
(they cannot run code). **Never give a save file a name that shadows a game module** (`settings.lua`, `game.lua`…):
the save directory is searched before the game's own files.

| File | Written by | Contents |
|---|---|---|
| `options.cfg` | `src/core/Settings.lua` | language, last accepted online name (`onlineName`) |
| `<difficulty>_highscore.dat` (`SCORE_FILE`) | `src/states/flappy/PlayState.lua` | Flappy best score, one file per Flappy difficulty |
| `story1.sav` … `story3.sav` | `src/story/Save.lua` | one story slot each: difficulty, lives, per-level best (rating, grade, points), done nodes, shards, bonus results, world rewards, points |
| `story.sav` | `src/story/Save.lua` | global: unlocked difficulties, cleared difficulties |
| `update/state.lua`, `update/slots/<version>/`, `update/boot.log` | `main.lua`, `src/update/Updater.lua` | downloaded versions (see [updates-and-release](updates-and-release.md)) |
| `recordings/*.csv` | `src/core/PlayRecorder.lua` | only with `FM_RECORD=1` (development) |
| `assets/nav/<level>.json` (in the save dir) | `src/ai/BotNav.lua` | bot navigation graphs rebuilt on the device when the shipped one is stale |
| `editor_playtest.json` | the editor (F5) | the level being play-tested |

**The story rule (user's rule, enforced by `story_flow`): nothing gained in a level is saved until the level is
finished.** Leaving through the pause menu keeps only what was LOST (lives); pickups, shards, points and grades are
written by `Run.complete` / `Run.addShard` from `onFinish`. Any new thing a level can give must follow it.

Old saves are migrated on load (`Shards.migrate`: shards of bosses already beaten are granted).

Going to Google Play: cloud saves would wrap `src/story/Save.lua` and `src/core/Settings.lua` — both already funnel
every read and write through two functions each.

## Story slots

- `src/story/Save.lua`: 3 slots `story1..3.sav` + global `story.sav` (unlocks) in the save dir — Lua tables loaded
  without an environment; never a `.lua` name. `src/story/Run.lua`: the open slot; `state(w, k)` = done / open /
  locked (levels open in order, the next world when the boss is beaten), `complete(id, result)` saves, `frontier()`.
