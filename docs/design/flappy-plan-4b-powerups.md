# Flappy campaign — Plan 4b: power-ups, inventory and the quick wheel (implementation plan)

<!-- project_check: future-paths (this plan names files that do not exist yet) -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flappy slots keep an inventory of power-ups (6 in total, 3 per type) that caged flappies give; in any stage
the player opens the QUICK WHEEL (the game freezes) and spends one: shield, extra heart, strength, the three magnets,
small, ghost.

**Architecture:** The catalog is data (one file per power-up + a list, golden rule 3). Effects live in the player base
(an `effects` table with timers, the shield in the one hurt / die path, the magnets as a pull in the shared update:
golden rules 1–2). The inventory is per slot in the Flappy save; SPENDING writes the save at once (the one exception to
rule 7, decided by the user), GAINING (a cage) only when the stage is finished. The wheel is a state pushed over
`AdventureState`, like the pause, so the level is frozen while it is open.

**Tech Stack:** LÖVE 11.x, Lua; harnesses via `tools/tests/run.sh`; art generators in Python (`/usr/bin/python3`, Pillow).

**Spec:** [powerups](powerups.md) (rules, catalog, strength and the special attack, several at once, the wheel, getting
them, built how) and [flappy-prequel](flappy-prequel.md); roadmap row 4b in [flappy-prequel § Plans](flappy-prequel.md#plans).

**Not in this plan (and why):** map shops and the points wallet (Plan 5, with the zone map's art); Adventure's inventory
and the `big` power-up (after the campaign, with Adventure's own plan); power-ups online (off in the first version);
the reward for freeing ALL cages (still pending: the user).

## Global Constraints

- Values from [powerups](powerups.md), verbatim: capacity **6 in total, at most 3 per type**; inventory **per slot**;
  using = spent at once, even if the player then dies or quits; durations `strength` 12 s, `magnet_*` 20 s (radius
  about 4 tiles), `small` 15 s (half-size hitbox and sprite), `ghost` 12 s (passes pillars and zone obstacles, NOT
  machines, shots or bosses; if it ends inside a pillar: a short invulnerability instead of a hit), `heart` +1 max HP for
  the rest of the stage (stacks), `shield` absorbs the next hit of any kind incl. spikes, lava, drowning — **not pits /
  being left behind** (forced deaths).
- Several at once: different types run together; the same timed type restarts its timer; a second `shield` cannot be
  used while one is up; no magnet while `magnet_all` runs — the wheel greys those out (never wasted by mistake).
- Strength: multiplies the damage the monster DEALS (the special attack's damage to bosses, ×2); it does NOT change the
  charge a cage or wall needs.
- Wheel: freezes the game in single player; same order always (catalog order); PC: hold `Q` or `Tab`, point with mouse
  or arrows / WASD, release to use, release with nothing chosen / `Esc` cancels; keys `1`–`6` use the type in that wheel
  position directly; pad: hold `L` (`button:leftshoulder`), point with the left (or right) stick, release over a
  segment; touch: the BAG button in the top HUD band, tap a segment (or hold the bag, slide, lift), tap the centre /
  outside to cancel. A setting "wheel: hold / toggle" for accessibility.
- Cages give a power-up (`gift` prop, chosen by the designer); a cage gives it once per slot; if the inventory is full
  it is let go with a notice on the results screen (*plan simplification of "offer a swap": recorded for the user*).
- Golden rules 1, 2, 3, 4 (every icon / bubble a real asset), 6 (no wings), 7 (gaining saved on finish), 9.
- Spanish code comments / commits, English docs; bump `version.txt` per pushed commit; no `Protocol.VERSION` change.

## Review Focus

1. **Spending then dying or quitting** — the power-up stays spent (save written at use). Test in Task 3.
2. **Using a greyed-out power-up** (second shield, magnet under `magnet_all`) — refused, nothing spent. Test in Task 3.
3. **Shield vs forced death** — falling behind the auto-scroll (forced) still kills and the shield stays; a pillar hit is
   absorbed. Test in Task 2.
4. **The wheel and the pause / game over** — opening the wheel while dying or at the finish does nothing; pausing is not
   possible while the wheel is open; closing returns to the exact frame. Test in Task 3.
5. **A full inventory and a cage** — finishing the stage with a full inventory keeps the inventory unchanged and marks
   the cage freed (it does not give again later). Test in Task 4.

---

### Task 1: The catalog and the inventory

**Files:**
- Create: `src/world/powerups/Powerups.lua` (registry: `LIST` in catalog order, `get(id)`, `forMode(mode)`), one file per
  power-up in `src/world/powerups/` (`shield`, `heart`, `strength`, `magnet_points`, `magnet_items`, `magnet_all`,
  `small`, `ghost`), each `{ id, modes = { 'flappy', ... }, duration = s|nil, icon = frame, sound = id }`; art
  `assets/images/ui/powerups/icons-Sheet.png` (8 icons, 16×16) from a new `tools/art/ui/make_powerups.py`
- Modify: `src/flappy/FlappySave.lua` (`VERSION = 3`, `inventory = {}` in `new` and `load`), `src/flappy/FlappyRun.lua`
  (`addPowerup(id) -> 'ok' | 'full' | 'type_full'`, `spendPowerup(id) -> boolean` (writes the save), `inventoryCount()`),
  lang keys `powerup.<id>` + `powerup.<id>.desc` (es / en)
- Test: `flappy_campaign` case `inventario`

**Interfaces:** Produces `Powerups.LIST`, `Powerups.get(id)`, `Powerups.forMode('flappy')` (the 8 above minus none),
`FlappyRun.addPowerup / spendPowerup / inventoryCount`, `FlappyRun.MAX_TOTAL = 6`, `FlappyRun.MAX_TYPE = 3`.

- [ ] **Step 1:** `inventario`: 3 shields → a 4th is `'type_full'`; then 3 hearts (6 in total) → a strength is
  `'full'`; `spendPowerup('shield')` → true and the file already has 2 shields; spending a missing id → false; a v2
  save loads with `inventory = {}`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement (catalog, icons, save, run). **Step 4:** Run → PASS;
  `run.sh project_check` (new lang keys).
- [ ] **Step 5:** Commit `Power-ups: catálogo como datos e inventario por partida (6 en total, 3 por tipo)`.

### Task 2: Effects in the player base

**Files:**
- Modify: `src/player/PlayerAdventure.lua` (`usePowerup(id) -> boolean` = `canUse` then apply; `canUse(id)`;
  `effects = {}` timers ticked in `_update`; `shield` absorbed in `takeDamage`/`hurt` and in `die` when not `force`;
  `hpMax` + 1 for `heart`; `damageMult()` = 2 with strength), `src/player/PlayerFlight.lua` (`small`: half hitbox via the
  existing size path; `ghost`: pillar `contact` ignored, and on expiry inside one a 1 s invulnerability),
  `src/world/entities/base/Boss.lua` (`onSpecialHit(power, pa)` multiplies by `pa:damageMult()`), a magnet pull in the
  shared update (pickups within 4 tiles move toward the player: points = pickups with only `score`; items = `lives`,
  `heal`, `charge`; all = both), `src/player/PlayerRender.lua` (shield bubble, small / ghost looks), art
  `assets/images/fx/shield-Sheet.png` from `make_powerups.py`
- Test: `flappy_flight` case `powerups`

- [ ] **Step 1:** `powerups`: shield absorbs one pillar hit (HP unchanged, shield gone, a second hit costs HP); shield +
  falling behind the auto-scroll → dies, shield kept (Review Focus 3); heart → `hpMax` 4, `hp` +1; strength → a boss
  stub hit by a power-3 burst takes 6 while a cage with `minCharge` 4 does NOT open with power 3; magnet_items pulls a
  `flapcharge` 3 tiles away within 1 s, magnet_points does not; small → outer box half; ghost → flies through a pillar
  with HP unchanged, and ending inside one gives invulnerability, not damage; `canUse('shield')` false while shielded,
  `canUse('magnet_points')` false under `magnet_all`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS; `run.sh mechanics`, `run.sh sp_boss` (rc 0).
- [ ] **Step 5:** Commit `Power-ups: efectos en el jugador (escudo, corazón, fuerza, imanes, pequeño, fantasma)`.

### Task 3: The quick wheel

**Files:**
- Create: `src/states/adventure/WheelState.lua` (state `powerup_wheel`, pushed over `AdventureState`; one layout
  function for drawing, mouse and touch; segments = the types the slot holds, catalog order, icon + ×N, greyed when
  `not pa:canUse(id)`; choosing calls `FlappyRun.spendPowerup(id)` and `pa:usePowerup(id)` and pops), art for the bag
  button and the ring plate `assets/images/ui/powerups/wheel.png`, `bag-Sheet.png` from `make_powerups.py`
- Modify: `input.lua` (actions `wheel` = `key:q`, `key:tab`, `button:leftshoulder`; `wheel_1`..`wheel_6` = keys `1`..`6`;
  `Input.stick() -> x, y` of the active pad's left stick, falling back to the right stick), `src/states/adventure/
  AdventureState.lua` (in a Flappy campaign stage — `args.powerups = true` from `FlappyMapState` — `wheel` pressed opens
  it when alive and not finished; `wheel_n` uses directly; the bag button on touch), `src/ui/TouchControls.lua` or
  `FlappyHud` (the bag button rect in the top band, `FlappyHud.bagRect()`), `src/core/Settings.lua` + the settings screen
  (`wheelToggle` false / true), lang keys
- Test: new harness `powerup_wheel` (runs the real game states: open → frozen (player position unchanged over 1 s) →
  choose shield → inventory −1 in the file, `pa.shield`; greyed segment does nothing (Review Focus 2); cancel spends
  nothing; `wheel_2` key uses the 2nd type directly; opening while dying / after the finish does nothing; spend then die
  → still spent (Review Focus 1); touch: tapping the bag opens it, tapping a segment uses it; captures at 960 / 1280 /
  1600) and its row in `tools/tests/README.md` and `run.sh`'s LIST

- [ ] **Step 1:** Write the harness. **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS; look at the
  captures; `menu_flow`, `touch_layout` → TODO OK.
- [ ] **Step 5:** Commit `Power-ups: la rueda rápida (congela; PC, mando y táctil; atajos 1–6)`.

### Task 4: Cages give power-ups; HUD shows effects

**Files:**
- Modify: `src/world/entities/types/items/cage.lua` (prop `gift`: a power-up id of mode `flappy`, default `shield`),
  `src/flappy/FlappyRun.lua` (`complete`: for each newly rescued cage, `addPowerup(gift)`; a result `'full'` /
  `'type_full'` goes into `summary.lostGifts`), `src/states/story/StoryResultsState.lua` (a line per gift won / lost),
  `src/ui/FlappyHud.lua` (active effects: icon + seconds left; the shield as an icon while up),
  `tools/levelgen/flappy_lib.py` + `levels_flappy_valle.py` (each cage's `gift`: stage 1 `shield`, stage 2 `heart`)
- Test: `flappy_campaign` case `regalos` (a finished stage with its cage rescued adds its gift; finishing again does not
  give it again; with a full inventory the gift is listed in `lostGifts` and the cage still counts as freed —
  Review Focus 5); the deferred Plan 4 minor: `jaulas` uses the REAL cage placement index of `valle_pilares_1`

- [ ] **Step 1:** Write / tighten the cases. **Step 2:** Run → FAIL. **Step 3:** Implement; regenerate the two stages.
  **Step 4:** Run → PASS; `level_check` on both stages; `docs_reference`.
- [ ] **Step 5:** Commit `Power-ups: los flappies enjaulados regalan uno; el HUD muestra los efectos`.

### Task 5: Docs, battery, release

- [ ] New system page `docs/gameplay/powerups.md` (what · files · data · SP / server / client · how to add a power-up ·
  tests · decisions) + a line in `docs/README.md`; mark what is built in [powerups](powerups.md); update
  [flappy-campaign](../gameplay/flappy-campaign.md), [player](../gameplay/player.md), [save-data](../architecture/save-data.md)
  (inventory, v3), [platforms](../architecture/platforms.md) (the bag button), `tools/tests/README.md`, the roadmap.
- [ ] `run.sh project_check`, `run.sh docs_reference`, `run.sh all` → only the known failures.
- [ ] Bump `version.txt`, commit, fetch / check, push; deploy from Linux. Hand-off: what only a person can judge (the
  wheel on a phone and on the Switch, whether freezing breaks Flappy's pace, durations, the icons and the bubble).
