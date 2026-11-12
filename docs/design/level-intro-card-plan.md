# Level intro card — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** before the start countdown of every story / Free Play level (single player and online), a ~2 s black title
card that can't be skipped: two island-coloured bands slide in carrying the level name and the island, a small plate
with the number ("1-3", "1-B", "1-?", "1-castle") drops in, a strip of the island's ground, decoration and enemy along
the bottom, and the monster runs in. The server waits for every player to load (8 s limit), and the card is the
waiting screen.

**Architecture:** the start becomes ONE shared sequence in `src/world/systems/StartCountdown.lua` (no graphics):
card phase (`CARD_TIME`), then the countdown as today (`TIME`, `GO_TIME`). Single player drives it with its own
timer; the server freezes for `CARD_TIME + TIME` after every player has loaded; the online client derives the phase
from the server clock. The number and the per-island look are DATA in `src/story/Worlds.lua`. The card drawing is a
new `src/ui/IntroCard.lua` that replaces `LevelCard` (src/ui, removed in 0.5.202); its art comes from one committed generator.

**Tech Stack:** LÖVE 11 / Lua; sock (ENet) messages; plain-Python PNG generator (no PIL); harnesses `story_flow`,
`mechanics`, `online_smoke`, `level_shots` through `tools/tests/run.sh`.

**Spec:** [level-intro-card.md](level-intro-card.md)

## Global Constraints

- Card `CARD_TIME` = 2.0 s; countdown unchanged (`TIME` = 3, `GO_TIME` = 0.8). Setting `TIME` to 0 must work with
  nothing else changed (the user may remove the countdown after trying it).
