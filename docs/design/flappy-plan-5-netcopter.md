# Flappy campaign — Plan 5: the Net-Copter, the Valley's boss (implementation plan)

<!-- project_check: future-paths (this plan names files that do not exist yet) -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** zone 1 ends with its first boss: the **Net-Copter** (Redcóptero), a junk machine the Evil Monster pedals
among the pillars. It is beaten by **return to sender** (glowing bombs hit while rising fly back) and by the **special
attack**, with charge and food handed out in a controlled way during the fight.

**Architecture:** the boss is a Lua boss on the `Boss` base inside a normal boss zone at the end of an auto-scroll
Flappy stage (the auto-scroll stops at the arena, the zone locks the camera; after the fight the player flies to the
finish). Return to sender is a GENERIC trait (`reflectable`) handled in the shared interaction path, not inside the
boss. The controlled drops extend the existing `bossdrops` director (golden rule 2) with a `charge` kind and a
Flappy-level rule set. Single player only (Flappy levels are not online).

**Tech Stack:** LÖVE 11.x, Lua; harnesses via `tools/tests/run.sh`; art generator in Python (`/usr/bin/python3`, Pillow).

**Spec:** [flappy-prequel](flappy-prequel.md) (§ The story, § Damage to bosses), roadmap row 5 in
[flappy-prequel § Plans](flappy-prequel.md#plans). Recipe: [how-to-add-a-boss](../bosses/how-to-add-a-boss.md) (read
it first; its checklist applies). System pages: [flappy-campaign](../gameplay/flappy-campaign.md),
[bosses/system](../bosses/system.md).

**The user's decisions (2026-11-08):** the Net-Copter as proposed (below). Boss music: every Flappy boss uses the track
`tuffi` until Flappy bosses get music of their own; `tuffi` is really the FINAL battle's theme and may later be reworked
with Evil Monster motifs.

**Not in this plan:** the Valley background, the real stages, the map art, the shops and the wallet (**Plan 5b**); the
reward for ALL cages (still PENDING, the user).

## The boss (the design, 10 lines)

1. **Moves:** hovers in the right third of the arena, following the player's height loosely (lag ~0.8 s), never
   leaving the zone. Phase 2: lower and faster.
2. **Net shot** (phase 1+): the cannon glows 0.6 s (telegraph + sound), then a net flies left at the player's height
   at the moment of firing. Hit: 1 HP + `ctrlLock` 0.4 s (`Boss.strike`). From phase 2: a spread of 3 nets.
3. **Glowing bomb** (every ~6 s at Normal): dropped from the gondola, falls slowly with a lit fuse (2.5 s). Touched
   by a RISING flying player → flies back to the machine: **2 damage**. Touched while falling, or the fuse runs out
   → explodes (1 HP in a radius of 1 tile).
4. **Claw sweep** (phase 2): a flashing line marks a row band for 0.8 s, then the claw arm crosses the arena on it
   (2 HP). Dodge by changing height.
5. **Vulnerable:** always while active (no stun windows: the monster cannot stomp here). `Boss.INV_TIME` after each
   hit. Body contact: 1 HP and a push left; it is never stomped (`interact` returns nil; contact via `Boss.strike`).
6. **Health:** `hp` 12 for 1 player (`bossHp` modifier applies). Phase 2 at ≤ 50 %: the balloon pops.
7. **Intro** (~3.5 s): the Evil Monster pedals in from the right, laughs, the net cannon unfolds.
8. **Death:** explosions (generic hold), the balloon and cannon fall apart, and the Evil Monster **flees** off the right
   edge pedalling a broken propeller — it does NOT die (it returns at every zone; lore).
9. `rollStart(r)`: randomizes the first net timer, the first bomb timer and the start height.
10. Damage to players: net 1, bomb 1, claw 2, body 1.

## Global Constraints

- Golden rules 1–4, 6 (no wings, on the monster OR the Evil Monster), 7 (nothing from the fight saved before the stage
  is finished).
