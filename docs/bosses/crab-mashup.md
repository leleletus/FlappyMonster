# Mega Mashup de los Cangrejos (Crab Mega Mashup) — the script

**Status: PLAN, nothing built yet.** The design below is the user's (answers of 2026-10-27); the points still open
are at the end. Tick a milestone (`[x]`) in the same commit that does it and say in which version.

An EVENT boss rush: the four giant crabs — Mega Crabby (Tantrum), Icy Mega Crabby, Mega Gloomy Crabby and the Groove
Crab — one after another, **each in its own arena and with its own music**, then a FINAL where they tag-team on a new
stage, and a chain-explosion defeat. The music is ADAPTIVE: each crab's part loops for as long as the player needs and
only moves on, at a clean cut point, once the crab has taken its damage. Reached from **Free Play only** (a special
event card); single player and online co-op.

## The flow

```
event intro (4 bars, once) → TANTRUM ⟲ → seam → ICY ⟲ → seam → GLOOMY ⟲ → seam → GROOVE ⟲ → seam
  → FINAL ⟲ (tag team, random order, 4 music variants) → END (chain explosion) → OUTRO ⟲ (empty stage, exit)
⟲ = loops until the crab has taken its damage; it then waits for the next CUT POINT (every 4 bars) to leave
```

## Rules

- **Damage per turn**: a crab moves on after taking **2 damage** in its turn, any way (two stomps, or one ground
  pound). It is also the CAP: a crab can never take more than 2 in one turn (a stomp then a ground pound deals 1 + 1,
  not 1 + 2). Online the number is **2 + 1 per extra player** (1 player 2 · 2 players 3 · 3 → 4 · 4 → 5), cap included.
- **One shared boss bar** for the whole event, with the ACTIVE crab's name on it (it changes with each crab). Main part:
  4 crabs × 2 segments; the final: another 4 × 2 (both scaled online as above).
- **Each crab fights as in its level, NEVER enraged** in the main part (rage is suppressed whatever its HP). They are
  enraged only in the final. Their openings are their own:
  Tantrum — stuck after the ceiling drop · Icy — ground pound on a frozen claw after the frost clap · Gloomy — tired
  and lit by the flashlight (its arena is dark) · Groove — the DJ DECKS (its phase-2 opening, here without rage and
  from the start; no golden notes): both decks spinning → bass drop → knocked out → stomp / GP.
- **After the winning hit** the crab is DAZED (stars, no contact damage, no attacks) until the music reaches the next
  cut point (≤ 4 bars), then the seam starts.
- **Difficulty**: the selector applies as usual (pace, player HP, …); the 2-damage rule does not change with it.
  (Xtra Extreme has one boss per arena since 0.5.24; nothing to switch off.)
- **Help**: food and extra lives come from the SMART DIRECTOR (below), on every difficulty in this event, scaled by it.
- **Checkpoints**: game over in the main part → restart at the crab you were fighting (the ones beaten stay beaten).
  Game over in the final → the final from scratch (all four, full final bar).

## The music, rebuilt for this (`tools/music/crab_mashup.py`)

The current linear track (0.5.58) is reworked into PIECES. Each crab keeps its own tempo; every loop has a **cut point
every 4 bars** where it can go into its seam without a jump.

| Piece | Content (the user's picks) | Tempo | Length |
|---|---|---|---|
| event intro | tribal drums, the slap brings the cell (as now) | 180 | 4 bars, once |
| TANTRUM loop | theme A → war chant → tribal bridge | 180 | 24 bars |
| seam T → Icy | 4 bars: scene change + Icy's re-intro and pose | 180 | 4 |
| ICY loop | thaw B → chorus C → breath K | 180 | 24 |
| seam Icy → Gloomy | 4 bars, slows to 144 | 180→144 | 4 |
| GLOOMY loop | legs bridge → war chant in the cave | 144 | 16 |
| seam Gloomy → Groove | 4 bars, key lift D → E minor | 144→150 | 4 |
| GROOVE loop | stop-time solo → slap riff A → climax | 150 | solo 8 + A + climax 16 |
| seam Groove → final | 4 bars, accelerates | 150→170 | 4 |
| FINAL × 4 variants | the current "todos" finale (war chant over the slap riff, legs, music box) with the ACTIVE crab's instrument leading and the others quieter; all four variants in E minor, cut into each other at any 4-bar point | 170 | 16 each |
| END | the current coda (all four in D minor, the ♭VI–♭VII–i climb) ending on a HELD final chord instead of la llamada (it does not loop) | 170 | 8 |
| OUTRO loop | a relaxed Groove riff (slap + soft drums) with the crowd | 150 | 8 |

How a cut works: every 4-bar phrase of a loop ends so that the seam's first bar follows it naturally (same harmony
rule at every cut point); the generator writes each piece as its own file plus a **cue map** (bars, BPM, cut points),
and checks every cut → seam join by numbers (no clicks, level steps, harmony). The intro and seams also leave room
for the scene change.

