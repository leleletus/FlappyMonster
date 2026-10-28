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
`caveRumble`, `boxBreak`, `scaleLaunch`, `headBump`); its own set is still open. **Arena:**
`tools/levelgen/arenas/jefe_escarabajo.json` (`make_jefe_escarabajo.py`). **Music:** `templo` "El Templo"
([music-history](../audio/music-history.md#el-templo-toolsmusictemplopy-boss-track-templo)). **Shard:** none yet.
**Harnesses:** `giantbeetle_rules`, `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with `LEVEL=` that arena.

## The arena: the temple of the scale

Zone cols 12-35, rows 3-12, floor 13, LOW ceiling (row 2, 10 tiles above the floor). A big SCALE (pulley at 24,3,
`span` 12, `drop` 9.375, `travel` 2): level, its two pans sit FLUSH WITH THE FLOOR, each over a 3-wide pit 2 deep (so the
charge runs across them and a pan can sink). Drop-through ledges at both sides (row 8) and in the centre (row 6) to
dodge the charge and the waves.

## Behaviour

- **Armoured**: standing, stomps and ground pounds only bounce (`isVulnerable` = 'flipped' only). Touching it = 1 HP.
- **Flipping it** (the only opening): with it on a pan, a ground pound (or any hard impact) on the OTHER pan fires it
  (`onScaleLaunch`: 'launched', straight up at `LAUNCH_V` 1500 px/s until it hits something) → smashes into the ceiling
  (shake, debris) → 'tumble' (turns over as it falls) → **'flipped'** (`FLIP_T` 4.2 / 3.4 s, legs flailing, stars):
  stomp 1 / ground pound 2 (`INV_TIME` between hits) → 'righting' (hops back up). About 3 flips win the fight.
- **Attacks** (never the same twice in a row; `REST_T` 1.2 / 0.8 s between):
  1. **Charge**: 'charge_wind' (scraping dust, `CHARGE_WIND` 0.8 / 0.6) → 'charge' (`CHARGE_V` 860 / 1060 px/s; running
     into it = 1 HP and a big push) → into a wall: 'bonk' (armoured) and DEBRIS falls from the ceiling (`ROCKS` 4 / 6:
     one above each player, the rest anywhere; a SHADOW warns `ROCK_WARN` 0.75 s; 1 HP). Angry: two charges in a row.
  2. **Toss**: tears a temple BLOCK out of the floor ('toss_wind') and throws it in an arc onto the player ('toss';
     1 HP; it shatters on landing). Angry: two blocks.
  3. **Wing leap**: 'leap_wind' (the target mark) → 'leap' (wings buzzing) → 'slam': two shockwaves along the floor
     (`BossWaves`, 1 HP). Landing ON A PAN fires the other pan (`Scale.slamUnder`, × `SLAM_POWER` 1.5): a player there
     shoots up and, hitting the ceiling, loses 1 (`HIT_CEIL`). With a player standing on a pan it jumps to the OTHER
     one `PAN_BAIT` 65 % of the time — so stand on a pan to bait it, step off before it lands, get on the other pan
     and ground-pound.
- **Angry** (under `rageAt` 0.5): faster, double charge, double toss, and small Rhino Beetles drop from the ceiling
  (reserve minions, `def.summons`, `MINIONS` easy 1 · normal / hard 2 · extreme / xtra 3).
- **Intro**: buzzes down from above the zone, lands with a slam, roars. **Defeat**: 'dying_out' (on its back, the legs
  slowing) → 'dying_flee' (clumsy flight up through the ceiling, pure function of time; shard at `THROW_T`); its
  minions burst.
- **Drawing**: every frame with its lowest pixel on the ground (`Set:footGap`, measured from the image) except in the
  air (leap, launched, tumble, flee) — the user saw its legs floating in some frames — PLUS 1 px (the front legs are
  longer: the back ones touch the ground, the front ones sink 1 px; the user).
- **Network**: `netPackExtra` = rage, target mark, blocks {id, x, y}, debris {id, x, y, t, floor}, waves
  (`BossWaves.pack`); protocol 79.

## How to extend

- Tuning lives in the constants at the top of the file (`{ normal, angry }` pairs).
- The scale rules are generic (any boss with `ridesScale` + `onScaleLaunch` / `onScaleCatapult`):
  [traps-and-mechanisms](../entities/traps-and-mechanisms.md).

## Tests

`giantbeetle_rules` (arena, armour, flip, hits, double edge, bait, charge + debris, toss, waves, rage, defeat, net);
`boss_sim LEVEL=tools/levelgen/arenas/jefe_escarabajo.json` (a whole fight played as intended: every state seen, killed
by flipping it); `boss_intro`, `online_boss` with that arena.

## History and decisions

- 2026-10-28: the user picked the Rhino Beetle among three non-crab ideas (beetle, mandrill, chameleon), the design D
  colours (a mix of A "Bronce" and C "Castaña") and approved the fight; then asked that the scale fire it into the
  CEILING (not just up) and work against the player too, and that the scale's catapult be general for any hard impact.
- Legs: the generated 2-frame walk "didn't look like walking" → 4-frame tripod gait with knees; the user then retouched
  the legs by hand (protected: `KEEP` in the generator).
- Music: four lead melodies were rejected; the approved theme has NO melody (the riff of "Temple Tumble" is the tune).