- New ids, stored and never renamed: entity types `netcopter`, `glowbomb`, `netshot`; stage `valle_redcoptero`
  (`Zones.LIST[1].boss`). All Flappy-only (`flappyOnly`, category Flappy).
- Boss zone music: `"music": "tuffi"`.
- Art: [pixel-density](../art/style-rules.md) — one pixel size for all sprites; the Evil Monster on the SAME 26x21 grid
  as `assets/images/bosses/miniboss1/monster/Idle1.png` (extend, do not redesign); the machine big with few art pixels
  (×6), never fine detail. Previews to `/home/mtvemo/FlappyMonster_pruebas/redcoptero/vista_previa.png`, applied only
  after the user's verdict. Check the hand-edited list in [generators](../art/generators.md) before writing anything
  under `miniboss1/`.
- Sounds: reuse existing ids from `src/audio/Sound.lua` (`bossHurt`, explosions, a laugh); new sounds are not part of
  this plan.
- Spanish comments / commits, English docs; `version.txt` + 1 per pushed commit; no `Protocol.VERSION` change (not online).

## Review Focus

1. **Return to sender from the side or from above** (the player not rising, `vy >= 0`) — the bomb explodes and hurts;
   it never reflects. Test in Task 2.
2. **A reflected bomb that misses** (the boss moved) — it leaves the arena or hits a solid tile and explodes harmlessly
   for the player; it never comes back. Test in Task 2.
3. **No charge for a long time** — the director's pity rule drops a charge within `PITY_T`; there is never more than
   one charge item in the arena at once. Test in Task 3.
4. **Dying during the fight** — the player respawns inside the arena (boss zone respawn), the boss keeps its HP, the
   charges and bombs on screen do not duplicate. Test in Task 5.
5. **After the fight** — walls drop, the player can fly right to the finish with the auto-scroll stopped, and the
   stage completes with `onFinish`. Test in Task 5.

---

### Task 1: Art — the Evil Monster and the Net-Copter (preview, then the user's verdict)

**Files:**
- Create: `tools/art/bosses/make_netcopter.py` (`--apply` writes; without it only the preview)
- Create (on `--apply`): `assets/images/bosses/netcopter/` — `machine-Sheet.png` (balloon + gondola + propeller, 2
  frames), `machine_popped-Sheet.png` (phase 2, 2 frames), `cannon-Sheet.png` (idle, glow), `claw.png`,
  `pilot-Sheet.png` (the Evil Monster pedalling: 2 frames, laugh, hurt), `pilot_flee-Sheet.png`, `net.png`,
  `bomb-Sheet.png` (fuse 2 frames), `parts.png` (pieces that fly off)

- [ ] **Step 1:** write the generator: the pilot derived from `miniboss1/monster/Idle1.png`'s grid (26x21, same colours);
  the machine as junk (patched balloon, wooden gondola, a bicycle-pedal propeller), 2–3 tones per part.
- [ ] **Step 2:** run it; it writes the preview (all frames side by side at game scale on the Valley sky colour).
- [ ] **Step 3: STOP — show the preview to the user and wait for the verdict.** Tasks 2–4 do not need the art (they
  use `debugColor` boxes) and may proceed meanwhile. Apply (`--apply`) only after the verdict.
- [ ] **Step 4:** commit the generator and, after the verdict, the applied PNGs; add the generator to
  [generators](../art/generators.md).

### Task 2: Return to sender — the `reflectable` trait and the `glowbomb`

**Files:**
- Modify: `src/world/entities/base/Interactions.lua` (the shared player ↔ entity path), `src/world/entities/EntityTypes.lua`
  (document the trait)
- Create: `src/world/entities/types/traps/glowbomb.lua`
- Test: new harness `tools/tests/netcopter_rules/` + its row in `tools/tests/README.md`

**Interfaces:**
- Produces: entity field `reflectable = true`; hook `Entity:onReflect(pa)` (default nil). `Interactions` calls it when
  a FLIGHT player (`pa.flight`) overlaps the entity with `pa.vy < 0`; otherwise the entity's normal `interact`.
