# Giant Pufferfish rework + pufferfish island skins — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the Giant Pufferfish gets one opening per low tide, a bouncing spiked ball, floor spine waves, three
phases and three new high-tide attacks; every pufferfish (small + giant) gets its own look per island.

**Architecture:** all fight logic stays in `src/world/entities/types/bosses/giantpuffer.lua` (shared by single
player, server, client); everything the client draws travels in `netPackExtra`. The whirlpool is a sideways current
through the existing air system (`src/world/systems/Push.lua`, `pushAt`), already predicted online. Skins use the
anim-set `variants` + `isleArt` pattern of the Mole (`src/world/entities/types/enemies/mole.lua`, `Mole:isle` / `Mole:anims`).

**Tech Stack:** LÖVE 11 / LuaJIT; Python 3 + Pillow for the art generator.

**Spec:** [giantpuffer-rework.md](giantpuffer-rework.md) (approved by the user 2026-11-16).

## Global Constraints

- Golden rule 1: identical in single player / server / online client; no `love.graphics`, `Input` or `Sound` outside
  render code paths that already use them; draw only from state + `netPackExtra`.
- Two releases: **R1 = the fight** (Tasks 1-5), **R2 = the skins** (Tasks 6-7, only after the user approves the
  preview). Each release: `Protocol.VERSION` + 1 (R1: 129; R2 only if packed data changes — it does not), bump
  `version.txt` (R1: 0.5.236), commit (Spanish, `Co-Authored-By` line), `git fetch` + check
  `git log HEAD..origin/master`, push to master, `tools/deploy_server.sh`.
- Never rewrite `assets/images/enemies/pufferfish/puffer_fish-Sheet.png` (hand-edited by the user).
- Code comments in Spanish; docs in English; commits with `git -c core.fileMode=false`.
- Tests only through `tools/tests/run.sh`; new cases go into `tools/tests/giantpuffer_rules/main.lua` and its row in
  `tools/tests/README.md` (Spanish).
- Values (phase 1 / 2 / 3): HP 6, `hpPerPlayer` 2; phase 2 at ≤ 4 HP (`phase2At` 0.67), phase 3 at ≤ 2 HP
  (`phase3At` 0.34); flop wind-up {0.45, 0.38, 0.32}; gasp {1.6, 1.4, 1.2}; floor wave {500, 560, 620} px/s, ~0.6 tile
  tall, phase 3 a second wave 0.35 s later; ball bounce height {3, 4, 4.5} tiles; attack every {3.4, 2.8, 2.3} s;
  ring {12, 14, 16} spines with a 3-spine gap, {2, 3, 3} rings at the existing `BURSTS` times; charge warning 0.8 s
  (locked the last 0.2 s), speed {700, 800, 900}; whirlpool phases 2-3 only, 1.0 s warning, 1.6 s pull {220, 280}
  px/s sideways, then puff.

## Review Focus

1. Player hit during the gasp **at the very end of low tide** (water already rising): must become the ball, then
   swim when the water reaches it — never stuck as a ball under water, never a second gasp that tide. → Task 1
   case `ultima_ocasion`.
2. Ball bouncing into a **corner / under the centre platform**: must not get stuck or tunnel out of the zone. →
   Task 1 case `bola` runs 10 s and checks it stays inside `zoneBounds` and keeps moving.
3. Whirlpool with the player **out of the water** or on the other side of a wall: no pull. → Task 4 case `remolino`.
4. **Two players**: one opening per tide is per boss, not per player (the second player cannot hit a ball). →
   Task 1 case `una_ocasion` with 2 players.
5. Online client sees the **same ring gap and charge line** as the server. → Task 5 case `red`.

---

### Task 1: Phases, HP, one opening per low tide, the spiked ball

**Files:**
- Modify: `src/world/entities/types/bosses/giantpuffer.lua`
- Test: `tools/tests/giantpuffer_rules/main.lua`, row in `tools/tests/README.md`

