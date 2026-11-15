# Starway, second wave: Pulsar, the Star Stage, the Sanctuary of the Beat, and the boss ideas (2026-11-15)

Status: **levels built (0.5.230); the user edited Pulsar and the Sanctuary by hand and picked idea 2: the Metronome Golem is BUILT (0.5.231, [metrogolem](../bosses/metrogolem.md))**.

The user's notes after playing (2026-11-15): the mini blocks of the relief made some paths impossible and opened others
("decoration must never help": now non-solid), the orbiting stars did not hurt (fixed), the nebula rock was too noisy
(redrawn). Second round (0.5.232): orbits at half speed (one turn per phrase), the Sanctuary plays `estelar_pulsar`
(the fight keeps `estelar_boss`, the beat clock changes tempo with it), the Golem reworked ([metrogolem](../bosses/metrogolem.md#history)).

The user's brief (2026-11-15), after Vía Estelar ("very good, but long, repetitive and somewhat tedious"):
- a remaster of the Vía Estelar theme and three new tracks (another level, a bonus, a boss) — delegated to a music agent;
- the **ceiling and wall versions of the clap spikes** and **another rhythmic obstacle or enemy**;
- a new level that is **less tedious and exploits the beep blocks much more**, with pure parkour and platforming;
- the bonus and the boss level, same spirit;
- **every level with an interesting structure**: no flat square walls without relief or decoration — the user noted
  that most generated levels have this problem and that the only levels with "geological" variety are the ones they
  edited by hand. Use the background plane (the second block layer) to the full;
- mid-work note: "the double jump lets the player skip paths like `ooo HHH ooo HHH`" (pink / cyan runs of 3 with gaps
  of 3) → use formations that cannot simply be jumped over.

## What was built

| Thing | Where |
|---|---|
| Clap spikes from ceilings and walls (prop `dir`: up / down / left / right; the plate turns with them) | [traps-and-mechanisms](../entities/traps-and-mechanisms.md#rhythm-objects-of-starway-05224) |
| **Orbiting stars** `orbitstars` (proposal #9 of [starway-rhythm-objects](starway-rhythm-objects.md)): 1-4 spiked stars orbiting a crystal hub, one quarter turn per beat in a snap | same page |
| Relief helper `tools/levelgen/geo.py`: floating islands with an inverted-dome underside and stalactites, floating MASSIFS, rock ceilings, carved caves with the cave wall on the background plane, arches; the steps of every outline softened with MINI BLOCKS (the Starway tiles are now mini-block kinds); background spires out of a cloud sea, distant islands, towers, porticos, arches | [generator-and-solver](../levels/generator-and-solver.md) |
| The three levels, `tools/levelgen/levels_estelar_2.py` | below |

### The double-jump rule (the user's note)

The physics give a running double jump of about **5 cells across and 3 rows up** (run 266 px/s, jump 568 px/s, gravity
1600). So in these levels a gap that only ONE colour bridges is always **≥ 7 cells wide or ≥ 4 rows high**, and the
formations are:
- **two adjacent runways** (cyan 7 + pink 7 over spikes): with either colour alone the gap is 7, so you enter the cyan
  on the cyan phase and step onto the pink exactly on the switch;
- **long single-colour runways** (12 cells): crossable only by running the whole phrase, from the start of it;
- **runway + pads** (pink 3 · cyan 8 · pink 3 · cyan 3) under a rock ceiling with clap spikes (no jumping over);
- **stairs rising 2 rows per step** (the same colour is 4 rows up: out of reach);
- **vertical drops** (half-shaft floors, the same colour 8 rows below).

## Pulsar / Púlsar (`pulsar`)

240 × 40, music `estelar_pulsar` at **140 BPM** (phrase 3.43 s: the blocks switch faster than in Vía Estelar),
`timeLimit` 480, Free Play, online `race`. Six stretches, about a third of Vía Estelar's length:

| Cols | Stretch | What |
|---|---|---|
| 2-17 | Take-off | big floating island, sign `pulsar.intro` |
| 19-52 | The needle stair | beep steps two by two of the same colour (two per phrase), the jump to the other colour on the switch; landing island |
| 53-97 | The clap rift | a floating MASSIF crossed by a tunnel (cave wall behind, on the background plane): floor, CEILING and both claps; the PIT (cyan 7 + pink 7 runways over spikes); the CHIMNEY climbed on alternating pink / cyan ledges with WALL claps; star 1 in a niche |
| 98-143 | The orbits | open sky: an orbit over the first gap, a metronome pair meeting under two orbiting stars, a 12-cell pink runway under a counter-rotating orbit (star 2 at its hub), a Gust |
| 144-165 | The shaft | a hollow geode: half-shaft floors pink / cyan alternating, drop off the edge just before the switch; wall claps; spikes at the bottom; exit tunnel |
| 166-238 | The final sprint | on-beat spring to a ledge; pink · cyan runway · pink · cyan under a floating rock ceiling with claps; metronome through three orbiting stars; star 3 above with a spring; the 2-row stair to the finish |

Checked with `level_solve` stretch by stretch (2026-11-15): all OK — start → stair, the switch jump, the stair top,
landing → pit, the pit swap, the chimney, the orbits, the pink runway, the shaft (see the shaft line in the hand-off) —
the whole level in one search runs out of budget, as with Vía Estelar.

## The Star Stage / El Escenario Estelar (`escenario_estelar`)

The bonus (King of the Hill against the bot), 72 × 28, music `estelar_bonus` at **126 BPM**, `matchTime` 100. A
floating STAGE between two islands; zone 1 on the stage floor, zone 2 on a crystal ledge above it (one active at a
time). The islands join the stage by single-colour runways (pink left, cyan right: gap 6 with the other colour). Upper
tier in 2-row steps (crystal ledges → pink / cyan steps → the top), plus a plain trampoline in the middle. Clap plates
on the islands and an orbiting star over each runway (away from the zones). A SOLID cloud sea below: falling costs time,
not a life; trampolines at both edges bring you back. Respawning Gummies and a Hopper (40 % of their points), two
stars. Background: an arch and a portico behind the stage, towers on the islands. `bot_nav`: reaches both stops, holds
the zone 80 %, 20 shoves in the hunt.

Not in the story (there is no Starway island yet): Free Play lists it as a King of the Hill arena.

## The Sanctuary of the Beat / El Santuario del Compás (`santuario_del_compas`)

The boss level, 130 × 32, music `estelar_boss` at **150 BPM** (phrase 3.2 s). A short approach (cols 2-80: 2-row
stair, a cyan runway under a floating ceiling with claps, metronomes between orbiting stars) to a crystal TEMPLE
(arena cols 84-125, floor row 26): a floating massif with a peaked roof, a hanging ceiling with clap spikes, a brick
wall with windows and pillars behind. The arena floor is brick at both ends and, in the middle, 4-cell pink / cyan
segments over a spike pit (half the floor vanishes every phrase); crystal ledges low on both sides, a pink and a cyan
ledge, a long pink one high in the middle; on-beat springs in the corners. **The boss is not there yet**: until it
exists the finish is behind the arena, so the level can be played through. When the boss is built: a boss zone over
the arena (its walls close the entrance and the exit), the finish after it.

## Boss ideas (for the user to pick; nothing built)

All use the arena above and the beat clock (golden rule 1: everything a client draws comes from the clock or the
snapshot). Names are proposals.

1. **The Conductor / El Director** — a crystal conductor floating over the arena, baton in hand. Each phrase he
   "conducts" one colour: on beats 6-8 he points at pink or cyan and the floor of THAT colour becomes the solid one at
   the switch (not always alternating: he can repeat, the warning tells which). Attacks on the beat: a baton slash
   that sends a wave along the solid floor (jump it on beat 4), star notes that fall in eighths. Weak point: after a
   repeat he is tired for one phrase and comes down to the floor — stomp him. Phase 2: he speeds the music up (the
   hurry rate, ×1.19) for the rest of the fight.
2. **Metronome Golem / Gólem Metrónomo** — a huge pendulum golem in the middle of the arena. Its pendulum sweeps the
   arena one side per beat (a hazard you dodge by standing on the side it has just left), and every phrase it STOMPS:
   the floor colour under it switches early. Hit its lamp (head) by an on-beat spring launch on the switch. Simple and
   very readable.
3. **Echo Queen / La Reina del Eco** — she REPEATS the player: during a phrase she records the player's jumps and plays
   them back the next phrase as shockwaves along the floor (a call-and-response duel, like the Groove crab's rhythm
   duel but platforming). Vulnerable when her copy lands on a block that just vanished.
4. **The Beep Twins / Los Gemelos Beep** — a pink and a cyan crystal spirit. Each is solid / attackable only while its
   colour is solid, and hides inside the blocks of its colour otherwise; they swap places on every switch. Kill both;
   when one dies the arena keeps only the other colour's blocks switching.
5. **Constellation Dragon / Dragón Constelación** — a dragon made of orbiting stars (the new `orbitstars` as its body)
   that coils around the arena in quarter turns on each beat; its head is the only part you can stomp, and it is only
   reachable from the upper ledges on certain beats. The most spectacular, the most work.

Recommendation: **2 (Metronome Golem)** for a first Starway boss — it fits the arena as it is, it is easy to read, and
it reuses the beat clock directly; **1 (the Conductor)** if a richer, more musical fight is wanted.

## Needs a person

The music (not listened to), the feel and difficulty of the faster beat, whether the two-runway swaps and the shaft
drops are fair, how the relief and the background plane look in motion, the bot in the bonus as an opponent.