- The card can NOT be skipped; NO pause (key, pad, corner button, focus loss) during the card or the countdown.
- Plates: normal `w-n`; boss `w-` + castle icon; bonus `w-B`; secret (including the 7 secret boss levels) `w-?`;
  no known number (no island, editor test, Free Play level outside the story's nodes) → no plate, bands and strip
  still shown.
- Shown in story mode and Free Play, single player, and online; NOT in Flappy stages (`level.flappy`), the menu demo
  (`demo`), editor test plays (`fromEditor`). Mid-match joiners / reconnects: no card.
- Level music starts when the card appears (already the case on state enter; keep it).
- Server waits for every starting player's `level_loaded`; limit 8 s after the first one arrives, 20 s after
  `game_init` if none arrives. While waiting the card stays alive; once the wait passes the card's normal end by 1 s,
  "Waiting for players..." with animated dots in the BOTTOM-LEFT (key `intro.waiting`).
- Network change: `Protocol.VERSION` 116 → 117 (comment in Spanish, first in the list), `version.txt` + 1.
- Every image a real asset file from a committed generator; never overwrite hand-edited sprites
  (`docs/art/generators.md` list). Pixel art, integer positions, stepped motion. No stencils (`src/ui/Clip.lua`).
- Layout at draw time from `WINDOW_W/H`. Player-facing text only via `assets/lang/translations.csv` (es, en).
- Code comments in Spanish; docs in English; tests only through `tools/tests/run.sh`. Commits with
  `git -c core.fileMode=false`, never `tools/deploy_server.sh`.

## Review Focus

- A RETRY from pause / a game-over restart / a respawn after death: the card shows on RETRY and restart, NEVER on an
  in-level respawn (checkpoint). → test in Task 1.
- A level name long enough to need two lines at 960 wide, and the plate, must not overlap each other or the strip
  (`lo_que_mas_largo`). → capture + rect check in Task 4.
- Online: a client that never sends `level_loaded` (crashed, old client mid-handshake) must not hold the room forever;
  a player who LEAVES during the wait must not be waited for. → tests in Task 5.
- Online round restarts (a new `game_init` for the same client, modes with rounds): the card shows again and the
  wait runs again. → test in Task 5.
- Window focus loss during the card on PC/phone: no pause menu pops over the card, and pausing works again right after
  the GO. → test in Task 1 (call `state:pauseGame()` directly; harnesses skip `love.focus`).

---

### Task 1: The shared start sequence and single player timing

**Files:**
- Modify: `src/world/systems/StartCountdown.lua`, `src/states/adventure/AdventureState.lua` (enter ~line 216-221,
  update ~618-648, `pauseGame` ~300, touch pause ~1158)
- Test: `tools/tests/mechanics/main.lua` (new check `inicio_fases`), `tools/tests/story_flow/main.lua` (new check
  `sin_pausa_inicio`)

**Interfaces:**
- Produces in `StartCountdown`: `CARD_TIME = 2.0`; `total(card)` → `(card and CARD_TIME or 0) + TIME`;
  `phase(rem)` → `'card'` (rem > TIME), `'count'` (0 < rem ≤ TIME), `'go'` (−GO_TIME < rem ≤ 0), or `nil`;
  `beeps(prev, rem)` unchanged signature but silent while `rem > TIME` (the first tick sounds when `rem` crosses TIME,
  or on the first frame if it starts ≤ TIME). `ticks(tickDt, card)` → ticks of `total(card)`.
- Produces in `AdventureState`: `self.introCard` (bool: this start has a card — not demo, not `fromEditor`, not
  `level.flappy`; true again on RETRY / restart, which re-enter the state); `self.startCd = StartCountdown.total(self.introCard)`;
  `self:startPhase()` → `StartCountdown.phase(self.startCd)` or `'go'` while `startGoT`, else nil.
  `pauseGame()` and the `pause` input do nothing while `startPhase()` is `'card'` or `'count'`.

- [ ] **Step 1: Write the failing checks.** `mechanics` `inicio_fases`: `phase(2.5)=='card'`, `phase(3)=='count'`,
  `phase(0.5)=='count'`, `phase(-0.1)=='go'`, `phase(-1)==nil`; `total(true)==5`, `total(false)==3`; beeps:
  stepping `rem` from 5 down by 0.1 with a `Sound.play` spy gives exactly 3 `countTick` and 1 `countGo`, none while
  `rem > 3`; with `TIME` temporarily set to 0, `phase(0.5)=='card'`, `phase(0)=='go'` and `total(true)==2`. `story_flow` `sin_pausa_inicio`: enter a story level; for 4.5 s of updates press `pause` every frame and
  call `pauseGame()` → the top state is still the adventure state and `player.x` unchanged; after the GO, `pause`
  pushes `PauseState`. Also: the demo and a Flappy stage start with `startCd == 3` (no card); after a checkpoint
  respawn `startCd` stays nil.
- [ ] **Step 2: Run** `tools/tests/run.sh mechanics` and `tools/tests/run.sh story_flow`; expected FAIL on the two
  new checks.
- [ ] **Step 3: Implement** the `StartCountdown` additions and the `AdventureState` changes (the frozen-world branch
  is the same; only the length, the beeps gate and the pause gates change). The old `self.card` / `cardT` stay for
  now (Task 4 replaces them).
- [ ] **Step 4: Run** both harnesses; expected all OK (fix any older check that assumed a 3 s start: search the
  harnesses for `StartCountdown.TIME` and `startCd`).
- [ ] **Step 5: Commit** "Inicio en dos fases (tarjeta + cuenta atrás) y sin pausa durante ellas".

### Task 2: Numbers and per-island look as data

**Files:**
- Modify: `src/story/Worlds.lua`
- Test: `tools/tests/story_flow/main.lua` (new check `placas`)

**Interfaces:**
- Produces: `Worlds.plate(id)` → `{ w = n, n = m }` (normal), `{ w = n, kind = 'boss' }`, `{ w = n, kind = 'bonus' }`,
  `{ w = n, kind = 'secret' }`, or `nil`. `w` = index in `Worlds.LIST`; `n` = index in `Worlds.nodes(w)` among the
  non-boss nodes. A secret level is `'secret'` even when it is a boss fight.
- Produces: each `Worlds.LIST` entry gets `intro = { bands = { {r,g,b}, {r,g,b} }, shade = { {r,g,b}, {r,g,b} },
  top = 'path/to/tile.png', under = 'path/to/tile.png', deco = 'path.png', enemy = { 'frame1.png', 'frame2.png' },
  enemyScale = n }` (image paths under `assets/images/`); `Worlds.INTRO_DEFAULT` the same shape (neutral greys, grass);
  `Worlds.introOf(id)` → the entry of `worldOf(id)` or `INTRO_DEFAULT`.

- [ ] **Step 1: Write `placas`:** `plate('valle_soleado')` = `{w=1,n=1}`; `plate('bosque_interruptores')` = `{w=1,n=3}`;
  `plate('reino_gummy')` = `{w=1,kind='boss'}`; `plate('isla_flotante')` = `{w=1,kind='bonus'}`;
  `plate('guarida_cangrejo_rey')` → `kind='secret'`; `plate('jardin_gummies')` (Free Play member) = nil;
  `plate('no_existe')` = nil. For every world, `intro` exists and every path in it loads with `love.graphics.newImage`.
- [ ] **Step 2: Run** `tools/tests/run.sh story_flow`; expected FAIL `placas`.
- [ ] **Step 3: Implement.** Pick each island's colours, tiles, decoration and enemy from its own assets (Pradera:
  green / gold, grass + dirt, an oak, a gummy; Nieve: icy blues, snow tiles, a fir, a penguin; final island: reds…).