Engine side (new, generic, `src/audio/`): an **adaptive music player** that plays pieces gaplessly (LÖVE queueable
source), knows the song position from the cue map (the song CLOCK the fights use), and on request "leave at the next
cut point" schedules the seam on the exact sample. Online the SERVER decides the cut (by bar number) and the clients
schedule the same bar.

## The main part, crab by crab

| Crab | Arena (its own, reused) | Re-intro (during its seam) | Opening |
|---|---|---|---|
| Tantrum (Mega Crabby) | `jefe_cangrejo` | its fall + roar, shortened, + a pose on the seam's last bar | stuck after the drop |
| Icy Mega Crabby | `jefe_cangrejo_helado` | its own, shortened + pose | frozen claw (GP) |
| Mega Gloomy Crabby | `jefe_lugubre` (dark, flashlight) | falls from the dark, shortened + pose | dazzled by the flashlight |
| Groove Crab | `jefe_groove` (stage, crowd, deck platforms) | drops from the sky with its stage, shortened + pose | DJ decks → bass drop → KO |

The **seam** (4 bars) = the transition: the screen changes to the next arena (fade / wipe), the next crab's re-intro
and pose play with the players frozen (as in a boss intro), the bar's name changes, and the fight starts on the first
downbeat of that crab's loop.

## The final — TAG TEAM (new big stage)

- A **new arena**: a big concert stage mixing the four settings (beach, ice, cave, the Groove's stage), with a place at
  the back where beaten crabs lie KO'd out of the way.
- **One crab fights on the floor at a time, ENRAGED**, chosen at RANDOM each time. The music switches to its variant
  at the next cut point.
- The crabs **waiting** for their turn stay in the background and each throws ONE hazard on the beat:
  Tantrum — drops Crabbies from the ceiling · Icy — icicles falling on the music-box notes · Gloomy — a short
  blackout (flashlight only) · Groove — colour notes on the bass pops.
- The crabs **beaten** in the final go to the KO place and stay there knocked out: no contact damage, no hazards,
  until the defeat scene. So the final gets calmer as it goes; the last crab is a duel.
- Each crab again needs 2 damage (online: scaled) with the same cap; after the hit, dazed until the cut point (as in
  the main part), then it is moved to the KO place and the next one jumps in with a short pose.
- **Gloomy's turn**: the stage lights fade OUT (darkness fading in, flashlight on) and come back when it is beaten.
- **Groove's turn**: the GOLDEN NOTE is its opening here (no decks on the final stage).

## The defeat — CHAIN EXPLOSION

The END music: on each hit of the coda's climb one crab BURSTS (like the Groove Crab's death: blasts, pieces, confetti,
big shake), the last one on the held final chord; the crowd goes wild. No mirror shard (event).

Then the player **stays on the empty stage**: the OUTRO loop plays with the crowd cheering, the stage screen shows the
results / online ranking, and an EXIT (door / flag) goes back to Free Play.

## Online (co-op)

- Online boss levels are played in the **Race** mode, which is co-op: everyone in the same fight against the same
  crabs (the server's). Anyone's hits count; the per-turn number scales with the players (above).
- The server decides cut points, seams and scene changes; everyone changes scene together.
- A player out of lives SPECTATES and comes back at the next seam. If everyone is out → checkpoint (as above).
- **Ranking** at the end: total damage dealt and fewest deaths, per player, on the stage screen.

## The smart food director (all boss fights)

Replaces today's random director (`types/directors/bossdrops.lua`: food every ~14-15 s on Extreme / Xtra, lives every
~70 s on Xtra) in EVERY boss fight; in this event it works on every difficulty, scaled and balanced per difficulty.

- Food when it is NEEDED: the player at LOW HP (threshold by max HP and difficulty), BEFORE A HARD PART (a crab change,
  the final) if hurt, or STRUGGLING (many hits / deaths lately, a long time without dealing damage). Never when not
  needed.
- Where: a SAFE and REACHABLE spot on the floor, away from the boss and from where its next attack will land, not on
  the player.
