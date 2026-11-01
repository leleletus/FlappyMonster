# The Triple Strike Scorpion (`giantscorpion`) and the small Scorpion (`scorpion`)

The user's secret boss for the volcano (2026-10-31): the volcano's one-tailed Scorpion after a mirror splinter split its
tail in three. **In the game as entities, with an arena for testing; no story level, no music of its own, no collectible
entry yet** (plan: [future-secret-bosses](future-secret-bosses.md)).

Try them: `love . --editor tools/levelgen/arenas/jefe_escorpion.json`, then play from the editor (a small one stands
before the boss zone). The zone falls back to the default boss track until it gets its own.

## Files

| File | What |
|---|---|
| `src/world/entities/types/bosses/giantscorpion.lua` | the boss |
| `src/world/entities/types/enemies/scorpion.lua` | the small one |
| `src/world/entities/base/ScorpionKit.lua` | shared by both: piece anchors, tail curves, drawing tails and arms |
| `src/world/entities/base/SegmentChain.lua` | generic live chain of segments: springs, fixed length, drawing only |
| `src/player/PlayerGulp.lua` | being caught: the Carnivorous Plant's mechanic, with `gulpKind` choosing the sounds |
| `tools/art/enemies/make_scorpion.py`, `tools/sounds/scorpion.py` | art and sounds |
| `tools/levelgen/arenas/make_jefe_escorpion.py` | the test arena |

Art, sound names and anchors: [future-secret-bosses](future-secret-bosses.md). Sets used: `bosses/giantscorpion` (body),
`bosses/giantscorpion_parts` (segments, stingers, pincers), `bosses/giantscorpion_fx` (marks, crack, impact); the small
one, `enemies/scorpion` and `enemies/scorpion_parts`.

## The boss

Hp 12 + 4 per extra player. Phases at 2/3 and 1/3 of its health (`angerAt`, `rageAt`): faster each time.

| Attack | States | What happens |
|---|---|---|
| **Joined** | `join_coil` → `join_wind` → `join_hit` → `stuck` → `pull` → `split_coil` → `rest` | rattle while they braid; big floor mark under the player, locked; one heavy strike at the mark (−2); it stays STUCK: the window; it pulls free and uncoils with its rattle |
| **Split** | `split_coil` → `split_aim` → `sting` → `split_back` → `rest` | rattle while they uncoil; 3 coloured marks, the first striker aimed at the player and two beside; each stinger strikes in turn (−1, only at its mark); last phase, half of the time, two at once and then the third (`two`) |
| **Pincer** | `claw_wind` → `claw` → `hold` / `claw_back` | within 4.5 tiles, at most every 4.5 s: hiss, pincer drawn back; aim locks for the last 30 % of the warning; if it reaches you, you are CAUGHT |

- **The rattle:** `scorpionRattleJoin` / `scorpionRattleSplit`, played the frame the movement starts; the movement lasts
  0.21 s; each of the 3 clicks (0, 0.09, 0.18 s) flashes one stinger. The clicks never lie: coiling announces the strike,
  uncoiling the stingers.
- **Its body can be walked through and never hurts** (like the Gloomy): only the tails when thrown and the pincer when thrown
  do anything. Outside its window, landing on it does nothing either.
- **Hitting it:** only while `stuck` (or `hold`). Stomp 1, ground pound 2, on the body OR on the stuck tail (`GS:overTail`, pure,
  so the client predicts the same). `stuck` lasts by difficulty
  (`STUCK_T`, 4.4 s on Easy to 2.3 s on Xtra), and `Boss.GETUP_T` after the first hit.
- **Caught:** like the Plant's swallow: the player is hidden, mashes buttons to get out (10 presses) and loses 1 HP every
  1.75 s, with the pincer's sounds (`gulpKind` = 1, in the own state because the client predicts them). Hitting the boss
  with someone caught frees them.
- **Size:** art ×7 (was ×10). **Reach:** the tails reach 520 px from their base, stretching up to ×1.4 so the point always lands on its mark (`SegmentChain` `stretch`). It walks closer while you are out of reach. Marks stay inside the zone.
- **Entry:** tails tucked, skitter, they open with the rattle, hiss. **Defeat:** `dying_out` (tails fall limp), `dying_flee`: runs
  away through the wall, still big, without the clasp.

## The small one

Art ×3 (the house's small enemies are ×4: at ×4 it was too big). Walks. A player ahead, only as far as it can really reach (110 px): closer
than 65 px, the pincer (`pinch_wind` → `pinch`, −1); otherwise a click, tail drawn back (`sting_wind`), the point lands ON THE FLOOR
where the player was (`sting`, −1, a 28 px box at the point) and stays stuck 0.75 s (`stuck`, harmless), then it walks on. Stomping
kills it. Touching it from the side, −1.

## Single player, server, client

- **Rule 1:** what hurts comes from state, `deadTimer` and the marks (`netPackExtra`: phase, marks, order, pattern, gap, hand;
  the small one, its mark). The tails are NOT simulated: each client moves its own `SegmentChain` in `render`. They can
  differ by a few pixels between clients and nothing depends on it.
- The chain steps at a fixed 1/30 s and is drawn interpolated, so it moves the same at any FPS. `COIL_K`, `FAST_K`, `CALM_K` in `ScorpionKit`:
  almost no bounce (`sin_rebote`: under 8 % past its target, in the rattle's time).
- Protocol 98.

## How to extend

- A new tail attack: a state, its entry in `ATTACKS`, its curve in `GS:moveTails` and its hit from pure data.
- Any tail, tentacle or rope elsewhere: `SegmentChain` knows nothing about scorpions.
- **Before it enters the story:** its secret exit and level, its music, the `collectibles.json` entry (not before: the Groove's gate
  asks for every splinter), the `Worlds.lua` line.

## Tests

`giantscorpion_rules` (one case per rule, both types), `boss_intro`, `boss_sim`, `sp_boss`, `online_boss` with
`LEVEL=tools/levelgen/arenas/jefe_escorpion.json`; `boss_frames` with `CLAW=1` (always in pincer range, never finished off) or
`SMALL=1 FOCUS=small` (follows the small one).

## History and decisions

- 2026-10-31: replaces the Emperor Penguin. The user's ideas: three tails with a rattle, joined or split, claws that catch, and
  tails made of live segments. Island (volcano), real grab, small one-tailed form and clasp agreed with the user. Design C
  «Obsidiana», shorter body, tails over the body. First sound rejected (3 clicks 0.36 s apart, not tied to the movement);
  approved: wooden rattle during the coiling.
- 2026-10-31, first play by the user: small one too big and its tail hitbox "absurdly big"; tail looked like it hit the floor but did not
  reach; it froze after attacking (no speed back); the boss so giant there was no room; "very jelly". Fixed: small ×3, boss ×7, tail
  reaches its mark exactly, small hit box, body passable and harmless (the user's request), arena 40 tiles wide (was 26), springs
  almost without bounce, far less screen shake. Renamed by the user: **Triple Strike Scorpion / Escorpión Triple Aguijón** (ids
  unchanged).
- 2026-10-31: chaining hits while stuck (and on the Groove) reported by the user → one hit per knockout, for all bosses ([system](system.md)).
- **Pending the user:** how the fight feels, numbers (timings, damage), whether hiding the caught player reads well or it
  should stay visible in the pincer. Nobody has played it. Sounds not listened to by Claude.
