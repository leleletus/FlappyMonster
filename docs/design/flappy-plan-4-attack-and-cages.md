# Flappy campaign — Plan 4: charge, special attack, cages, special obstacles, food, HUD (implementation plan)

<!-- project_check: future-paths (this plan names files that do not exist yet) -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flappy stages get their own play layer: charge items fill a meter, the SPECIAL ATTACK spends it as a burst of
flap magic, CAGES (caged flappies, saved only when the stage is finished) and CRACKED WALLS open with enough charge,
zone food heals, and a Flappy HUD shows HP, lives and charge.

**Architecture:** Everything lives in the shared simulation's base pieces (golden rules 1–2): the charge and the burst
are player state (`PlayerFlight.lua`), the hit is a generic entity hook `onSpecialHit(power, pa)` (default: nothing;
enemies die; `Boss` takes `power` damage, ready for Plan 5's machines), the charge item is a pickup field. Cages and
walls are new Flappy-only entity types. Rescued cages travel like `taken` extra lives: recorded by `AdventureState`,
saved by `FlappyRun.complete`, passed back so freed cages stay open.

**Tech Stack:** LÖVE 11.x, Lua; harnesses via `tools/tests/run.sh`; art generators in Python (`/usr/bin/python3`, Pillow).

**Spec:** [flappy-prequel](flappy-prequel.md) (§ Gameplay, Damage to bosses, Collectible: caged flappies), roadmap row 4
in [flappy-prequel § Plans](flappy-prequel.md#plans). System page: [flappy-campaign](../gameplay/flappy-campaign.md).

**Not in this plan (and why):** return-to-sender shots and the controlled charge drops inside boss fights need the Evil
Monster's machines (Plan 5); power-ups and the cage → power-up reward are Plan 4b; the reward for ALL cages stays
PENDING (the user).

## Global Constraints

- Golden rules 1 (shared simulation: no `love.graphics` / real `Input` / real `Sound` outside render), 2 (base, not
  copies), 3 (catalogs as data; new ids never renamed), 4 (every image and sound is a real asset file; generators are
  fine when their output is committed), 6 (no wings), 7 (nothing gained in a stage saved before it is finished).
- Flappy-only content (`flappyOnly`) never appears in Adventure levels: palette hidden + `Model:validate` error.
- Charge: integer `0..CHARGE_MAX` with `CHARGE_MAX = 5`; one item = +1; firing spends ALL; power = charge spent;
  charge does not carry between stages (a new player per stage already resets it).
- Special attack input: action `special` — keys `x`, `k`; pad `button:rightshoulder`; touch: an extra button above
  the jump button (the slot the flashlight uses). `button:leftshoulder` stays free for Plan 4b's quick wheel.
- Sounds: reuse existing sound files (`oneUp`, `checkpoint`, `gpStart`, `breakBlock`-style ids found in
  `src/audio/Sound.lua`); new dedicated sounds are not part of this plan.
- Spanish code comments / commits, English docs; `version.txt` bump per pushed commit; no `Protocol.VERSION` change
  (Flappy levels are not online; the input stub gains `special_pressed` locally only).

## Review Focus

1. **Firing with no charge** — nothing happens (no burst, no sound spam, no state change). Test in Task 3.
2. **A cage freed, then the player dies or leaves before the finish** — it is NOT saved; replaying, it is closed again;
   only after a finished stage does it start open. Test in Task 4.
3. **A burst meeting terrain** — solid tiles stop it, pillars (not solid) do not, a cracked wall it cannot break absorbs
   it. Test in Task 3 / Task 5.
4. **Walls never trap the player** — every stage keeps an open route without breaking anything: the `etapa`-style bot
   clears both Valley stages with zero charge. Test in Task 6.
5. **Touch layout** — the special button never overlaps the D-pad or the jump button at the 8 `touch_layout` sizes.
   Test in Task 7.

---

### Task 1: Flappy-only entities

**Files:**
- Modify: `src/world/entities/EntityTypes.lua` (document + keep `flappyOnly` on the type), `src/editor/EditorPalette.lua`
  (entities filtered like tiles), `src/editor/EditorModel.lua` (`validate`: an entity whose type is `flappyOnly` in a
  non-Flappy level = error, same message style as the pillar one)
- Test: `tools/tests/flappy_flight/main.lua` case `exclusivo` (extended)

**Interfaces:** Produces: type field `flappyOnly = true` honoured for entities exactly as for tiles.

- [ ] **Step 1:** Extend `exclusivo`: a model with a placement of a registered test type marked `flappyOnly` (use the
  `cage` type name — it does not exist yet, so for this task register a throwaway type inside the harness with
  `EntityTypes.register{ name = '_t_flappy', flappyOnly = true, class = <minimal Entity.extend> }`) → 1 error in a
  normal level, 0 in a Flappy one.
- [ ] **Step 2:** Run `run.sh flappy_flight CASE=exclusivo` → FAIL.
- [ ] **Step 3:** Implement the palette filter and the validate rule.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `Flappy: entidades exclusivas de Flappy (paleta y validación del editor)`.

### Task 2: Charge and the charge item

**Files:**
- Create: `src/world/entities/types/items/flapcharge.lua` (type `flapcharge`, label "Carga de aleteo", category
  `Flappy`, `flappyOnly`, `pickup = { charge = 1, score = 50 }`), its art `assets/images/items/flapcharge.png` from a new
  `tools/art/items/make_flappy_items.py` (a small swirl of flap magic, no wings; 16×16 ×4), name added to the entity list
- Modify: `src/world/entities/base/Interactions.lua` (`pickupEffect`: `pk.charge` → `pa.charge = min(CHARGE_MAX,
  pa.charge + pk.charge)`), `src/player/PlayerAdventure.lua` (`charge = 0` in `new` only: respawning keeps the charge), `src/player/PlayerFlight.lua` (`PlayerAdventure.CHARGE_MAX = 5`)
- Test: `flappy_flight` case `carga`

**Interfaces:** Produces: `pa.charge` (integer), `PlayerAdventure.CHARGE_MAX`.

- [ ] **Step 1:** Case `carga`: a stage with 6 `flapcharge` in a row at the player's height; flying through them →
  `pa.charge == 5` (capped); dying and respawning keeps it.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement; generate the sprite; register the type.
- [ ] **Step 4:** Run → PASS; `run.sh enemy_data` (catalog check) → TODO OK.
- [ ] **Step 5:** Commit `Flappy: la carga de aleteo (objeto y medidor del jugador)`.

### Task 3: The special attack

**Files:**
- Modify: `input.lua` (action `special` as in Global Constraints; label for hints), `src/network/Protocol.lua`
  (`newInputStub`: `special_pressed`, read by `pressed('special')`), `src/player/PlayerFlight.lua` (fire + bursts),
  `src/player/PlayerRender.lua` (draw bursts), `src/world/entities/base/Entity.lua` (`Entity:onSpecialHit(power, pa)`
  default: enemies of category `Enemigos` that are not bosses die with `dieFling(1)` and return true; others return
  false), `src/world/entities/base/Boss.lua` (`Boss:onSpecialHit(power)` → `self:damage(power, 'special')` when
  vulnerable, returns true)
- Create: `assets/images/fx/flapburst-Sheet.png` (from `make_flappy_items.py`)
- Test: `flappy_flight` case `ataque`

**Interfaces:**
- Consumes: `pa.charge` (Task 2).
- Produces: `pa.bursts = { { x, y, power, dist }, ... }` (simulation state; drawn by `PlayerRender`), constants
  `BURST_SPD = 900` px/s, `BURST_RANGE = 8` tiles; `Entity:onSpecialHit(power, pa) -> absorbed:boolean`.
- Rule: pressing `special` with `charge > 0` adds one burst at the player's front (`x + OUTER_W/2`, `y`) with
  `power = charge`, sets `charge = 0`, plays a sound. Each step a burst moves right by `BURST_SPD * dt`; it ends at
  `BURST_RANGE` tiles, on a SOLID tile (`level:collisionAt`), or when an entity whose outer box it overlaps returns
  `true` from `onSpecialHit` (each entity is hit once per burst). Pillars (`collision = 'none'`) do not stop it.

- [ ] **Step 1:** Case `ataque`: with `charge = 0`, pressing special changes nothing (Review Focus 1); with
  `charge = 3`: one burst, charge 0; a Gummy 4 tiles ahead dies; a burst with a solid block 3 tiles ahead ends there;
  a pillar between does not stop it.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → PASS; `run.sh mechanics` → TODO OK (base `Entity` change).
- [ ] **Step 5:** Commit `Flappy: el ataque especial (ráfaga de magia de aleteo) y el gancho onSpecialHit`.

### Task 4: Caged flappies

**Files:**
- Create: `src/world/entities/types/items/cage.lua` (type `cage`, "Flappy enjaulado", category `Flappy`,
  `flappyOnly`; prop `minCharge` 1..5 default 1; states `closed` / `open` / `empty` (already freed in a finished run);
  `onSpecialHit(power)`: `closed` and `power >= minCharge` → `open` (the flappy flies off upward and leaves), sets
  `self.rescuedNow = true`, returns true; otherwise returns true without opening (absorbs)), art
  `assets/images/items/cage-Sheet.png` (closed with a small flappy of another colour inside, open, empty) from
  `make_flappy_items.py`
- Modify: `src/states/adventure/AdventureState.lua` (`args.rescued` = `{ [placement] = true }` → those cages start
  `empty`; on finish `result.rescued` = placement indices of cages with `rescuedNow`, the same way `taken` works),
  `src/flappy/FlappyRun.lua` (`complete` stores `d.rescued[id][i] = true`), `src/flappy/FlappySave.lua` (`rescued = {}`
  in `new` and `load`, `VERSION = 2`), `src/states/flappy/FlappyMapState.lua` (passes `rescued`; the card shows
  `flappy.map_cages` "Flappies: {n}/{m}" when the stage has cages)
- Test: `flappy_flight` case `jaula`, `flappy_campaign` case `jaulas`

**Interfaces:** Produces: `result.rescued` (list of placement indices), `FlappySave` field `rescued[stage] = { [i] = true }`,
`FlappyRun.rescuedCount(id) -> freed, total`.

- [ ] **Step 1:** `jaula`: a cage `minCharge = 2` hit with power 1 stays closed and absorbs; with power 3 opens.
  `jaulas`: `complete` with `result.rescued = { 1 }` stores it; a result without `rescued` (left halfway) stores
  nothing (Review Focus 2); `rescuedCount` reports it.
- [ ] **Step 2:** Run both → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → PASS; `menu_flow` → TODO OK.
- [ ] **Step 5:** Commit `Flappy: flappies enjaulados (se guardan al terminar la etapa)`.

### Task 5: Cracked walls (special obstacles)

**Files:**
- Create: `src/world/entities/types/mechanisms/crackwall.lua` (type `crackwall`, "Muro agrietado", category `Flappy`,
  `flappyOnly`; props `minCharge` 1..5 default 2, `rows` 1..9 default 3; a SOLID body like the door
  (`isSolidBody`); `onSpecialHit(power)`: `power >= minCharge` → breaks (debris fx, sound, no longer solid), returns
  true either way), art `assets/images/world/flappy/crackwall.png` from `make_flappy_items.py`
- Test: `flappy_flight` case `muro`

- [ ] **Step 1:** `muro`: flying into an intact wall stops the player (solid); a burst with power below `minCharge`
  does not break it and stops; with enough power it breaks and the player flies through.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS; `door_rules` → TODO OK.
- [ ] **Step 5:** Commit `Flappy: muros agrietados (se rompen con carga suficiente)`.

### Task 6: Zone food and the Valley stages populated

**Files:**
- Modify: `src/flappy/Zones.lua` (zone field `food = 'valle'`), `src/world/entities/types/items/apple.lua` (skin
  `valle` in `FILES`; in a Flappy level `auto` resolves to the zone's food through `Zones.find` of the level's file name,
  else the island rule as today), `tools/art/world/make_food_sprites.py` (+ `valle`: a peach) →
  `assets/images/items/food_valle.png` (check `docs/art/generators.md` hand-edited list first: `apple.png` is the
  user's and must not be regenerated), `tools/levelgen/flappy_lib.py` (`write(..., entities=)`),
  `tools/levelgen/levels_flappy_valle.py` (each stage: 4–6 charge items, 1 cage on a risky line, 1 cracked wall
  hiding a shortcut with a charge item behind it, 2 food; the main route always open)
- Test: `flappy_campaign` case `zonas` (extended: each Valley stage has ≥ 1 cage and ≥ 3 charge items), `flappy_flight`
  case `etapa` extended to also run both Valley stages with the zero-charge bot (Review Focus 4)

- [ ] **Step 1:** Extend the two cases. **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement; regenerate the two stages (`levels_flappy_valle.py` only writes its two files).
- [ ] **Step 4:** Run → PASS; `run.sh level_check -- assets/levels/valle_pilares_*.json` → TODO OK;
  `run.sh docs_reference`.
- [ ] **Step 5:** Commit `Flappy: comida de zona y etapas del Valle con carga, jaula y muro`.

### Task 7: Flappy HUD and the touch button

**Files:**
- Create: `src/ui/FlappyHud.lua` (`FlappyHud.draw(pa, lives)`: HP pips, the charge meter of `CHARGE_MAX` cells, lives;
  layout computed at draw time, rule 9), art `assets/images/ui/flappy/hud-Sheet.png` (heart full / empty, charge cell
  full / empty, 16×16 each) from `tools/art/ui/make_flappy_hud.py`
- Modify: `src/states/adventure/AdventureState.lua` (in a Flappy level: `FlappyHud.draw` instead of the HP bar of
  `BossHud.drawPlayers`; score and time stay), `src/ui/TouchControls.lua` (`TC.update(active, extra)` where
  `extra = 'light' | 'special' | nil`; the special button uses the light button's slot and a new frame of
  `assets/images/ui/touch/` from `tools/art/ui/make_sprites.py`), `src/states/online/OnlineAdventureState.lua` (passes
  `'light'` as before)
- Test: `touch_layout` (special button inside the screen, no overlap, 8 sizes — Review Focus 5), `menu_flow` `vuelo`
  capture shows the Flappy HUD

- [ ] **Step 1:** Extend `touch_layout` with the special button. **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement HUD, art, touch button. **Step 4:** Run `touch_layout`, `menu_flow` → TODO OK; look at
  `menu_flight.png` (HUD readable, nothing overlapping).
- [ ] **Step 5:** Commit `Flappy: HUD propio (vida, vidas, carga) y botón táctil del ataque especial`.

### Task 8: Docs, battery, release

- [ ] Update [flappy-campaign](../gameplay/flappy-campaign.md) (charge, attack, cages, walls, food, HUD, saves v2),
  [player](../gameplay/player.md#flight-flappy-levels) (charge, bursts), [entities overview](../entities/overview.md)
  (`onSpecialHit`), [save-data](../architecture/save-data.md) (`rescued`), [pickups](../gameplay/pickups.md) (`charge`,
  Valley food), [generators](../art/generators.md) (new generators), `tools/tests/README.md`, roadmap row 4 in
  [flappy-prequel](flappy-prequel.md#plans).
- [ ] `run.sh project_check`, `run.sh docs_reference`, `run.sh all` → only the known failures.
- [ ] Bump `version.txt`, commit, fetch / check, push; deploy from Linux (memory). Hand-off: what only a person can
  judge (the feel of the burst, the charge balance, how the cage / wall / food / HUD look, the touch button on a phone).
