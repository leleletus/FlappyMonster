# Mega Crabby — `megacrabby`

Was the Coast boss until 0.5.30 (now replaced by the [Giant Pufferfish](giantpuffer.md)). Since 2026-10-29 it is a
SECRET boss: its lair `guarida_cangrejo_rey` is reached through the secret exit of `arrecife_globo` (a red node on the
Coast); it wears the SHELL CROWN with a mirror splinter and drops it when it falls (collectible `astilla_crabby`), then
flees still big — the mirror's light shrinks it in the ending
([story-mode](../story/story-mode.md#the-secrets-secret-exits-splinters-the-groove-and-the-mashup)). A giant Crabby (the Crabby's own pixel grid at scale 10) that chases, charges, climbs walls and the
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
  .py). Summon spots: `pickSummonSpots` (never overlapping, outside its body; netPack 9). Death (own states, 0.5.27): upside down (it fell on its head)
  dying_kick → dying_getup (flips back with a hop) → dying_daze (stars) → dying_flee; beaten STANDING (`not flipped`,
  `Mega:defeat` records `defeatFrom`) dying_stand — or dying_iced if its claws were frozen (the Ice Mega: the ice
  cracks off, `onStandFree`) — → dying_daze → dying_flee, never turning over. dying_flee: GIANT, walking with gravity
  (`Mega:fleeStep`, 0.5.28 — no more crawling: the giant body shook turning every stair corner): a wall of up to
  `FLEE_JUMP_MAX` cells is jumped just over, early (`Boss:jumpAhead`; a bump against it still jumps), a drop ahead (stairs down, an edge) is taken with a forward hop
  (`FLEE_HOP_VY`); zone walls ignored, `fleeing`; it goes when nobody sees it (`Boss:fleeOver`, docs/bosses/system.md).
  dying_daze (`DAZE_T` 2.4 s) sways and shakes with LOOSE claws swinging (`pose2d`; also struggling in dying_stand /
  dying_iced, walking claws while fleeing, flailing up in a jump — `_rdy` = drawn vertical motion), stars ring the
  spike base (`Mega.STARS_Y` × sprH); the shard goes at `THROW_T`
  (`Mega:shardDrop`) → dead. `releasesZone()` (Boss hook, used by
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
- 0.5.4, the user saw it "trembling, the sprite shaking fast" while walking (in the credits). The render decides
  walk vs idle from how far it moved since the previous DRAW; drawn more often than it moves (the credits' fixed
  1/60 s physics on a faster screen, a repeated online snapshot) every other frame saw no movement and it switched
  walk / idle frame each frame. "Moving" now lasts 0.1 s after the last advance (`_movedAt`).
- 0.5.23, Xtra Extreme: the pair hemmed the player in (the waiting one kept chasing). `OPENINGS = { stuck }` and,
  while its ally attacks or is stuck, the chase becomes `Boss:waitMove` (step aside, sway, face the player):
  `docs/gameplay/difficulty.md` (6). The ice variant inherits it.
- 0.5.27, the user: in the story the bosses stay GIANT until the ending film shrinks them, so a defeat must not shrink them; they lose the crystal and leave, still giant, respecting the terrain, and DROP the shard while fleeing (not at once). Before: it shrank to a normal Crabby and ran straight through everything. Upright death bug (Ice Mega beaten with frozen claws turned upside down to kick): fixed by `dying_stand` / `dying_iced`. Harnesses: `icecrabby_rules` `mega_de_pie`, `sp_boss KILL=1` (captures `defeat_NN.png`).
- 0.5.28, the user: fleeing down the stairs into / out of its arena it looked like shaking (Crawler wrapping each corner) → "just jump down the stairs or small walls" (`fleeStep`). Dizzy stars were behind the body, bunched and too low → drawn after it, ring around the spike base; the user's first look at 0.6 × sprH: "not where it should be" on the crabs. Then: the dizzy shake lasted too little (all bosses: 1.2 → 2.4 s), claws must not stay fixed while shaking or jumping (react like walking), and jumps must start early, not glued to the wall.
