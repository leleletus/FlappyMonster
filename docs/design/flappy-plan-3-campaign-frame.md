# Flappy campaign — Plan 3: the campaign frame (implementation plan)

<!-- project_check: future-paths (this plan names files that do not exist yet) -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The FLAPPY button leads to a real campaign: 3 Flappy save slots (Easy / Normal / Hard), a zone map, stages
played on Adventure's engine with lives, Game Over and the results screen, and CONTINUE resuming the last mode played.

**Architecture:** The story mode's save / run / slots / results code is split into a shared core plus a per-campaign
descriptor, so Flappy reuses it instead of copying it (golden rule 2). Flappy gets its own data (`Zones`), its own save
files (`flappy<n>.sav`) and its own map screen. Stages are normal Flappy levels (`"flappy": true`) launched through
`AdventureState` with the same `lives / onLeave / onGameOver / onFinish` contract the story map uses.

**Tech Stack:** LÖVE 11.x, Lua (LuaJIT); harnesses under `tools/tests/` run with `tools/tests/run.sh`.

**Spec:** [flappy-prequel](flappy-prequel.md) (sections Gameplay, Difficulties, Menus and access) and the menu
decisions of 2026-11-07 in it. Roadmap of all plans: [flappy-prequel § Plans](flappy-prequel.md#plans).

## Global Constraints

- Golden rules in `CLAUDE.md`, especially: 1 (shared simulation), 2 (no copied code: extend the base), 3 (catalogs are
  data; ids are never renamed), 7 (nothing gained in a stage is saved before the stage is finished).
- Flappy saves are SEPARATE from Adventure's: files `flappy1.sav`, `flappy2.sav`, `flappy3.sav` in the LÖVE save
  folder (never names of game `.lua` files).
- Campaign difficulties: only `easy`, `normal`, `hard` (Extreme and Xtra Extreme stay Adventure-only).
- Health 3 HP (4 on Easy) = `Difficulty.k('playerHp')`, unchanged.
- Stage ids are level file names and are stored in saves: choose them once (`valle_pilares_1`, `valle_pilares_2`) and
  never rename them.
- `Campaign.READY` stays **false** in this plan (the campaign has no ending yet); the Adventure lock is not switched on.
- Player-facing text only through `assets/lang/translations.csv` (CRLF line endings, UTF-8 BOM, every language).
- Code comments and commit messages in Spanish; docs in English. Bump `version.txt` per pushed commit; no
  `Protocol.VERSION` change (nothing online changes).

## Review Focus

1. **Continue with saves of both modes** — CONTINUE must open the most recently WRITTEN save of either mode, and must
   ignore Adventure saves while Adventure is locked. Test in Task 6.
2. **A damaged Flappy save file** — the slot shows as damaged/empty but the file is NOT overwritten until the player
   chooses to (same as the story's `.bak` behaviour). Test in Task 1.
3. **Leaving a stage halfway (pause → menu)** — lives LOST are kept, nothing gained is kept (rule 7). Test in Task 4.
4. **Narrow and wide screens** — slots and zone map at 960, 1280 and 1600 logical width, nothing cut. Captures in
   Task 5 / Task 3.
5. **Story mode regression after the core extraction** — `story_flow`, `menu_flow`, `collection` and `sp_boss` still
   pass unchanged. Run in Task 2.

---

### Task 1: `SaveFile` — the shared save-file primitives

**Files:**
- Create: `src/core/SaveFile.lua`
- Modify: `src/story/Save.lua` (its local `ser`, `parse`, `read`, `write` move out; `Save.write/delete/global` call
  `SaveFile`)
- Test: `tools/tests/flappy_campaign/main.lua` (new harness, case `archivo`), its row in `tools/tests/README.md`,
  `"flappy_campaign"` in the `LIST` of `tools/tests/run.sh`

**Interfaces:**
- Produces: `SaveFile.read(name) -> table|nil, damaged:boolean`, `SaveFile.write(name, data) -> boolean` (writes
  `name .. '.bak'` first, as today), `SaveFile.remove(name)`, `SaveFile.modtime(name) -> number|nil`.

- [ ] **Step 1:** Create the harness folder like `tools/tests/flappy_flight/` (symlinks `assets input.lua libs
  settings.lua src`, `conf.lua` with identity `fm_test_fcampaign`). Case `archivo`: write `{ a = 1, t = { 'x' } }`,
  read it back equal; write garbage text to `flappy9.sav` → `read` returns `nil, true` and the file is unchanged.
- [ ] **Step 2:** Run `tools/tests/run.sh flappy_campaign CASE=archivo` → FAIL (module missing).
- [ ] **Step 3:** Move the four functions from `Save.lua` into `SaveFile.lua` without changing their behaviour; the
  file is still a Lua table read without an environment.
- [ ] **Step 4:** Run `CASE=archivo` → PASS; run `tools/tests/run.sh story_flow` → TODO OK.
- [ ] **Step 5:** Commit `Guardado: SaveFile compartido (leer / escribir con .bak) sacado de Save`.

### Task 2: `RunCore` — progress rules shared by both campaigns

**Files:**
- Create: `src/story/RunCore.lua`
- Modify: `src/story/Run.lua` (keeps only the story extras: shards, secrets, bonus, collectibles, unlocks)
- Test: harness case `progreso`

**Interfaces:**
- Consumes: `SaveFile` (Task 1).
- Produces: `RunCore.install(R, saves, worlds)` adds to module table `R` (which holds `R.slot`, `R.data`):
  `open(i, difficulty)`, `close()`, `active()`, `save()`, `isDone(id)`, `worldOpen(w)`, `state(w, k)`,
  `progress(w)`, `frontier()`, `setLives(n)`, `score(id, result) -> summary` (the scoring + best + points part of
  today's `Run.complete`, without world rewards / unlocks), `restartWorld(w)` (the non-`restartGame` part of
  `Run.gameOver`). `saves` must provide `SLOTS, new(difficulty), load(i), write(i, d)`; `worlds` must provide
  `count(), get(w), nodes(w)` with nodes `{ id = <level id> }` and `get(w).boss`.
- `Run.complete` and `Run.gameOver` keep their signatures and results; they call the core parts.

- [ ] **Step 1:** Case `progreso` on a fake catalog of 2 worlds × 2 nodes: `state(1,1) == 'open'`, `state(1,2) ==
  'locked'`; after `score` of node 1 → `state(1,2) == 'open'`; after the world-1 boss → `worldOpen(2)`;
  `frontier()` returns `2, 1`; `restartWorld(1)` clears world 1's `done` and keeps `best`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement `RunCore.install`; make `Run.lua` call `RunCore.install(Run, Save, Worlds)` and delete its
  now-duplicated functions.
- [ ] **Step 4:** Run `CASE=progreso` → PASS; then `story_flow`, `collection`, `menu_flow`, `sp_boss` → all TODO OK.
- [ ] **Step 5:** Commit `Historia: RunCore (progreso, puntuación, vidas) compartido por las campañas`.

### Task 3: Zones, Flappy saves and `FlappyRun`

**Files:**
- Create: `src/flappy/Zones.lua`, `src/flappy/FlappySave.lua`, `src/flappy/FlappyRun.lua`
- Create: `tools/levelgen/levels_flappy_valle.py` → `assets/levels/valle_pilares_1.json`, `valle_pilares_2.json`
  (placeholder stages in the style of `_flappy_vuelo.json`: `"flappy": true`, auto-scroll, pillars, finish; the second
  harder; replaced by real stages in Plan 5, same ids)
- Modify: `src/flappy/Campaign.lua` (`Campaign.finished()` hook: when the LAST zone's last stage is completed, call
  `Campaign.unlockAdventure()`; harmless while only zone 1 exists because `READY` is false)
- Test: harness cases `zonas`, `partida`

**Interfaces:**
- `Zones.LIST = { { id = 'valle', stages = { 'valle_pilares_1', 'valle_pilares_2' }, boss = nil } }` — data, one line
  per zone; `Zones.count()`, `Zones.get(z)`, `Zones.nodes(z) -> { { id = stage }, ... }` (boss last when present),
  `Zones.path(id)` = `'assets/levels/' .. id .. '.json'`. Lang keys `flappy.zone.<id>` (Valle de los Pilares / Valley
  of the Pillars).
- `FlappySave`: `SLOTS = 3`, `VERSION = 1`, `new(difficulty) -> { version, difficulty, world = 1, node = 1, lives,
  done = {}, best = {}, playTime = 0, points = 0, gameOvers = 0 }` (lives = `Difficulty.of(difficulty, 'livesStart',
  3)`), `load(i)`, `write(i, d)`, `delete(i)`, `file(i)` = `'flappy' .. i .. '.sav'`. (The field names `world` /
  `node` are RunCore's.)
- `FlappyRun` = `RunCore.install({}, FlappySave, Zones)` plus `complete(id, result) -> summary` (score, then
  `Campaign.finished()` when it was the last node of the last zone) and `gameOver() -> z` (restart the current zone;
  lives back to the start).
- Every stage file must load with `level.flappy == true` and a finish trigger.

- [ ] **Step 1:** Cases: `zonas` — every node of `Zones` exists as a file, is Flappy, has a finish, `level_check`
  errors 0; `partida` — `FlappyRun.open(2, 'easy')` writes `flappy2.sav` and NOT `story2.sav`; `complete` of stage 1
  opens stage 2; lives on Easy = 3 at start; `gameOver()` returns to zone 1 node 1.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement the three modules and the generator; run the generator.
- [ ] **Step 4:** Run cases → PASS; `run.sh level_check -- assets/levels/valle_pilares_*.json` → TODO OK;
  `run.sh docs_reference` (new levels).
- [ ] **Step 5:** Commit `Flappy: zonas como datos, partidas flappy<n>.sav y FlappyRun; dos etapas provisionales del Valle`.

### Task 4: The zone map and playing a stage

**Files:**
- Create: `src/states/flappy/FlappyMapState.lua` (state `flappy_map`, registered in `game.lua`)
- Modify: `src/states/story/StoryResultsState.lua` (`args.returnTo` default `'story_map'`, `args.name` overrides the
  level title; nothing else changes)
- Test: `menu_flow` case `mapa` (it runs the real game states; `flappy_campaign` stays a module-level harness)

**Interfaces:**
- Consumes: `FlappyRun`, `Zones` (Task 3).
- `flappy_map` args `{ world = z, node = k, notice = langKey|nil }`. Layout computed at draw time (rule 9): a header
  with the zone name, the zone's stages as a row of nodes on a path (done = gold with grade, open = red, locked =
  grey, as the story map), the selected stage's card at the bottom (name, best grade, best time), lives top right.
  ← → move, ENTER plays, BACK → `flappy_slots` (Task 5). Touch: tap a node = select, tap the selected = play. The
  look is placeholder (menu background + panels); the real map art is Plan 5.
- Playing = `Transition.go('adventure', { level = Zones.path(id), returnTo = 'flappy_map', difficulty =
  FlappyRun.data.difficulty, lives = FlappyRun.data.lives, onLeave = FlappyRun.setLives, gameOverNote =
  L('flappy.go_zone'), onGameOver = <FlappyRun.gameOver() then flappy_map with notice 'flappy.go_notice'>, onFinish =
  <FlappyRun.complete then story_results with returnTo = 'flappy_map', name = level name> })` — the same contract as
  `StoryMapState:_start`.

- [ ] **Step 1:** Case `mapa`: open slot 1 Normal, `flappy_map` shows 2 nodes (`open`, `locked`); ENTER → an
  `AdventureState` whose `level.flappy` is true and whose `returnTo` is `flappy_map`; calling its `onFinish` with a
  fake result → `StoryResultsState`; confirming → `flappy_map` with node 2 open; leaving a stage through the pause
  menu after losing a life → save lives = start − 1 and `done` unchanged (Review Focus 3). Captures
  `menu_flappy_map_{960,1280,1600}.png`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement `FlappyMapState`; the two `StoryResultsState` args.
- [ ] **Step 4:** Run → PASS; look at the three captures (nothing cut, nothing overlapping).
- [ ] **Step 5:** Commit `Flappy: mapa de zonas (provisional) y jugar una etapa con vidas, Game Over y resultados`.

### Task 5: Flappy save slots through the shared slot screen

**Files:**
- Create: `src/story/Campaigns.lua` (descriptors)
- Modify: `src/states/story/StorySlotState.lua` (reads everything campaign-specific from the descriptor),
  `src/states/flappy/FlappyCampaignState.lua` (CAMPAÑA becomes a real button → `story_slots { campaign = 'flappy' }`;
  INFINITO stays while `READY` is false), `game.lua` only if a new state name is needed (prefer none)
- Test: `menu_flow` case `flappy_slots`

**Interfaces:**
- `Campaigns.get(id) -> descriptor`, ids `'story'` and `'flappy'`. Descriptor fields: `saves` (Save | FlappySave),
  `run` (Run | FlappyRun), `worlds` (Worlds | Zones), `map` (`'story_map'` | `'flappy_map'`), `back` (state + args to
  return to: `adv_mode_select` | `flappy_campaign`), `difficulties` (`Difficulty.ORDER` | `{ 'easy', 'normal',
  'hard' }`), `label(slotData) -> { window = cart label frame, title = text }`, `introFilm` (`'intro'` | nil),
  `extras(slotData) -> footer text | nil` (story: shards line; flappy: nil).
- `story_slots` args gain `campaign` (default `'story'`); with `'story'` the screen behaves exactly as today.

- [ ] **Step 1:** Case `flappy_slots`: FLAPPY → CAMPAÑA reaches the slot screen with 3 empty cartridges; an empty one
  offers exactly 3 difficulties; choosing Normal creates `flappy<n>.sav` (no `story<n>.sav`) and lands on
  `flappy_map`; BACK from the slots returns to `flappy_campaign` with CAMPAÑA selected; the story slots unchanged
  (existing `story_slots` checks still pass). Captures at 960 / 1280 / 1600 (Review Focus 4).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement `Campaigns.lua` and route `StorySlotState` through it; the Flappy cartridge label uses
  the "new" window until Plan 5 draws a Valley window (`cart_labels.png` is generated by
  `tools/art/ui/make_menu_ui.py`; check `docs/art/generators.md` for hand edits before touching it).
- [ ] **Step 4:** Run `menu_flow` → TODO OK; `story_flow` → TODO OK.
- [ ] **Step 5:** Commit `Flappy: partidas en cartuchos (la pantalla de partidas, compartida con la historia)`.

### Task 6: CONTINUE resumes the last mode played

**Files:**
- Modify: `src/states/menu/TitleState.lua` (`lastSlot` → the newest save across campaigns)
- Test: `menu_flow` cases `con partida` (extended) and `continuar_flappy`

**Interfaces:**
- Consumes: `Campaigns` (Task 5), `SaveFile.modtime` (Task 1).
- `TitleState:_lastSave() -> campaignId, slot | nil`: newest `modtime` over every slot of every campaign, skipping
  `'story'` while `Campaign.adventureLocked()`. CONTINUE's description says which (`menu.desc_continue` gets `{mode}`:
  "Flappy" / "Aventura"). Choosing it opens that campaign's run and goes to its map.

- [ ] **Step 1:** Cases: a story save written after a Flappy save → CONTINUE opens `story_map`; then a Flappy save
  written later → CONTINUE opens `flappy_map` with that slot; with `Campaign.READY = true` and Adventure locked, a
  newer story save is ignored (Review Focus 1).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement; update the `menu.desc_continue` row (es / en) in the CSV.
- [ ] **Step 4:** Run `menu_flow` → TODO OK.
- [ ] **Step 5:** Commit `Menú: CONTINUAR sigue el último modo jugado (Flappy o Aventura)`.

### Task 7: Docs, full battery, release

**Files:**
- Create: `docs/gameplay/flappy-campaign.md` (the usual skeleton: what · files · data · SP / server / client · how to
  extend — adding a zone / a stage — · tests · decisions), a line in `docs/README.md`
- Modify: `docs/architecture/save-data.md` (`flappy<n>.sav`), `docs/architecture/menus.md` (slots by campaign,
  CONTINUE), `docs/story/story-mode.md` (RunCore / Campaigns), `docs/gameplay/flappy-mode.md` (access),
  [flappy-prequel](flappy-prequel.md) (step 3 status), `tools/tests/README.md`

- [ ] **Step 1:** `run.sh project_check` (only the known `tools/music/ref` failure) and `run.sh docs_reference`.
- [ ] **Step 2:** `run.sh all` → only the failures already present before this plan (`bot_nav`, `gloomy_rules`, the
  flaky `online_smoke` / `online_boss`).
- [ ] **Step 3:** Bump `version.txt`, commit, `git fetch` + `git log HEAD..origin/master`, push. Deploy only from
  Linux for now (memory: deploy-from-linux); tell the user the version and commit.
- [ ] **Step 4:** Hand-off note: what only a person can judge (the placeholder map's usability on a phone, the two
  placeholder stages' difficulty).