- Produces: `glowbomb` — props `owner` (the boss entity, set on spawn), `fuse` (s, default 2.5), `fall` (px/s, 90).
  States `falling → returning → exploding`. `returning`: flies to `owner`'s centre at 700 px/s; on overlap
  `owner:damage(2, 'reflect')` then explodes; a solid tile or leaving the zone → explodes without hurting anyone.
  Exploding: `Explosions.blast` with radius 1 tile, 1 HP to players (not when it was returning).

- [ ] **Step 1: failing tests** in `netcopter_rules`, cases: `rebote` (player flying with `vy = -300` touches a falling
  bomb → state `returning`; a dummy `Boss` 3 tiles right loses 2 HP), `de_lado` (`vy = 0` → explodes, player loses 1
  HP), `falla` (owner moved out of the path → the bomb ends at a solid tile, player HP unchanged, bomb gone),
  `mecha` (untouched for 2.5 s → explodes).
- [ ] **Step 2:** `tools/tests/run.sh netcopter_rules` → FAIL (type missing).
- [ ] **Step 3:** implement the trait in `Interactions` and `glowbomb.lua`.
- [ ] **Step 4:** `tools/tests/run.sh netcopter_rules` → every case OK; `tools/tests/run.sh flappy_flight` still OK.
- [ ] **Step 5:** commit.

### Task 3: Controlled charge and food in Flappy boss fights (`bossdrops`)

**Files:**
- Modify: `src/world/entities/types/directors/bossdrops.lua`
- Test: `netcopter_rules` (new cases)

**Interfaces:**
- Consumes: `flapcharge` (Plan 4), `apple` with skin `auto` (the zone food).
- Produces: in a level with `level.flappy`, at EVERY difficulty, the director runs a Flappy rule set:
  `Drops.POOL.charge = 1` (at most one charge item in the zone at once); `Drops.FLAPPY_CHARGE = { easy = 6, normal = 8,
  hard = 10 }` s between charges; `Drops.PITY_T = 12` (all players in the zone at 0 charge that long → one now, ignoring
  the timer); food with `Drops.FLAPPY_FOOD = { easy = 10, normal = 14, hard = 18 }` under the existing "when it is
  needed" rules. Position: a free AIR cell of the zone (no solid tile, no pillar), ≥ 4 tiles from the boss, 2–6 tiles
  from the player who needs it; items appear in place (no `skyfall`) and float.