**Interfaces:**
- Produces: `GP:ph() -> 1|2|3` (phase from `self.hp / self.hpMax` vs props `phase2At`/`phase3At`; old `rageAt`, if
  set and `phase2At` is not, is used as `phase2At`); every `{normal, angry}` table becomes `{p1, p2, p3}`;
  `self.rage = self:ph() >= 2` (keeps anger symbols + summons); `self.opened` (bool: this low tide's opening used,
  reset when it enters `swim`); new state `'ball'` (in `ATTACKS` and `SPIKY`).
- Props: `Boss.props({ hp = 6, hpPerPlayer = 2 }, …)` with `phase2At` 0.67 and `phase3At` 0.34 (number props like
  today's `rageAt`, which stays in the schema for old levels).

- [ ] **Step 1: Write the failing cases** in the harness:
  - `una_ocasion`: low tide, boss in `gasp`, 2 players; stomp → `hp` −1 and state reaches `'ball'` within
    `HURT_T` + 0.1 s; while it is `'ball'`, `boss:isVulnerable() == false`, a stomp from player 2 leaves `hp`
    unchanged and costs player 2 1 HP; it never enters `gasp` again before `flood(level).level > 0`.
  - `bola`: put it in `'ball'` at low tide for 10 s: stays inside `zoneBounds`, max height above floor between
    2.5 and 3.5 tiles (phase 1), never still for > 0.5 s; touching it costs 1 HP; when `tideTo(level,'hold')` →
    `swim` within 2 s.
  - `ultima_ocasion`: hit it in a gasp started 0.3 s before the water comes back → `'ball'` → `swim`, `opened`
    reset only on `swim`.
  - `fases`: hp 6→4 → `ph()==2`, `rage==true`; 4→2 → `ph()==3`; level with only `rageAt=0.5` → phase 2 at 3 HP.
  - Update `varado` (after the stomp the state is `'ball'` once out of `hurt_puff`) and `enfado` (now `fases`).
- [ ] **Step 2:** `tools/tests/run.sh giantpuffer_rules CASE=una_ocasion` (and the others) → FAIL.
- [ ] **Step 3:** implement in `giantpuffer.lua`: `ph()`, 3-entry tables (new values above), `onDamaged` sets
  `self.opened = true`; `hurt_puff` → `resume` → if not wet and `opened`, `enter('ball')`; `'ball'` update: gravity
  physics with bounce (floor: `vy = -sqrt(2·ADV_GRAVITY_boss·h)`, wall: `vx = -vx`), horizontal speed toward the
  target capped (~260 px/s), `prick(level, HIT_PUFF)`; wet → `deflate` → `swim`. `resume` and the `gasp` entry
  check `opened`. Pose: `'ball'` = `puffed` anim with a slight squash on each bounce; a flash for its first 0.4 s.
- [ ] **Step 4:** `run.sh giantpuffer_rules` → all cases `OK`.
- [ ] **Step 5:** commit «Pez Globo Gigante: una ocasión por marea baja, bola de púas, 3 fases».

### Task 2: Floor spine wave on every flop landing

**Files:** same as Task 1.

**Interfaces:**
- Produces: `self.waves = { {id, x, y, dir, t}… }` (y = top of the surface it landed on), `GP:fireWave(level)`,
  `GP:updateWaves(level, dt)`, `GP:waveBox(w) -> {x,y,w,h}` (≈ 24 × 0.6·T, bottom on the surface).

- [ ] **Step 1: Failing case** `ola_suelo`: force a flop landing on the floor; 2 waves (dir −1, +1) at speed
  `{500,560,620}[ph]`; a player standing in the path loses 1 HP; a player jumping over it (feet > 0.7·T above the
  surface) does not; the wave is removed at a wall and where the surface ends (no tile under `x`); phase 3 → 4 waves
  in total, the second pair 0.35 s later.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** implement: `fireWave` in both landing branches (`flop` and `fall` → `gasp`); update in
  `updateBoss` next to `updateSpines`; render a row of `spineImg` pointing up along each wave; add the boxes to
  `debugBoxes`; `defeat()` clears `waves`.
- [ ] **Step 4:** run → PASS (all cases).
- [ ] **Step 5:** commit «Pez Globo Gigante: ola de púas por el suelo al caer».

### Task 3: High tide — ring with a moving gap, the charge

**Files:** same as Task 1.

**Interfaces:**
- Produces: `GP:fireBurst(level, k)` now leaves a gap: `self.gapA` (radians, the centre of the gap, rotated by
  `2π·3/n` between rings, starting aimed AWAY from the target); states `'charge_warn'` and `'charge'`;
  `self.lineX, self.lineY` (end point of the charge line, locked the last 0.2 s); attack choice: never the same as
  `self.lastAtk`; near → puff, far → ring or charge (phase 3: charge is followed by `spines_warn` directly).

- [ ] **Step 1: Failing cases:**
  - `aro_hueco` (replaces `puas`): phase 1 → 2 rings of 12 − 3 = 9 spines; the gap centre moves between rings by
    3 spines' angle; a player sitting in the first gap is not hit by ring 1; spines still stop at walls.
  - `embestida`: high tide, player far; `charge_warn` lasts 0.8 s and the line follows the player until 0.2 s before;
    then it moves along the line at `{700,800,900}[ph]` px/s, puffed (`SPIKY`), contact costs 1 HP with a strong push
    (`HIT_PUFF`), ends at a wall or the water surface → `deflate`; it never goes above the water surface.
  - `combo`: phase 3, after `charge` ends the next state is `spines_warn`.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** implement; charge warning drawn as a dashed line on the water (`BossFx` helpers if one fits, else
  rectangles); sound: `pufferWarn` for the warning and an existing dash sound pitched (builder picks).
- [ ] **Step 4:** run → PASS.
- [ ] **Step 5:** commit «Pez Globo Gigante: aros con hueco y embestida».

### Task 4: Whirlpool (phases 2-3), sideways pull through Push

**Files:** same as Task 1 (+ `src/world/systems/Push.lua` only if `Push.collect` misses bosses — check first).

**Interfaces:**
- Consumes: `Push.collect` / `Push.at(level, x, y, o)` (`pushAt(x, y, o) -> wx, wy, k`).
- Produces: states `'whirl_warn'` (1.0 s) and `'whirl'` (1.6 s → `puff_warn`); `GP:pushAt(x, y, o)` returns
  `(sign(self.x − x) · {0, 220, 280}[ph], 0, 1)` only when `self.state == 'whirl'`, `o` is a player (has
  `isInvulnerable`), the point is in liquid (`level:liquidAt`) and inside `zoneBounds`; otherwise `nil`. It must use
  only fields that travel in the snapshot (state, x, phase).

- [ ] **Step 1: Failing case** `remolino`: phase 2, high tide, player 6 tiles left in the water standing still for
  1.6 s of `whirl` → moves ≥ 1.5 tiles toward the boss; the same player out of the water → does not move; phase 1
  never picks the whirlpool; a pufferfish minion / box is not pulled.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** implement; render a foam spiral around it during `whirl_warn` / `whirl` (`now`-based rotation; use
  the existing `undertow_foam` particle if it fits).
- [ ] **Step 4:** run → PASS.
- [ ] **Step 5:** commit «Pez Globo Gigante: remolino (fases 2 y 3)».

### Task 5: Network, docs, release R1

**Files:**
- Modify: `giantpuffer.lua` (`netPackExtra` / `netApplyExtra`), `src/network/Protocol.lua` (`VERSION = 129` + its
  comment line first), `version.txt` (0.5.236), `docs/bosses/giantpuffer.md` (rewrite Behaviour, numbers, network,
  a history line: «2026-11-16 the user: miserable, killed in 2 low tides → rework B»), `docs/design/README.md` (row:
  built 0.5.236, skins pending), `tools/tests/README.md`.

**Interfaces:**
- Pack layout (fixed): header `{ phase, markX, markY, burst, lineX, lineY, opened(0/1), gapA·1000 }` (NB = 8), then
  `NetList` of spines (stride 5: id, x, y, a·1000, t·100), then `NetList` of waves (stride 4: id, x, y, dir).
  `netApplyExtra` reads the second list from the `nextK` the first `NetList.read` returns; interpolates by id as now.

- [ ] **Step 1:** extend case `red`: server-side boss in each of `ball`, `charge_warn`, `whirl`, with spines and
  waves alive → pack → apply on a fresh copy → same `ph()`, line, gap, spine and wave positions (±1 px), same
  `pushAt` result for a test point.
- [ ] **Step 2:** run → FAIL; implement; run → PASS.
- [ ] **Step 3:** `run.sh boss_sim LEVEL=tools/levelgen/arenas/jefe_pez.json`,
  `run.sh online_boss LEVEL=tools/levelgen/arenas/jefe_pez.json NOSHOTS=1 SECS=60`,
  `run.sh boss_intro LEVEL=tools/levelgen/arenas/jefe_pez.json SECS=30`,
  `run.sh sp_boss LEVEL=assets/levels/cala_resaca.json SECS=40` → all OK; `boss_frames` captures of `ball`,
  `charge_warn`, `whirl` to look at.
- [ ] **Step 4:** `run.sh docs_reference`, then `run.sh all` → ends «TODO OK».
- [ ] **Step 5:** commit, fetch / check, push, `tools/deploy_server.sh`; report version + commit. Hand-off: feel and
  difficulty not judged (user must play `cala_resaca`).

### Task 6: Skins generator + preview (R2) — STOP for the user

**Files:**
- Create: `tools/art/enemies/make_puffer_skins.py`
- Modify: `docs/art/generators.md` (row + description)

**Interfaces:**
- Produces (on `--apply`): `assets/images/enemies/pufferfish/<isla>-Sheet.png` for the 7 islands ≠ costa (same size
  and frame grid as `puffer_fish-Sheet.png`, same opaque silhouette per frame ± added detail pixels inside it), and
  `assets/images/bosses/giantpuffer/<isla>-spine.png` (same size as `spine.png`).

- [ ] **Step 1:** script reads the user's sheet, maps its palette per island + adds each island's detail (spec list:
  pradera spots, fortaleza plates/rivets, nieve crystal spines, cueva glowing spots + lure, volcan magma cracks +
  ember tips, jungla yellow/black bands, estelar star specks / star tips); few colours, flat areas.
- [ ] **Step 2:** no flag → `/home/mtvemo/FlappyMonster_pruebas/pez_globo/vista_previa.png` (8 rows: costa original +
  7, every frame, ×6, plus the spine variants); `--apply` writes only missing files (`--force` to overwrite).
- [ ] **Step 3:** a check in the script: for every frame, alpha mask of each variant == mask of the original
  (silhouette unchanged) unless a pixel is listed as island detail; it prints `OK` / the differing frames.
- [ ] **Step 4:** show the preview to the user; **stop until approved** (iterate on the script with their feedback).

### Task 7: Apply skins, wire them, release R2

**Files:**
- Modify: `assets/anim/enemies/pufferfish.json` (`variants`: each island `{from: puffer_fish-Sheet.png, to:
  <isla>-Sheet.png}`), `src/world/entities/types/enemies/pufferfish.lua` (`isleArt = true`;
  `Puffer:isle(level)` + `Puffer:anims()` like `Mole:isle` / `Mole:anims` in `src/world/entities/types/enemies/mole.lua`, base = `costa`), `giantpuffer.lua` (same `anims()`
  override + spine image per island, loaded in `loadAssets`), `docs/gameplay/carry-and-push.md` § Islands (pufferfish
  listed), `docs/art/asset-layout.md`, `docs/entities/enemies.md` pufferfish entry, `version.txt` (0.5.237).

- [ ] **Step 1:** `run.sh mechanics ONLY=islas_arte` must list the pufferfish among `isleArt` and pass; add a check
  there that the pufferfish with `isle=nieve` loads `nieve-Sheet.png` and with `isle=costa` the original sheet.
- [ ] **Step 2:** run → FAIL before wiring; wire; run → PASS.
- [ ] **Step 3:** `run.sh giantpuffer_rules`, `run.sh project_check`, `run.sh docs_reference`, `run.sh level_shots`
  on `bajo_el_hielo`, `mina_inundada`, `jungla_colgante` to look at in-game skins.
- [ ] **Step 4:** commit, fetch / check, push, `tools/deploy_server.sh`; report. Hand-off: looks in game for the user.
