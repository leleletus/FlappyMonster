# Damage sources — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** every hit on the player carries `{ what, part }`; the death message names it exactly ("Pufferfish spike" vs
"Pufferfish projectile") in single player and online.

**Architecture:** a tiny module `src/player/DamageSource.lua` (make, encode/decode to a number, text). The player's
damage functions take the source and keep `pa.lastHit` when a hit lands. The shared contact rule fills it from the
entity and the hazard box's `part`; tiles, environment causes and direct calls pass theirs. `DeathCause` reads it first
and keeps its guess as the fallback. Online, the own state carries the encoded source.

**Tech Stack:** LÖVE 11 / Lua; harnesses `mechanics`, `story_flow`, `online_helmet`, `project_check` via `tools/tests/run.sh`.

**Spec:** [damage-sources.md](damage-sources.md)

## Global Constraints

- Damage amounts, who gets hurt, invulnerability and shields do not change; only the label travels.
- A source is `{ what = string, part = string|nil }`; `what` = entity type name, tile name, or one of `fall`, `drown`,
  `time`, `crush`, `explosion`; parts are lower-case ids (`body`, `spike`, `projectile`, `fire`, `claw`, …).
- A hit that does not land (shield, invulnerable, already dying) leaves `pa.lastHit` unchanged.
- Calls that pass no source keep working; `DeathCause` falls back to its current guess.
- Player-facing text only from `assets/lang/translations.csv` (es, en): `part.<part>`, `death.part`
  (es "{part} de {name}", en "{name} {part}"), names from `enemy.<family>` / `Lang.bossName` / `death.<cause>`.
- Shared simulation code stays graphics-free. `Protocol.VERSION` 118 → 119, `version.txt` + 1.
- Comments in Spanish; docs in English; tests only through `tools/tests/run.sh`; `git -c core.fileMode=false`.

## Review Focus

- A boss attack that kills in one call path but hurts in another (e.g. `Boss.strike` vs a direct `hurt`): both label
  the same attack. → covered by Task 3's boss case.
- Two hits in the same frame (spike tile + enemy): the one that landed last is the label; a shield keeps the older
  one. → Task 1 test.
- Respawn: `lastHit` is cleared on respawn so an old source never names a later "fell" death. → Task 1 test.
- Online: an own state from before the change (index missing) decodes to nil without errors. → Task 5 test.
- A new entity type added later with an unnamed hazard box: the parts check fails loudly. → Task 2 test.

---

### Task 1: The source and the player's damage functions

**Files:** Create `src/player/DamageSource.lua`; Modify `src/player/PlayerAdventure.lua` (`hurt`, `takeDamage`,
`die`, `hazardHit`, respawn); Test `tools/tests/mechanics/main.lua` (case `fuente_base`).

**Interfaces — Produces:**
- `DamageSource.make(what, part) → { what, part }`; `DamageSource.of(entity, part) → { what = entity.def.name, part }`.
- `DamageSource.encode(src) → integer` (0 = none) / `decode(n) → src|nil`, from a registry built identically on every
  machine: sorted entity type names + tile names + the causes, × sorted part names (`DamageSource.PARTS`).
- `DamageSource.text(src) → string|nil` (translated; Task 4 fills the texts).
- `PlayerAdventure:hurt(n, src)`, `:die(drown, force, src)`, `:hazardHit(src)`; field `pa.lastHit`; cleared on respawn.

- [ ] Step 1: `fuente_base`: hurt with src A → `lastHit == A`; with a shield, hurt with B → still A; invulnerable,
  die with C → still A; die with D (vulnerable) → D; respawn → nil; `decode(encode(x))` equals x for an entity source,
  a tile source and a cause; `encode(nil) == 0`, `decode(0) == nil`.
- [ ] Step 2: run `ONLY=fuente_base tools/tests/run.sh mechanics` → FALLA.
- [ ] Step 3: implement. Step 4: run → OK. Step 5: commit.

### Task 2: Contact damage and named hazard boxes

**Files:** Modify `src/world/entities/base/Interactions.lua` (pass the source on `kill` / `hurt` results), every
`getHazardBoxes` (base `Entity`, `DataEnemy` shots, `spikefall`, `avalanche`, `cryo`, `miniboss1`, `snowboss`,
`megacrabby`, `megagummy`, `crabbytramp`, `crabby_ice`, `crabby`, `pufferfish`, `mortar`) and `DataBoss` hitboxes
(`part` per box); Test `mechanics` (cases `fuente_contacto`, `fuente_partes`).

