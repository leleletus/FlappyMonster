# Mega Crabby — `megacrabby`

The Coast boss: a giant Crabby (the Crabby's own pixel grid at scale 10) that chases, charges, climbs walls and the
ceiling, pounces, drops spike-first and summons Crabbies. It is also the base class of the Icy Mega Crabby.
**File:** `src/world/entities/types/bosses/megacrabby.lua`. **Art:** `assets/images/bosses/megacrabby/` (the claws
are the USER's drawing: never overwrite). **Sounds:** `assets/sounds/bosses/megacrabby/` (`tools/sounds/megacrabby.py`).
**Level:** `guarida_cangrejo_rey`; arena `tools/levelgen/arenas/jefe_cangrejo.json`. **Music:** `crab_tantrum_normal`.
**Harnesses:** `boss_sim`, `boss_intro` (`gp_subditos`), `crawler_drop SUMMON=1`, `online_boss`.

## Behaviour

- **MegaCrabby** (`types/bosses/megacrabby.lua`, sprites `assets/images/bosses/megacrabby/`, sounds
  `bosses/megacrabby/` from `tools/sounds/megacrabby.py`): Crabby ×2.5 (MS=10), always spiked,
  two claws (`claw_left-Sheet.png` 2×7x6 at 0.7 of the body scale, right = flipped,
  drawn IN FRONT of the body beside the legs; `CLAW_*` constants) that snap at random.
  Secondary animation is render-only and derived from state + deadTimer (same in SP and
  online): squash & stretch per step/landing/windup/charge/drop, breathing, claw sway
  per animation (`Mega:pose2d`), struggle shake when stuck, continuous particles
  (`renderFx`: mega_step / mega_trail / mega_debris / mega_dirt); one-shot fx from the
  sim: mega_slam, mega_land, mega_poof. States intro → chase (floor, nearest player, contact/spike = 1 HP + knockback via
  `hitPlayers`; claw boxes too; after a hit it backs off: recover) → windup → charge →
  recover (contact near a wall: `pushAway` bounces the player OVER the crab to the
  other side; `graceT` after every contact hit: no chained stuns); `pounceEvery`:
  wallclimb (the wall AWAY from the target) → wallaim (marker starts at the target and
  chases it at `MARKER_SPEED`, fixed the last `AIM_LOCK_WALL` s) → pounce (ballistic leap,
  not head-first, only the crush counts: `pounceDamage` 2 HP) → recover; `summonEvery`:
  summon (only if it can: free reserve and below `summonMax`; `SUMMON_WARN` s of yellow
  floor markers at `summonSpot(i)`, count in netPack); every `ceilingEvery` s: climb (Crawler; the
  zone edges count as walls/ceiling via `crawlSolidAt`) → ceiling (above target) → aim
  (FOLLOWS the target along the ceiling with the marker below for `aimTime`, then
  `AIM_LOCK_CEIL` s still and shaking) → drop (spike hazard = KILL) → stuck (ONLY vulnerable state,
  one hit per drop: `hitDrop`; stomp 1 / GP 2) → getup (during its inv time; landing =
  `landShock`: knockback+stun around, 1 HP only to whoever is really UNDER it; then
  `recover` 1 s + `graceT` 1.4 s without contact damage). `rest`: every `restEvery` s
  of chase (5) it stops for ~`restTime` (1.8, ×0.8-1.3) breathing slowly with drooping
  claws (attack timers don't run meanwhile); still spiky on contact. Claws `CLAW_K` 0.85
  (anchored at the joint `CLAW_X/CLAW_Y`: bigger claws grow outward/up from the same
  point). Steps: deeper `step.wav` + GAIN 0.56 (≈ -11.5 dBFS). Spike boxes (head spike,
  drop kill) = tile-spike proportions: base rectangle 60% w × 40% h. Rage below
  `rageAt` (default 0.6): render-only anger symbols pop around its head (`renderAnger`:
  `anger_vein/steam/scribble.png` strips, scale 3) plus, in render (`self._angry`), ONLY a
  reddish pulse and a SLIGHT 1-px tremble — claws, snaps and bounce stay normal (the user
  found more too much; idle = idle frame, never walking feet when still). Roar = giant-crab
  MONSTER (`tools/sounds/megacrabby.py roar`): distorted 34-52 Hz throat growl with jaw
  chatter (AM ~23 Hz) through mouth formants (310/680 Hz) + sub, crescendo, plus the crab
  layer (low chitin stridulation, froth, hiss) and claw clacks; fx `mega_roar` (warped
  semi-transparent shock rings + IRREGULAR sharp zigzag shockwave lines: 3-5 long segments,
  uneven kinks, tapering width, optional side crack; bone/sand colours with a dark brown
  edge — the user rejected "electric" yellow/blue) + `shake_roar` (soft, long). Windup = legs scuttling +
  accelerating claw snaps; claw closes on the sound's snaps (`WINDUP_SNAPS`, same in the
  .py). Summon spots: `pickSummonSpots` (never overlapping, outside its body; netPack 9). Death (own states): dying_kick → dying_shrink (deflates to normal size) →
  dying_flee (small crab without claws runs straight to the nearest side through
  everything, silent steps, fades) → dead. `releasesZone()` (Boss hook, used by
  BossZones) lets the zone clear when the flee starts, so boss walls open first.
  Intro: hidden + not solid while `dormant`; `fall_in` (0.7 s silence, 'megaFall',
  falls from above the zone through anything outside it, lands on the zone floor at
  `introSpot` = its editor x if ≥ `INTRO_SAFE` tiles from every player, else the floor
  point farthest from them; shadow grows on the floor) → `land_in` (slam fx, no
  damage) → `roar_in` ('megaRoar' + fx `mega_roar` rings + shakes, claws up) → `ready`
  → fight starts straight in 'chase'. Rests are EMOTES: `restKind` (netPack field 8)
  cycles `REST_KINDS` {1 roar, 2 claw punches + clacks, 1, 3 spike flex}; drawn in
  `pose2d` (5th return = spike scale for `drawLocal`).
  Minions: the type def's `summons(placement)` makes Level.fromData append RESERVE
  placements (crabby / crabbytramp, wallWalk + dropOnSight) after the JSON ones, so
  server and clients share indices; `Entities.create` → `e:makeReserve(key)` (not alive,
  state 'reserve', not sent: netAtRest). The boss activates them (`resetToHome` +
  'spawning', `leashZone` = its zone via `Crabby:crawlSolidAt`); they die with it. Minions have
  NO patrol route (`makeReserve` sets infinite bounds): they used to inherit the default
  Crabby route around the boss's cell and a GP knockback snapped them to its edge (a
  "teleport", sometimes onto the player). Route limits in `Entity:moveAndCollide` never pull
  an entity that is already outside back in one step (they only stop it moving further out).
  Harness `boss_intro` case `gp_subditos`. `Boss.hurtSound` per boss.
  Minions behave exactly like normal wall-walking ceiling Crabbies (harness
  `crawler_drop SUMMON=1`). Test arena: `tools/levelgen/arenas/jefe_cangrejo.json`.