- [ ] **Step 4: Run** `tools/tests/run.sh story_flow` and `tools/tests/run.sh project_check`; expected OK.
- [ ] **Step 5: Commit** "Número del nivel y aspecto de cada isla para la tarjeta (datos en Worlds)".

### Task 3: The card's art

**Files:**
- Create: `tools/art/ui/make_intro_card.py` → `monster-Sheet.png` (in assets/images/ui/intro, removed in 0.5.203), `band.png`, `plate.png`
- Modify: `docs/art/generators.md` (one line), `docs/art/asset-layout.md` (the `ui/intro/` folder)

**Interfaces:**
- Produces: `monster-Sheet.png` — the monster's run frames (`monstrito3-5`, as `make_loading.py` reads them) then its
  idle frames (`monstrito1-2`), each with a 1-px WHITE outline, frames of 11×18 in one row (run 1-3, idle 4-5);
  `band.png` — a 16×16 white/light-grey pixel band piece (tinted by the band colour at draw time; top-edge highlight
  row), tiled horizontally, with a 4-px end cap at its leading edge; `plate.png` — a small white 9-slice-able plate
  (12×12, 4-px corners) with a 1-px darker rim. The castle icon is frame 1 of `assets/images/story/castle-Sheet.png`
  (reused, not copied).

- [ ] **Step 1: Write the generator; run** `python3 tools/art/ui/make_intro_card.py`; expected three files written.
- [ ] **Step 2: Look at each PNG enlarged** (Read the image): outline continuous around the monster, no hole; no wing
  shapes (CLAUDE.md rule 6).
- [ ] **Step 3: Commit** with the doc lines: "Arte de la tarjeta de presentación del nivel".

### Task 4: `IntroCard` — drawing and single player

**Files:**
- Create: `src/ui/IntroCard.lua`
- Delete: `LevelCard` (src/ui, removed in 0.5.202) (and its uses in `AdventureState` and `OnlineAdventureState`)
- Modify: `src/states/adventure/AdventureState.lua` (draw the card while `startPhase() == 'card'`, INSTEAD of the
  level), `assets/lang/translations.csv` (`intro.waiting` es "Esperando jugadores", en "Waiting for players"; the dots
  are drawn, not in the text), `tools/tests/story_flow/main.lua` (rewrite `tarjeta`), `tools/tests/level_shots` or
  `story_flow` captures
- Test: `story_flow` `tarjeta`, captures `intro_pradera`, `intro_nieve`, `intro_final` at 960 / 1280 / 1600

**Interfaces:**
- Consumes: `Worlds.plate`, `Worlds.introOf` (Task 2); Task 3 images; `StartCountdown.phase` (Task 1).
- Produces: `IntroCard.new(level, id)` → card table `{ name, island|nil, plate|nil, look }` or nil for Flappy levels;
  `IntroCard.draw(card, t, o)` — `t` = seconds since the card appeared (keeps growing past `CARD_TIME` while waiting:
  the card stays alive); `o.waiting` = seconds past the card's normal end (nil = not waiting) → the
  "Waiting for players..." line once > 1; `IntroCard.rects(card)` → `{ name = {x,y,w,h}, island = …, plate = …,
  strip = … }` at the current `WINDOW_W/H` (one source for draw and the overlap check).
- Motion (spec + mockups): bands slide in over 0.4 s in 8-px steps (name band from the left, ~3/4 width, top third;
  island band from the right, narrower, below it), plate drops 0.2 s after into the space LEFT of the island band,
  monster runs in along the strip from the left and stops at ~1/3 width by 1.2 s, then idles; enemy idles near the
  right; after 1.2 s, every ~1.5 s the monster does a small hop or turns (alive while waiting); the bands' highlight
  row shimmers slowly. Last 0.2 s of the card phase: cut to the level (no fade needed; builder may add a stepped
  wipe).

- [ ] **Step 1: Rewrite `tarjeta`:** on entering `bosque_interruptores` the card is `{name≠nil, island≠nil,
  plate={w=1,n=3}}`; while `startPhase()=='card'` the frame draws the card and NOT the level (spy: the level renderer
  is not called); confirm / jump / pause / tap pressed during the card do not shorten it (card still shown at
  1.9 s); at 2.1 s the phase is `'count'`. Free Play `jardin_gummies`: card with no plate. `IntroCard.rects` at 960,
  1280, 1600 for the LONGEST level name in the game: no two rects overlap and all lie inside the screen
  (`lo_que_mas_largo`). Captures `intro_pradera`, `intro_nieve`, `intro_final` at the three widths.
- [ ] **Step 2: Run** `tools/tests/run.sh story_flow`; expected FAIL.
- [ ] **Step 3: Implement** `IntroCard` and hook it; remove `LevelCard` and its translation keys only if nothing else
  uses them (`levelcard.par`).