**Interfaces — Consumes:** Task 1. **Produces:** every hazard box has `part`; `Interactions.check` returns the box so
`run` can build `DamageSource.of(e, hb.part)`; body contact → `DamageSource.of(e, 'body')`.

- [ ] Step 1: `fuente_contacto`: a Crabby's spike → `{crabby, spike}`; a pufferfish's spines → `{pufferfish, spike}`
  and its projectile → `{pufferfish, projectile}`; a falling spike → `{spikefall, spike}`; walking into a Gummy →
  `{gummy, body}`. `fuente_partes`: create one of every entity type (with its default props), collect every hazard box
  it returns over a few updates, each has a `part` in `DamageSource.PARTS`.
- [ ] Step 2: run → FALLA. Step 3: implement. Step 4: run → OK. Step 5: commit.

### Task 3: Tiles, environment and direct calls

**Files:** `src/player/PlayerCollision.lua` (tiles), `PlayerAir.lua` (drown), the fall-out death, `PlayerGulp.lua`,
`PlayerFlight.lua`, `src/world/systems/AutoScroll.lua` (crush), `Explosions.lua`, `HardLaunch.lua`,
`server/srv/sim.lua` and `AdventureState` (time limit, forced), `mechanisms/bossglass.lua`, `base/Boss.lua`
(`Boss.strike`, `Boss.withPlayer`), `DataBoss.lua`, the bosses with direct calls (`groovecrab`, `snowboss`,
`megacrabby`, `megacrabby_ice`, `mirror`, `megagummy`), enemies (`crabby_ice`, `crabbytramp`, `scorpion`, `beetle`),
behaviour `ram`; Test `mechanics` (case `fuente_entorno`).

- [ ] Step 1: `fuente_entorno`: spike tile → `{spikes}`; lava → `{lava}`; drowning → `{drown}`; falling out → `{fall}`;
  out of time → `{time}`; crushed by the auto-scroll → `{crush}`; a bomb's blast → `{explosion}`; a Mega Gummy attack →
  `{megagummy, <its part>}`; every direct `hurt(`/`die(` call in `src/` and `server/` passes a source (a grep in the
  harness lists the ones that don't; allowed: none besides tests and the menu demo).
- [ ] Step 2: run → FALLA. Step 3: implement. Step 4: run → OK. Step 5: commit.

### Task 4: The message

**Files:** `src/player/DeathCause.lua` (reads `pa.lastHit` first), `src/ui/DeathBanner.lua`, `src/player/DamageSource.lua`
(`text`), `assets/lang/translations.csv` (`part.*`, `death.part`, names for non-enemy entity types such as
`enemy.spikefall`); Test `mechanics` (`causa_muerte` extended, `fuente_textos`).

- [ ] Step 1: `causa_muerte`: with `lastHit = {pufferfish, projectile}` the banner text is `death.enemy` with
  "Proyectil de Pez Globo" (es) / "Pufferfish projectile" (en); with `{spikes}` → `death.spikes`; with nil → the old
  guess. `fuente_textos`: every `what` reachable from the registry and every part has its text in es and en.
- [ ] Step 2: run → FALLA. Step 3: implement. Step 4: run → OK. Step 5: commit.

### Task 5: Online

**Files:** `src/network/Protocol.lua` (own state index 46 = `DamageSource.encode(pa.lastHit)`; `applyOwnState`
decodes; missing → nil; VERSION 119), `version.txt`, `src/states/online/OnlineAdventureState.lua` (its death banner reads
the local player's `lastHit`); Test `mechanics` (`fuente_red`), `online_helmet` (the pufferfish phase: the client's
player shows `{pufferfish, spike}`).

- [ ] Step 1: `fuente_red`: pack → apply round trip keeps `lastHit`; an own state of 45 entries applies with
  `lastHit == nil`. `online_helmet` `pez`: also `localPa.lastHit` is the pufferfish's spike.
- [ ] Step 2: run → FALLA. Step 3: implement. Step 4: run → OK. Step 5: commit.

### Task 6: Docs, battery, release

- [ ] Docs: `docs/gameplay/player.md` (damage + `lastHit`), `docs/entities/how-to-add-an-enemy.md` (name every hazard
  box `part`), `docs/architecture/netcode.md` (v119), `docs/design/damage-sources.md` (status: built),
  `docs/design/README.md`, `tools/tests/README.md` (new checks), `docs/design/ux-round-2026-11.md`.
- [ ] `tools/tests/run.sh project_check`, then `tools/tests/run.sh all` → `TODO OK` (rerun a lone `online_*` once).
- [ ] Commit, fetch, push; the user deploys the server from Linux.
