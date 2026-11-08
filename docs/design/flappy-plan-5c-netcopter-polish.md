# Flappy campaign — Plan 5c: the Net-Copter, after the user's first play (implementation plan)

<!-- project_check: future-paths (this plan names files that do not exist yet) -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the Net-Copter fight feels alive and fair: a bomb that threatens and can really be returned, a machine that
crosses the arena and turns, nets that look and sound like nets, a cannon mounted on the machine, more sounds,
effects and animation, and a Mirror-style laugh.

**Architecture:** same files as Plan 5 ([flappy-plan-5-netcopter](flappy-plan-5-netcopter.md)):
`src/world/entities/types/bosses/netcopter.lua`, `traps/netshot.lua`, `traps/glowbomb.lua`, the art generator
`tools/art/bosses/make_netcopter.py`, harness `netcopter_rules`. New: a sound generator `tools/sounds/netcopter.py`
(output committed in `assets/sounds/`, registered in `src/audio/Sound.lua`). Single player only.

**Spec:** the user's verdict after playing 0.5.176 (2026-11-08), recorded in [netcopter](../bosses/netcopter.md):
1. the bomb is useless: it only falls to the floor, never hits the monster, and can almost never be returned (it is
   below); 2. the machine must not stay still: it moves from the left side to the right side too, and turns;
3. the nets have no sound, no effect and no spin: they don't look like real nets; 4. the cannon is not really attached
to the machine; 5. more sounds, effects and animations: it should feel alive, a good boss fight; 6. the Evil Monster's
laugh like the Mirror's (blank face + laughing-eye sprites).

## Decisions (Claude's calls, told to the user)

