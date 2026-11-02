# Backlog plan of 2026-11-02

The user's list of 2026-11-02, in working order. Online bugs first (they break play today), then the two gameplay
changes, then the rest. Tick an item in the commit that does it and say in which version. When everything is done,
move this page to the archive.

"Cause" below is what reading the code showed before fixing; each fix must be proved by a harness.

## A. Online bugs (reported by the user)

- [x] (0.5.147) **A1. Double points on a boss hit** (the points message appears twice). Proved on the rule (`mechanics jefe_puntos`); the harness could not land real
  hits on a boss body online, so a person must confirm it.
  Cause: the server runs `checkPlayerEnemyCollisions` twice per tick. Its lag compensation evaluates `Interactions.check`
  against the boss as the player saw it (`inv = 0`), so the second pass says `stomp` again; `Boss:damage` refuses (real
  `inv > 0`) but `Interactions.run` still calls `cb.stomp`.
  Fix: `stomp` / `pound` report whether they did anything; no effect → no points. The ground pound impact zone also runs
  once per impact, not once per pass.
- [x] (0.5.147) **A2. The Crab Mega Mashup does not work online.**
  Cause (to confirm with a harness): the director is at column 9 and players start at column 138; the snapshot only
  carries entities near each player, so the client never gets the director's `netPack` (phase, music, scene, fade).
  Fix: an entity class can ask to always travel; the director does. Then play the event online in a harness to find
  whatever else is broken behind it.
- [x] (0.5.147) **A3. The hitter does not hear their own hit on a boss** (others do, and vice versa).
  Cause: the server tags the sound with the hitter, and a client drops its own tagged sounds because it expects to have
  predicted them; `_checkLocalBounce` deliberately does not predict boss sounds.
  Fix: what a boss does when damaged sounds for everyone, the hitter included.
- [x] (0.5.147) **A4. King Gummy is immortal online in its last phase** (only 1 of the 3 pieces takes damage).
  Cause: `MG:interact` stores the piece in `self._hitPart`, a scalar, so lag compensation's `applyState` restores the old
  value right after the check. `hitPart` then always gets a stale index.
  Fix: the piece touched must not live in rewound state. Check every other `interact` for the same mistake.

## B. Gameplay changes (the user)

- [x] (0.5.147) **B1. Carefully putting an object down on top of another box.** Today `Carry.putDown` always leaves it level with the
  player's feet, so it can never rest on a box. It must land on whatever is in front: stacking becomes possible.
- [x] (0.5.147) **B2. Smaller ground pound.** It must only affect enemies and players ON THE GROUND and at most 1.5 tiles from the
  epicentre (today `GP_RADIUS_X / Y` = 170 / 110 px, airborne ones included). The Mirror and its chaser too (the user).

## C. Backlog chosen by the user

- [x] (0.5.147) **C1. Guard on the level tools:** `build.py` and `retheme.py` refuse to run without level names.
- [x] **C2. Smart boss-fight help:** already built (`bossdrops`, 0.5.62). Only `known-debt.md` was stale.
- [x] (0.5.147, coded and tested; feel still to be judged by the user) **C3. Jump buffer (~0.1 s).** Needs the user's feel check.
- [ ] **C4. Editor safety:** autosave / crash recovery, `validate()` on save, playtest from the cursor.
- [ ] **C5. Options:** music / SFX volume, mute, vibration, A/B swap for Xbox pads.
- [ ] **C6. Tests:** `perf` scenes for credits and the online client, full Evil Ship rules harness, forced push-only probe
  for the Mirror.

## Later (the user: "el 7 lo hacemos luego")

Code cleanup: shared `Sim.step`, splitting `server/main.lua`, sound catalog as data, removing dead code.
