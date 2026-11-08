# The Flappy campaign (zones, saves, map)

**What:** the main menu's FLAPPY → CAMPAÑA is the prequel campaign of [flappy-prequel](../design/flappy-prequel.md):
3 save slots of its own (Easy / Normal / Hard), a map of ZONES, and STAGES that are Flappy levels (`"flappy": true`, the
player flies: [player](player.md#flight-flappy-levels)) played on Adventure's engine with lives, Game Over and the
results screen. Built in Plan 3 ([flappy-plan-3-campaign-frame](../design/flappy-plan-3-campaign-frame.md), 0.5.167).
Today: zone 1 (Valley of the Pillars) with two PLACEHOLDER stages and a placeholder map look; the real content comes in
Plans 4–7 (roadmap: [flappy-prequel § Plans](../design/flappy-prequel.md#plans)).

**Files**

| File | Role |
|---|---|
| `src/flappy/Zones.lua` | the campaign as DATA: zones in order, each with its stages and (later) its boss |
| `src/flappy/FlappySave.lua` | slots `flappy1..3.sav` (separate from Adventure's `story<n>.sav`), `DIFFICULTIES` |
| `src/flappy/FlappyRun.lua` | the open slot: RunCore + `complete` (score; the last stage of the last zone → `Campaign.finished`) and `gameOver` (back to the start of the zone) |
| `src/story/RunCore.lua` | progress rules SHARED with the story (`Run.lua`): open / save / state / frontier / setLives / score / restartWorld |
| `src/core/SaveFile.lua` | save files as Lua tables with a `.bak` copy (shared with `Save.lua`) |
| `src/story/Campaigns.lua` | per-campaign descriptors (`story`, `flappy`) read by the slot screen and CONTINUE |
| `src/states/flappy/FlappyCampaignState.lua` | FLAPPY: CAMPAÑA (→ slots) and, while `Campaign.READY` is false, INFINITO (the old endless mode) |
| `src/states/story/StorySlotState.lua` | the cartridge slot screen, for either campaign (`story_slots { campaign = 'flappy' }`) |
| `src/states/flappy/FlappyMapState.lua` | the zone map (`flappy_map`), placeholder look |
| `src/flappy/Campaign.lua` | `READY`, the Adventure lock, `finished()` |
| `tools/levelgen/levels_flappy_valle.py`, `flappy_lib.py` | the two placeholder stages `valle_pilares_1/2` |

**Data:** a zone = one entry in `Zones.LIST` (`id`, `stages`, `boss`) + a lang key `flappy.zone.<id>`. Stage ids are level
file names and are stored in saves: never rename them. A slot: `{ version, difficulty, world, node, lives, done, best,
playTime, points, gameOvers }` ([save-data](../architecture/save-data.md)).

**Playing a stage:** the map calls `AdventureState` with the same contract as the story map: `lives`, `onLeave` (lives
LOST are saved however the stage ends), `onGameOver` (`FlappyRun.gameOver()`: the zone starts again, lives back to the
start, records kept), `onFinish` (`FlappyRun.complete` → `story_results` with `returnTo = 'flappy_map'`). Nothing gained
in a stage is saved before it is finished (golden rule 7).

**CONTINUE** (main menu): the most recently written save of ANY campaign (`TitleState` `lastSave`), Flappy or Adventure;
while Adventure is locked, its saves do not count.

**SP / server / client:** single player only. Flappy levels are listed in no online mode yet (project 3).

**How to extend**
- A stage: a Flappy level file (editor: Nivel → "Nivel Flappy (se vuela)", plus the auto-scroll) and its id in
  `Zones.LIST`; `run.sh flappy_campaign CASE=zonas` checks it.
- A zone: an entry in `Zones.LIST` + `flappy.zone.<id>` in `assets/lang/translations.csv`.
- Turn the Adventure lock on: `Campaign.READY = true` in the same commit that makes the campaign finishable (Plan 6).

**Tests:** `flappy_campaign` (`archivo`, `progreso`, `zonas`, `partida`), `menu_flow` (`flappy_slots`, `mapa`,
`continuar_flappy`, `candado`).

**Decisions**
- 2026-11-07, the user: FLAPPY first in the main menu, CONTINUE = the last mode played, Free Play only in the debug menu.
- Plan 3 rulings: finishing the placeholder zone does not unlock Adventure (`Campaign.finished` only counts with
  `READY`); the slot screen is shared with the story through descriptors instead of a copy.
