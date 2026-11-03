# Backlog plan of 2026-11-02

The user's list of 2026-11-02, in working order. Online bugs first (they break play today), then the two gameplay
changes, then the rest. Tick an item in the commit that does it and say in which version. When everything is done,
move this page to the archive. (2026-11-03: everything except the open decision of known-debt item 1 is done.)

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
- [x] (0.5.148) **C4. Editor safety:** autosave / crash recovery, `validate()` on save, playtest from the cursor.
- [x] (0.5.148) **C5. Options:** music / SFX volume, mute, A/B swap for Xbox pads. Vibration dropped: the game has no rumble at all, so there is nothing to switch off.
- [x] (0.5.148) **C6. Tests:** `perf` scenes for credits and the online client, full Evil Ship rules harness, forced push-only probe
  for the Mirror.

## D. Second round (the user, 2026-11-02, in this order)

- [x] (0.5.149, committed after the other session's 0.5.149-0.5.152: the next release is 0.5.153) **D1. Code cleanup:** dead code removed · sound catalog as data (`assets/sounds/index.json`) · server split
  into `server/srv/` · shared glue in `src/world/systems/Sim.lua` and one entity update order. The two loops still run
  the step in a different ORDER (known-debt item 1): unifying it is a design decision left open.
- [x] (0.5.153 / 0.5.154) **D2. Online:** profanity filter word lists as data + `name_filter` · report / block · rejoin
  after a cut / watch a running match (0.5.153) · leaderboards and the daily challenge (0.5.154, `server/srv/records.lua`,
  `OnlineRecordsState`; see netcode).
- [x] (0.5.155) **D3. Game modes:** Free Play tabs RACES / BOSSES, BOSS RUSH (`src/story/BossRush.lua`), ghost time trials
  (`src/story/Ghost.lua`); see docs/gameplay/free-play.md. Online Race rooms still list every level.
- [x] (0.5.156) **D4. Story extras** (agreed with the user; see docs/story/story-mode.md): copy a save slot · RETRY on the story results screen (replay the same
  level straight away) · RETRY in the single-player pause menu · a Theater in the Collection (rewatch unlocked films:
  intro, ending, chase, lair, credits) · a shard gallery (the shards collected per world).