- **Bomb = lobbed.** Thrown from the gondola in a ballistic arc whose landing point is the player's position at
  throw time and whose apex is ~2.5 tiles above the player's head (gravity `T.BOMB_G` 900 px/s², flight time from the
  geometry). A landing MARK (blinking ring on the floor / at the target cell) shows from the throw. It explodes on
  touching a player who is not rising, the floor, a pillar or a solid tile (radius 1 tile, 1 HP, as today). A flying
  player RISING into it returns it (Plan 5's `reflectable` rule, unchanged). The fuse stays as a fallback only.
- **Patrol.** The machine holds a SIDE (left third or right third of the zone) for `T.HOLD = {7, 5}` s (phase 1, 2)
  attacking, then CROSSES to the other side along the top band in `T.CROSS_T` 1.8 s and turns (`facing` = toward the
  zone centre); no attacks while crossing; body contact still hurts. Nets, cannon, claw and the bomb throw all use
  `facing`. Starts on the right side (the intro), `rollStart` randomizes the first hold length.
- **Nets:** 3-frame unfurl (folded ball → half → open) over the first 0.25 s, then spinning (rotation derived from
  age, so client and SP agree), a fibre puff when fired; on hitting a player, a net overlay wraps the monster for the
  `ctrlLock` time; on a pillar / solid tile it snags and comes apart (puff). Sounds: fire `netFire`, hit `netSnare`,
  snag `netSnag`.
- **Cannon:** on an iron arm bolted to the gondola side (art), pivoting with `facing`; recoil (1 art px back) + smoke
  puff when it fires.
- **Alive:** propeller spin (4 frames, faster when crossing), the balloon sways (±1 art px with `deadTimer`),
  pedalling legs matched to speed, a rhythmic `pedalSqueak` while moving, `propWhir` loop-ish ticks, sparks + smoke
  puff + 0.15 s shake on each hit, the Evil Monster's ANGRY frame (fist up) for 0.6 s after a hit, a smoke trail and
  an air-leak hiss (`leakHiss`) in phase 2, `balloonPop` when phase 2 starts, `clawServo` on the claw warn, `bombLob`
  on the throw. Effects are drawn from state + timers only (golden rule 1); particles via the existing fx module
  (`Entity.emitFx` / `src/fx/`).
- **Laugh like the Mirror:** a blank head (no eyes) + laughing-eye sprites ("joy eyes") on the Evil Monster's head,
  head bobbing in a few frames, used in the intro and when a player dies (as the Mirror does).

## Global Constraints

- Golden rules 1 (everything drawn derives from state + timers + x,y + packed fields; no love.graphics outside
  render), 2 (no copies: reuse the Mirror's laugh TIMING idea, not its code; shared helpers stay shared), 4 (every
  image and sound is a real file from a committed generator), 6 (no wings).
- Art: the same pixel density (×6), the Evil Monster's full body as in 0.5.176 (do NOT go back to a stick figure);
  never edit `assets/images/bosses/miniboss1/`, `assets/images/bosses/mirror/` or `assets/images/player/` (read only).
- Sounds: new ids are stored forever; each has a row in the sound docs ([sound](../audio/sound.md)).
- Spanish comments / commits, English docs; no `Protocol.VERSION` change (Flappy is not online).

## Review Focus

1. **The bomb thrown at a player standing still** lands within 1 tile of them and hurts; the same bomb met by a player
   flapping up into it returns it. Test in Task 1.
2. **Crossing never traps the player** against a wall with the body: while crossing it flies the top band; a player
   in the top band takes 1 HP once (invulnerability), never a chain. Test in Task 1.
3. **Facing after a crossing** — nets and bombs go toward the zone centre from the left side too. Test in Task 1.
4. **Sound spam** — the squeak / whir never play every frame (rate-limited). Checked in Task 3 (count plays in 5 s).
5. **The laugh** on a player's death does not freeze the fight. Test in Task 2.

---

### Task 1: Gameplay — the lobbed bomb, the patrol and facing

**Files:** `netcopter.lua`, `traps/glowbomb.lua`, `tools/tests/netcopter_rules/main.lua` (+ README row).
- [ ] Failing cases: `lanzada` (player still at x → bomb lands within 1 tile, player −1), `devuelta_arco` (player rises
  into the arc → returning, boss −2), `cruza` (after HOLD the boss is on the other third, `facing` flipped, no attack
  while crossing), `mira_izq` (from the left side a net travels right), `cruce_justo` (player in the top band during a
  crossing loses exactly 1).
- [ ] Implement; existing cases still OK (adapt `falla`/`mecha` to the lobbed bomb); `run.sh netcopter_rules` TODO OK.
- [ ] Commit.

### Task 2: Art — cannon arm, net unfurl, laugh, angry frame, propeller, effects sprites

**Files:** `tools/art/bosses/make_netcopter.py` (+ preview), `assets/images/bosses/netcopter/` (new sheets:
`cannon_arm`, `net-Sheet` 3 frames, `pilot_laugh-Sheet` (blank head + joy eyes frames), `pilot_angry`, propeller
4 frames, `puff`/`spark` small sheets), drawing in `netcopter.lua` / `netshot.lua`, laugh trigger on a player's death.
- [ ] Generator + preview; Read the preview; `--apply`.
- [ ] Wire the drawing (facing flip of the whole machine, cannon on its arm with recoil, net frames + rotation, sway,
  angry frame, laugh frames, smoke trail in phase 2); case `risa` (a player dies → laugh plays, the fight goes on).
- [ ] `run.sh boss_frames` capture of the arena (Read it), `netcopter_rules`, `project_check` OK. Commit.

### Task 3: Sounds and effects wiring

**Files:** `tools/sounds/netcopter.py` (new; style of `tools/sounds/tifon.py`), `assets/sounds/...` (its output),
`src/audio/Sound.lua`, `netcopter.lua`, `netshot.lua`, `glowbomb.lua`, sound docs.
- [ ] Generate `netFire`, `netSnare`, `netSnag`, `pedalSqueak`, `propWhir`, `balloonPop`, `clawServo`, `bombLob`,
  `leakHiss`; register; wire with rate limits; sparks/smoke/shake on hit.
- [ ] Test: the harness's sound stub (or `Sound` spy) counts `pedalSqueak` + `propWhir` plays over 5 s of hover:
  ≤ 12 each. `run.sh sounds` (if it checks registered files) + `netcopter_rules` + `project_check` OK. Commit.

### Task 4: Docs and release

- [ ] [netcopter](../bosses/netcopter.md) (behaviour, the user's verdict + these decisions in history), sound docs,
  generators line; `run.sh netcopter_rules flappy_flight flappy_campaign boss_sim project_check docs_reference` OK.
- [ ] version.txt + 1, commit; the controller pushes and deploys after the final review. Tell the user: sounds and
  feel not judged by a person.
