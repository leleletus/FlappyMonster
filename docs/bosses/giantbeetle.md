# Giant Rhino Beetle (Escarabajo Rinoceronte Gigante) — `giantbeetle`

The JUNGLE boss (a future island: weights, crates and carryables; not in the story yet — it will need more mirror
shards, [new-bosses-plan](new-bosses-plan.md) § 5). The Rhino Beetle ([enemies](../entities/enemies.md#rhino-beetle-beetle-0576--jungle-only))
giant: the same 22x20 sheet at scale 12 with the gold RUNE of the Mirror's Fury and a glowing eye. Not a crab (the
user: "there are too many crabs already"). Design approved by the user on 2026-10-28, with two additions of theirs:
the beetle FIRED by the scale must SMASH into the ceiling (or anything above) and fall on its back, and the scale is a
double-edged weapon (its slam fires the player too).
**File:** `src/world/entities/types/bosses/giantbeetle.lua`. **Art:** `assets/anim/bosses/giantbeetle.json` (body: walk,
charge, flip, toss, fly, slam + block, debris, wave, dust; `tools/art/enemies/make_beetle.py`, body sheet retouched by
the user — legs). **Sounds:** reused (`megaSlam/Step/Windup/Roar/Hurt/Fall`, `gustBlow` = the wings, `cavePebble`,
`caveRumble`, the chunk's material `breakSound`, `scaleLaunch`, `headBump`); its own set is still open. **Arena:**
`tools/levelgen/arenas/jefe_escarabajo.json` (`make_jefe_escarabajo.py`). **Music:** `templo` "El Templo"
([music-history](../audio/music-history.md#el-templo-toolsmusictemplopy-boss-track-templo)). **Shard:** none yet.
**Level:** `templo_escarabajo` "Templo del Escarabajo" / "Beetle Temple" (`tools/levelgen/levels_boss.py`: a short
jungle stretch with two Rhino Beetles, small boxes to throw them at and a Gummy, then the arena; tropical theme; in Free
Play — not in the story yet). **Harnesses:** `giantbeetle_rules`, `boss_sim` / `boss_intro` / `online_boss` /
`boss_frames` with `LEVEL=` that arena, `sp_boss LEVEL=assets/levels/templo_escarabajo.json`.

## The arena: the temple of the scale

Zone cols 12-35, rows 3-12, floor 13, LOW ceiling (row 2, 10 tiles above the floor). A big SCALE (pulley at 24,3,
`span` 12, `drop` 6.375, `travel` 2): level, its two pans hang 3 TILES ABOVE the solid floor (no pits; 0.5.79). A loaded
pan sinks to 1 tile above the floor (the charge bonks on it). Drop-through ledges at both sides (row 11) and in the
centre (row 9) to dodge the charge and the waves (0.5.81: one tile lower than in 0.5.79).

## Behaviour

- **Armoured**: standing, stomps and ground pounds only bounce (`isVulnerable` = 'flipped' only). Touching it = 1 HP.
- **Flipping it** (the only opening): with it on a pan, a ground pound (or any hard impact) on the OTHER pan fires it
  (`onScaleLaunch`: 'launched', straight up at `LAUNCH_V` 1500 px/s until it hits something) → smashes into the ceiling
  (shake, debris) → 'tumble' (turns over as it falls) → **'flipped'** (`FLIP_T` 4.2 / 3.4 s, legs flailing, stars):
  stomp 1 / ground pound 2 (`INV_TIME` between hits) → 'righting' (hops back up). About 3 flips win the fight.
  `FLIP_T` by difficulty { calm, angry }: easy 9 / 7.5 · normal 7.5 / 6 · hard 5.5 / 4.5 · extreme 5.2 / 4.2 ·
  xtra 5 / 4 s (0.5.81 gave +4 / +2 s over the old 4.2 / 3.4 — "almost impossible to get from one pan to the other" —;
  0.5.82: 1 s less, "not that easy"). After the first hit it gets up in `Boss.GETUP_T` ([system](system.md)).
- **Attacks** (never the same twice in a row; `REST_T` 1.2 / 0.8 s between):
  1. **Charge**: 'charge_wind' (scraping dust, `CHARGE_WIND` 0.8 / 0.6) → 'charge' (`CHARGE_V` 860 / 1060 px/s; running
     into it = 1 HP and a big push) → into a wall: 'bonk' (armoured) and DEBRIS falls from the ceiling (`ROCKS` 4 / 6:
     one above each player, the rest anywhere; a SHADOW warns `ROCK_WARN` 0.75 s; 1 HP). Angry: two charges in a row.
  2. **Toss**: tears a CHUNK of the floor it stands on (0.5.78; see below) ('toss_wind') and throws it in an arc onto the player ('toss';
     1 HP; it shatters on landing). Angry: two blocks.
  3. **Wing leap**: 'leap_wind' (the target mark) → 'leap' (wings buzzing) → 'slam': two shockwaves along the floor
     (`BossWaves`, 1 HP). Landing ON A PAN fires the other pan (`Scale.slamUnder`, × `SLAM_POWER` 1.5): a player there
     shoots up and, hitting the ceiling, loses 1 (`HIT_CEIL`). With a player standing on a pan it jumps to the OTHER
     one `PAN_BAIT` 65 % of the time — so stand on a pan to bait it, step off before it lands, get on the other pan
     and ground-pound.
- **Angry** (under `rageAt` 0.5): faster, double charge, double toss, and FLYING Rhino Beetles appear near the ceiling
  (reserve minions, `def.summons` with `wings`, `movement` 'fly', free flight in the upper half of the zone; they patrol
  and never charge; a stomp drops them on their back, righted they fly again — [enemies](../entities/enemies.md#rhino-beetle-beetle-0576--jungle-only);
  `MINIONS` easy 1 · normal / hard 2 · extreme / xtra 3).
- **Intro**: buzzes down from above the zone, lands with a slam, roars. **Defeat**: 'dying_out' (on its back, the legs
  slowing) → 'dying_flee' (clumsy flight up through the ceiling, pure function of time; shard at `THROW_T`); its
  minions burst.
- **Drawing**: every frame with its lowest pixel on the ground (`Set:footGap`, measured from the image) except in the
  air (leap, launched, tumble, flee) — the user saw its legs floating in some frames — PLUS 1 px (the front legs are
  longer: the back ones touch the ground, the front ones sink 1 px; the user).
- **Network**: `netPackExtra` = rage, target mark, blocks {id, x, y}, debris {id, x, y, t, floor}, waves
  (`BossWaves.pack`); protocol 79.

## 0.5.78 changes (the user)

- Its box was bigger than its body ("very hard to jump over or dodge") → the body without the horn (`outerW` 0.64,
  `outerH` 0.55 of the frame), centred (the drawing shifts `BODY_DX` 2 px), touching it = that box with no margin.
- The TOSS throws a CHUNK OF THE FLOOR it stands on instead of a fixed block: its material is the tile in front of its
  horn (`floorTile`; on a pan, stone), drawn spinning with that tile's own texture and breaking into pieces of that
  material (`chunk_break` with `{ tile }`; the tile id travels in the netPack and in the effect event).
- Repeated sounds spaced out (charge steps every `STEP_EVERY` 0.28 s, wing buzz every `BUZZ_EVERY` 0.3 s; they were
  10-12 per second).
- Landing on its SHELL hurt instead of bouncing (the contact damage only let a 14 px band count as "on top"; a fast
  fall crossed it in one step) → feet above the middle of its body = on top: no contact damage, `Boss:interact` bounces.
- Only the first falling stone seemed to be marked: over a PAN the stone looked for the floor at the bottom of the pit
  (its shadow was hidden under the pan and it fell through) and every shadow started faint and small → `floorBelow`
  finds the first tile, platform or BODY (pan) under it, the stone stops there, and the shadows are clearly visible from
  the start (50-80 %), blink and grow until it lands.
- Whatever is carried or pushed into the arena breaks / bursts when it closes ([system](system.md#what-is-brought-into-the-zone)).

## 0.5.79 changes (the user)

- Arena: shorter rope (`drop` 6.375: the level pans hang in the air, not flush with the floor), lower ledges (sides row
  10, centre row 8), no pits.
- Minions: flying Rhino Beetles with their own wings instead of walking ones (see Angry above).
- A chunk torn from a drop-through platform came out as STONE → `floorTile` takes one-way tiles too (wood), and on a
  pan (a body) it is wood.
- The chunks had no impact sound of their own → each plays its material's `breakSound` (`Materials`: stone/basalt
  `blockBreak`, dirt/grass/sand/snow/ash `gpImpact`, ice `iceBreak`, wood `boxBreak`) at the chunk.
- Music `templo` 2.5 dB lower ([music-history](../audio/music-history.md)).

## 0.5.80 changes (the user)

- A chunk of drop-through platform flew with a dark square behind it (the shadow was a full tile) → the shadow is the
  size of the tile's visible part (its `hitbox`).
- (0.5.81) Falling stones' shadows stayed where the floor was when they started: over a moving pan they floated →
  `updateRocks` recomputes `floor` (`floorBelow`) every step, during the warning and the fall; it travels in the
  netPack, so clients see it too.
- On a pan it still threw stone → `floorTile` looks for a body under its body and horn in a band (−4..+20 px from its
  feet), since riding a pan its feet are not always on the plank to the pixel.

## 0.5.84 changes (the user)

- "One of the noisiest bosses": every sound call of the boss and the small beetle passed (volume, pitch) to
  `Sound.play(name, pitch, volume)` — the wing buzz played at volume 1.6 three times a second, the steps at 1.3 — →
  fixed; the sounds now have the pitch and volume meant.
- Standing or walking on a pan did not lower it (bosses weighed 0) → it weighs 3 (`GB.weight`; a `ridesScale` boss
  counts in `Weight`).
- Its charge took a pan hit sideways (from a side ledge, or under a lowered pan) for a wall → pans are one-way bodies,
  passed sideways (`Snow:move`).

## 0.5.85 changes (the user)

- An infinite loop that broke the fight: knocked out against the ceiling, not hit, it got up ON THE PAN and the player
  ran to the other pan and fired it again, and again → when it gets up on a pan it immediately HOPS (`'hop'`: a soft
  jump with no waves and no scale slam) to the floor or a ledge 3-9 tiles away that is not a pan (`GB:hopOff`,
  `GB:onAPan`).

## How to extend

- Tuning lives in the constants at the top of the file (`{ normal, angry }` pairs).
- The scale rules are generic (any boss with `ridesScale` + `onScaleLaunch` / `onScaleCatapult`):
  [traps-and-mechanisms](../entities/traps-and-mechanisms.md).

## Tests

`giantbeetle_rules` (arena, pans — its weight lowers one, the charge passes through them —, hop off a pan after getting up, armour, shell bounce, stone marks, moving-pan shadow, flip, hits, double edge, bait, charge + debris, toss, waves, rage, flying minions, wood chunk + sound, defeat, net);
`boss_sim LEVEL=tools/levelgen/arenas/jefe_escarabajo.json` (a whole fight played as intended: every state seen, killed
by flipping it); `boss_intro`, `online_boss` with that arena.

## History and decisions

- 2026-10-28: the user picked the Rhino Beetle among three non-crab ideas (beetle, mandrill, chameleon), the design D
  colours (a mix of A "Bronce" and C "Castaña") and approved the fight; then asked that the scale fire it into the
  CEILING (not just up) and work against the player too, and that the scale's catapult be general for any hard impact.
- Legs: the generated 2-frame walk "didn't look like walking" → 4-frame tripod gait with knees; the user then retouched
  the legs by hand (protected: `KEEP` in the generator).
- Music: four lead melodies were rejected; the approved theme has NO melody (the riff of "Temple Tumble" is the tune).