- Extra lives: also smart (e.g. at the last life), amount by difficulty.

## The reward

An EXCLUSIVE COLLECTIBLE. The collectibles system does not exist yet: this event must give one when it does. (Note,
nothing to build now.)

## Base work (golden rule 2: generic, in the base)

1. **Adaptive music player + cue map** (`src/audio/`), used by the event and available to any level / boss.
2. **Song clock from the player** (the Groove Crab's `songT` / `GC.where` move to it; no behaviour change).
3. **Multi-arena boss event**: one level with the 5 arenas (the 4 reused + the final stage) and a controller that
   runs the turns, the shared bar, the transitions (screen change, players moved, frozen re-intro), checkpoints per
   crab, spectate-until-seam.
4. **Boss hooks**: `damageCap` per turn, `noRage`, `dazedUntilCut`, `enterStage` / `leaveStage`, `koPlace`, a
   "background hazard" mode per crab, Groove decks without rage.
5. **Darkness that fades** (`level.darkness` 0..1; today `level.dark` is fixed at load) for Gloomy's final turn.
6. **Smart director** replacing `bossdrops`.
7. **Free Play special event card** (top of the grid, its own look) + ES/EN keys for the name.

## Network

New entity types (event controller, final stage pieces) and new packed fields on the crabs → `Protocol.VERSION` + 1
and `version.txt`. The music position travels as the cue bar the server announces.

## Tests

- New harness `mashup_rules` (row in `tools/tests/README.md`): the cap (stomp + GP = 2), dazed until the cut, the cut
  only on 4-bar points, seam → next arena and crab, no rage in the main part, the final's random order and KO place,
  background hazards stop when beaten, checkpoints, online scaling.
- Music: the generator checks every cut → seam join; `tools/music/levels.py`.
- `boss_sim` / `boss_intro` / `online_boss` / `sp_boss` on the new level; `groovecrab_rules` after the song-clock move;
  `difficulty_rules` for the smart director; `run.sh all`; `docs_reference`.
- Needs a person: the music joins (not listened to by me), readability of each crab, the final's chaos, HP / food tuning.

## Milestones

- [ ] 1. Music in pieces + cue map + every cut → seam join checked (the user listens to the joins first).
- [ ] 2. Adaptive music player + song clock (Groove Crab moved to it, unchanged).
- [ ] 3. Event level + controller + TANTRUM → seam → ICY (a playable slice for the user).
- [ ] 4. GLOOMY and GROOVE (decks without rage).
- [ ] 5. Final stage + tag team + hazards + KO place + darkness fade.
- [ ] 6. Chain explosion, outro stage, exit, Free Play event card, intro silhouettes.
- [ ] 7. Smart food director (all boss fights).
- [ ] 8. Online co-op: server-driven cuts, scaling, spectate, ranking.

## Still open (not asked yet; proposal in brackets)

1. While a crab of the main part fights "as in its level": should its attacks also snap to the beat of the music?
   [yes, generic: an attack starts on the next beat of the song clock; no other change].
2. The event intro: four silhouettes in the fight order (decided); does the title say "MEGA MASHUP" or the full name?
3. Single player: does the stage screen show results (time, damage taken, deaths) as online does? [yes].
4. The smart director outside the event: only Extreme / Xtra as today, or also Easy / Normal? (The user picked "every
   boss fight"; the amounts per difficulty are to tune.)
5. The final stage's look and size; where the KO place is (a balcony at the back?).
6. Does the event card show a best time / best rank? [yes, local].

## History and decisions

- 2026-10-27: the music came first (0.5.57, a linear track), then 0.5.58 (Groove section = its climax; a coda with all
  four). The first script (synced to the linear track, all four together in the finale) was replaced the same day by
  the user's design: each crab in its own arena with a shared bar and a re-intro; move on after 2 damage (capped per
  turn); the music split into loops with cut points every 4 bars and 4-bar seams so a crab lasts as long as the player
  needs; no rage in the main part; order Tantrum → Icy → Gloomy → Groove; Groove by its decks; the final as a tag team
  (random, enraged, waiting crabs throw hazards, beaten ones lie KO'd out of the way) on a new stage at 170 BPM with a
  music variant per active crab; chain-explosion defeat on the coda ending on a held chord; stay on the stage with a
  soft Groove outro and an exit; food from a smart director in every boss fight; online co-op scaled +1 per extra
  player with a ranking; the reward a future exclusive collectible. "All four at once would be hell" (the user) →
  the tag team.
