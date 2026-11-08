# The Flappy campaign (zones, saves, map)

**What:** the main menu's FLAPPY → CAMPAÑA is the prequel campaign of [flappy-prequel](../design/flappy-prequel.md):
3 save slots of its own (Easy / Normal / Hard), a map of ZONES, and STAGES that are Flappy levels (`"flappy": true`, the
player flies: [player](player.md#flight-flappy-levels)) played on Adventure's engine with lives, Game Over and the
results screen. Built in Plan 3 ([flappy-plan-3-campaign-frame](../design/flappy-plan-3-campaign-frame.md), 0.5.167).
Today: zone 1 (Valley of the Pillars) with two PLACEHOLDER stages, its boss stage `valle_redcoptero` (Plan 5) and a
placeholder map look; the real content comes in
Plans 4–7 (roadmap: [flappy-prequel § Plans](../design/flappy-prequel.md#plans)).

**Files**

| File | Role |
|---|---|
| `src/flappy/Zones.lua` | the campaign as DATA: zones in order, each with its stages and its boss stage (`boss`) |
| `src/flappy/FlappySave.lua` | slots `flappy1..3.sav` (separate from Adventure's `story<n>.sav`), `DIFFICULTIES` |
| `src/flappy/FlappyRun.lua` | the open slot: RunCore + `complete` (score; the last stage of the last zone → `Campaign.finished`) and `gameOver` (back to the start of the zone) |
| `src/story/RunCore.lua` | progress rules SHARED with the story (`Run.lua`): open / save / state / frontier / setLives / score / restartWorld |
| `src/core/SaveFile.lua` | save files as Lua tables with a `.bak` copy (shared with `Save.lua`) |
| `src/story/Campaigns.lua` | per-campaign descriptors (`story`, `flappy`) read by the slot screen and CONTINUE |
| `src/states/flappy/FlappyCampaignState.lua` | FLAPPY: CAMPAÑA (→ slots) and, while `Campaign.READY` is false, INFINITO (the old endless mode) |
| `src/states/story/StorySlotState.lua` | the cartridge slot screen, for either campaign (`story_slots { campaign = 'flappy' }`) |
| `src/states/flappy/FlappyMapState.lua` | the zone map (`flappy_map`), placeholder look |
| `src/flappy/Campaign.lua` | `READY`, the Adventure lock, `finished()` |
| `src/world/entities/types/items/flapcharge.lua`, `items/cage.lua`, `mechanisms/crackwall.lua` | the Flappy-only entities (category Flappy) |
| `src/ui/FlappyHud.lua` | hearts + charge meter |
| `tools/levelgen/levels_flappy_valle.py`, `flappy_lib.py` | the two placeholder stages `valle_pilares_1/2` |
| `tools/levelgen/levels_flappy_valle_boss.py` | the Valley's boss stage `valle_redcoptero` (writes only that file) |

**Data:** a zone = one entry in `Zones.LIST` (`id`, `stages`, `boss`, `food`) + a lang key `flappy.zone.<id>`. Stage ids are level
file names and are stored in saves: never rename them. A slot: `{ version, difficulty, world, node, lives, done, best,
playTime, points, gameOvers, rescued }` (version 2; [save-data](../architecture/save-data.md)).

**Playing a stage:** the map calls `AdventureState` with the same contract as the story map: `lives`, `onLeave` (lives
LOST are saved however the stage ends), `onGameOver` (`FlappyRun.gameOver()`: the zone starts again, lives back to the
start, records kept), `onFinish` (`FlappyRun.complete`: score, record and the GRADE REWARD the first time — S +1 life, A +500 points, as in the
story — → `story_results` with `returnTo = 'flappy_map'`; its RETRY comes back with `replay` + `cleared` and the map
plays that stage again), and `taken` (extra lives already picked up there only give points). Nothing gained
in a stage is saved before it is finished (golden rule 7).

**CONTINUE** (main menu): the most recently written save of ANY campaign (`TitleState` `lastSave`), Flappy or Adventure;
while Adventure is locked, its saves do not count.

## Charge, special attack, cages, walls, food, HUD (Plan 4, 0.5.169)

- **Charge:** `flapcharge` items (Flappy-only, `pickup = { charge = 1 }`) add 1 to `pa.charge`, up to
  `PlayerAdventure.CHARGE_MAX` = 5, applied in the shared pickup path (`Interactions.run` → `pa:addCharge`). Dying keeps
  it; each stage starts at 0.
- **Special attack** (action `special`: X / K, pad R shoulder, touch: the extra button above the jump button): with
  charge, a BURST leaves the monster's front with `power` = the whole charge (spent), at 900 px/s for up to 8 tiles. A
  solid tile stops it (pillars do not); each entity it overlaps gets `onSpecialHit(power, pa)` once — the base: enemies
  (not bosses) die flung, `Boss` takes `power` damage; returning true absorbs the burst ([player](player.md#flight-flappy-levels)).
- **Caged flappies** (`cage`, Flappy-only, prop `minCharge` 1–5, shown as dots over it): a burst with enough power frees
  it (`rescuedNow`), less is absorbed. `AdventureState` returns `result.rescued` (placement indices) only when the stage
  is FINISHED; `FlappyRun.complete` stores `rescued[stage]`; replays pass `rescued` and those cages are empty. The map
  card shows "Flappies freed n/m". What freeing ALL of them gives is still PENDING (the user); each one will give a
  power-up: its `gift`, given when the stage is finished ([powerups](powerups.md), Plan 4b, 0.5.172).
- **Cracked walls** (`crackwall`, Flappy-only, props `minCharge`, `rows`): solid like the door until a burst with enough
  power breaks it. They hide shortcuts / prizes: the main route never needs them (the zero-charge bot clears every
  Valley stage — `flappy_flight etapa`). The camera's left edge never pushes the player through an intact wall (0.5.170, final review of
  Plan 4): against a wall it is the usual AutoScroll rule. In the Valley stages each wall encloses a charge item (solid
  blocks under and right of it: `flappy_lib.populate`).
- **Food:** a Flappy level's `apple` with skin `auto` takes its zone's `food` (`Zones.LIST`, via `level.id`, the level's
  file name set by `Level.new`); the Valley's is a peach (`food_valle.png`).
- **HUD:** `src/ui/FlappyHud.lua` — hearts (always visible) and the charge meter under score / time; lives stay top
  right.
- Stage objects come from `tools/levelgen/flappy_lib.py` `populate` (charges in the gaps, food, a cage up high, a wall
  over a hidden charge).

## Boss stages (Plan 5)

A zone's `boss` is a Flappy level like the others, built with `flappy_lib.boss_arena(col, boss, ...)` passed to
`write(..., arena=)`: pillars first, then a one-screen BOSS ZONE (full height, its music) with the boss in its right
third and a couple of short pillars inside (`stubs`), then a few columns to the finish. The auto-scroll's `endCol` is
the zone's last column, so the window stops exactly over the zone (`AutoScroll` 'stop', no walls) and the zone takes
the camera; once the boss is beaten the zone opens and the player flies on to the finish (`onFinish` as in any stage).
Inside the fight the boss director (`bossdrops`) hands out charges / food. Dying in the fight respawns IN THE AIR in
the zone's left third (`BossZones.respawnPoint` → `Level:flightSpot`, the same rule as the auto-scroll's Flappy respawn):
standing on the floor would cost 1 HP. `valle_redcoptero`: pillars at columns 18-60 (3 charges, 1 food), zone 66-85
with the `netcopter` at (81, 5) and music `tuffi`, finish at column 93.

**SP / server / client:** single player only. Flappy levels are listed in no online mode yet (project 3).

**How to extend**
- A stage: a Flappy level file (editor: Nivel → "Nivel Flappy (se vuela)", plus the auto-scroll) and its id in
  `Zones.LIST`; `run.sh flappy_campaign CASE=zonas` checks it (a boss stage needs a boss zone with a boss inside, no cage).
- A boss stage: a generator like `levels_flappy_valle_boss.py` (`flappy_lib.boss_arena`) and the id as the zone's `boss`.
- A zone: an entry in `Zones.LIST` + `flappy.zone.<id>` in `assets/lang/translations.csv`.
- Turn the Adventure lock on: `Campaign.READY = true` in the same commit that makes the campaign finishable (Plan 6).

**Tests:** `flappy_campaign` (`archivo`, `progreso`, `zonas`, `partida`, `premio`, `jaulas`), `flappy_flight` (`carga`,
`ataque`, `jaula`, `muro`, `etapa` on every Valley stage), `netcopter_rules` (`etapa_jefe`: the boss stage is passable
— arena reached, camera stopped, zone fighting, walls down after the win, finish touched; `muerte_en_pelea`: respawn in
the air inside the zone with full HP), `touch_layout` (`especial`), `menu_flow` (`flappy_slots`, `mapa`,
`continuar_flappy`, `candado`).

**Decisions**
- 2026-11-07, the user: FLAPPY first in the main menu, CONTINUE = the last mode played, Free Play only in the debug menu.
- Final review of Plan 3 (fixed in 0.5.168): the grade reward was shown but not given; RETRY did nothing; `taken`
  was not passed (extra lives could be farmed once stages have them).
- 2026-11-08, the user, after Plan 4 (0.5.170): "por lo demás, diría que está bien" — the charge, attack, cages,
  walls, food and HUD stand as built.
- Plan 3 rulings: finishing the placeholder zone does not unlock Adventure (`Campaign.finished` only counts with
  `READY`); the slot screen is shared with the story through descriptors instead of a copy.