- [ ] **Step 4: Run** `tools/tests/run.sh story_flow` and `tools/tests/run.sh project_check`; look at the captures
  (Read them): bands, plate, strip and monster where the mockup put them, nothing overlapping, island colours.
- [ ] **Step 5: Commit** "Tarjeta de presentación del nivel antes de la cuenta atrás (un jugador)".

### Task 5: Online — the server waits, the card follows the server clock

**Files:**
- Modify: `server/srv/sim.lua` (`initRoomSim`: `startTicks = math.huge`, `waitSince = now`, `loaded = {}`;
  `stepRoom`: frozen while waiting), `server/srv/lobby.lua` (`on("level_loaded")`), `server/srv/broadcast.lua`
  (`game_init` sends `card`, `cd` and `start` — nil while waiting; new message `round_start {start = tick}`),
  `src/states/online/OnlineAdventureState.lua` (`_startRemaining`, `_startFrozenAhead`, card draw), 
  `src/states/online/OnlineAdventureNet.lua` (`_onGameInit` sends `level_loaded` after building the world; handler
  for `round_start`), `src/network/Protocol.lua` (VERSION 117), `version.txt`
- Test: `tools/tests/online_smoke/main.lua` (checks `espera_carga`, `tarjeta_online`), `tools/tests/README.md` row

**Interfaces:**
- Consumes: `StartCountdown.ticks(tickDt, true)`, `StartCountdown.phase`, `IntroCard` (Tasks 1, 4).
- Produces (server): `sim.loaded[pid] = true` on `level_loaded`; the wait ends when every pid in `room.playerIds` that
  is not `late` and is still connected is loaded, or 8 s after the first `level_loaded`, or 20 s after `game_init`;
  then `sim.startTicks = sim.tick + StartCountdown.ticks(TICK_DT, true)` and `round_start { start = sim.startTicks }`
  to the room. While waiting, `stepRoom` behaves exactly like today's frozen branch (inputs drained, history
  recorded); `floodT` and the level clock still count from `startTicks`.
- Produces (client): `self.startTicks = nil` while waiting (card shown, `IntroCard.draw(card, t, { waiting = … })`
  with `t` from `love.timer` only for the animation, never for timing); `_startRemaining()` → `(startTicks −
  snapBuf.clock) * TICK_DT` once known; card shown while `phase(rem) == 'card'` or waiting; `_startFrozenAhead()`
  true while waiting. `late` joiners and `game_init` with `start` already in the past: no card.

- [ ] **Step 1: Write the checks** in `online_smoke`: `espera_carga` — a second test client that delays its
  `level_loaded` by 3 s: the server's `round_start` arrives ≥ 3 s after `game_init`, and the first client's card is
  still shown (waiting) until then and the "waiting" line appears after `CARD_TIME + 1`; a client that never sends it
  → `round_start` 8 s after the first `level_loaded`; a client that disconnects during the wait → start at once.
  `tarjeta_online` — after `round_start`, the client draws the card for `CARD_TIME` (by snapshot clock), then the
  countdown as before; the player does not move during either (existing `startCd.moved` check extended to the card).
  A second `game_init` (round restart) shows the card again.
- [ ] **Step 2: Run** `tools/tests/run.sh online_smoke`; expected FAIL.
- [ ] **Step 3: Implement** server, protocol bump, client.
- [ ] **Step 4: Run** `tools/tests/run.sh online_smoke`, `online_boss`, `online_helmet`, `online_menus`; expected OK.
- [ ] **Step 5: Commit** "Online: el servidor espera a que todos carguen y la tarjeta sigue su reloj; protocolo 117".

### Task 6: Docs, full battery, release

**Files:**
- Modify: `docs/design/level-intro-card.md` (status: built), `docs/design/ux-round-2026-11.md` (item 2 replaced),
  `docs/design/README.md` (row), `docs/architecture/netcode.md` (start wait, `level_loaded` / `round_start`,
  version 117 in its history), the page that describes the start countdown (find with `grep -rl StartCountdown docs`),
  `tools/tests/README.md` (rows for the new checks), `version.txt` (if Task 5 didn't)
- [ ] **Step 1:** `tools/tests/run.sh project_check`; expected OK.
- [ ] **Step 2:** `tools/tests/run.sh all` in the background; expected `TODO OK` (re-run a lone `online_*` failure
  once before treating it as real).
- [ ] **Step 3:** commit (Spanish, `git -c core.fileMode=false`, never `tools/deploy_server.sh`), `git fetch`, check
  `git log HEAD..origin/master`, push. The server is deployed by the user from Linux.