- [ ] **Step 1: failing tests**, cases: `cargas` (a fake Flappy arena: in 30 s simulated at Normal, charges appear,
  never two at once), `lastima` (player at 0 charge, timer far → a charge within `PITY_T` + 1 s), `aire` (every
  dropped item's cell is not solid and not a pillar), `aventura` (a non-Flappy boss level: no charge ever).
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** implement in `bossdrops.lua` (Flappy branch next to the event branch; no copy of its "needed" logic).
- [ ] **Step 4:** `run.sh netcopter_rules` OK; `run.sh boss_sim` OK (Adventure bosses unchanged).
- [ ] **Step 5:** commit.

### Task 4: The `netcopter` boss and its `netshot`

**Files:**
- Create: `src/world/entities/types/bosses/netcopter.lua`, `src/world/entities/types/traps/netshot.lua`
- Create: `tools/levelgen/arenas/NetcopterArena.json` (a Flappy test arena: flight, boss zone with music `tuffi`)
- Modify: `assets/lang/translations.csv` (the boss name row, every language), the boss list in
  [bosses/system](../bosses/system.md)
- Test: `netcopter_rules`; `boss_intro LEVEL=tools/levelgen/arenas/NetcopterArena.json`

**Interfaces:**
- Consumes: `glowbomb` (Task 2), `Boss.strike`, `Boss:onSpecialHit` (Plan 4), the art of Task 1 (until applied:
  `debugColor` boxes).
- Produces: states `dormant → intro → ready → hover ↔ aim_net → (bomb drops on its own timer) → [phase 2] sweep_warn →
  sweep → … → dying_hold → fleeing → dead`. Tuning table `T` at the top of the file with every number of the design
  above. `phase()` = 1 or 2 (≤ 50 % HP). Everything drawn derives from state + `deadTimer` + x, y.

- [ ] **Step 1: failing tests**, cases: `vida` (hp 12 at Normal; `bossHp` applies), `fase2` (damage to 6 → phase 2,
  `machine_popped`), `especial` (a burst of power 3 → hp −3; again inside `INV_TIME` → no damage), `no_pisa` (a flying
  player falling onto it never stomps: hp unchanged, player loses 1), `red` (a net hits a player in the line → −1 HP
  and `ctrlLock`), `garra` (the claw only hurts on the marked band), `huye` (at 0 HP: no death sprite, it leaves the
  zone to the right, zone `cleared`), `azar` (two `rollStart` seeds → different first-net times).
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** implement, following [how-to-add-a-boss](../bosses/how-to-add-a-boss.md) (header with the 10 lines,
  `rollStart`, `Boss.withPlayer` / `strike`, generic intro hooks).
- [ ] **Step 4:** `run.sh netcopter_rules` OK; `run.sh boss_intro LEVEL=tools/levelgen/arenas/NetcopterArena.json` OK;
  `run.sh boss_frames` (if it lists every boss) OK.
- [ ] **Step 5:** commit.

### Task 5: The boss stage `valle_redcoptero` in the campaign

**Files:**
- Modify: `tools/levelgen/flappy_lib.py` (a `boss_arena(...)` helper: auto-scroll `endCol` at the arena, a boss zone,
  a finish after it), create `tools/levelgen/levels_flappy_valle_boss.py` (writes ONLY `valle_redcoptero.json`)
- Create: `assets/levels/valle_redcoptero.json`
- Modify: `src/flappy/Zones.lua` (`boss = 'valle_redcoptero'`), `tools/tests/flappy_campaign/` (`zonas`: a boss stage
  needs a boss zone and no cage requirement), `tools/tests/flappy_flight/` or `netcopter_rules`

**Interfaces:**
- Consumes: Tasks 2–4. The stage: ~40 columns of pillars (Valley rhythm, a few charges and one food), then the arena
  (one screen wide, a couple of short pillars inside for cover), then ~8 columns to the finish.

- [ ] **Step 1: failing tests**: `flappy_campaign CASE=zonas` with the boss in `Zones.LIST` (fails: file missing);
  `netcopter_rules` cases `etapa_jefe` (a scripted pilot reaches the arena, the auto-scroll is `stop`, the zone
  `fight`; the boss forced to 0 HP → walls down, the pilot flies right and `onFinish` fires) and `muerte_en_pelea`
  (die in the fight → respawn inside the zone, boss HP unchanged, at most one charge on screen).
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** write the helper and the generator; run `python3 tools/levelgen/levels_flappy_valle_boss.py`; add the
  boss to `Zones.LIST`.
- [ ] **Step 4:** `run.sh flappy_campaign`, `run.sh netcopter_rules`, `run.sh flappy_flight`, `run.sh project_check`,
  `run.sh docs_reference` → all OK.
- [ ] **Step 5:** commit.

### Task 6: Docs, battery, release

**Files:** create `docs/bosses/netcopter.md` (the boss page skeleton: what · files · behaviour · tests · decisions);
modify [flappy-campaign](../gameplay/flappy-campaign.md) (boss stage, return to sender, drops), the roadmap row 5 in
[flappy-prequel](flappy-prequel.md#plans), [bosses/system](../bosses/system.md) table, `docs/README.md` if a page is
new, `version.txt`.

- [ ] **Step 1:** write the docs; record the user's verdict on the art and the `tuffi` decision in the boss page's
  decisions section.
- [ ] **Step 2:** `tools/tests/run.sh all` → ends with `TODO OK` (gameplay change: the full battery).
- [ ] **Step 3:** commit, bump `version.txt`, push to master, `tools/deploy_server.sh`; report version + commit.
- [ ] **Step 4:** tell the user what only a person can judge: the fight's feel and difficulty, the art in motion, the
  music (not listened to).
