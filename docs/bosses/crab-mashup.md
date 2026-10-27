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

## Decided after the first script (2026-10-27)

- Only the GROOVE's attacks follow the beat (it dances and attacks to the music, as in its own fight); the other
  three fight with their usual timing.
- The smart director outside the event: ONLY Extreme and Xtra Extreme, as today.
- The final stage: several speakers like the Groove's, and the Groove's audience but much bigger and more varied.
- Online, Race on a level with a boss is shown as **Cooperativo / Co-op** (0.5.60: `ModeTypes.forLevel`).

## Action plan (how it is built)

**Architecture** (generic pieces first, golden rule 2):

- **ONE level** `mashup_cangrejos` (`"event": true`), stitched by `make_mashup_cangrejos.py` (in
  `tools/levelgen/arenas/`) from the boss zones of the four STORY levels (`guarida_cangrejo_rey`, `glaciar_cangrejo`,
  `gruta_lugubre`, `isla_del_groove`: tiles, decorations, phase blocks, walls) side by side, separated by rock, plus a
  new FINAL STAGE. Each arena keeps its own boss zone and crab; the final stage has its own zone and four more crabs.
- **Scenes** (new, generic): level JSON `scenes: [{col, w, background, time, light, dark, snow, echo, spikeSkin,
  surfaceRow}]`; `Level:applyScene(i)` swaps those level fields (sky, light mood, darkness, snow, echo, spikes). Plus
  `level.darkness` 0..1 (fades in / out; `dark` stays the switch).
- **The event controller** (new entity `crabmashup`, `types/directors/`): runs on single player and on the server and
  travels in snapshots. It owns the MUSIC CLOCK (piece + position, advanced with the game time), the phase (intro,
  crab k, seam, final, end, outro), which arena / scene, the final's turn order, per-player stats, the background
  hazards, the checkpoint. Its zones are `event` zones: BossZones does not start them on its own.
- **Adaptive music** (`Sound.followAdaptive`): the pieces of a cue map (piece files, BPM, bars, cut points, what
  follows) play gaplessly FOLLOWING the controller's clock: the controller says piece, position and the next switch;
  the player starts the next piece half a frame early (like intro → loop today) and re-seeks if it drifts. Same code
  on single player and online clients (the server has no audio: it only runs the clock).
- **Boss hooks for events** (Boss base): `rageMode` ('never' | 'always'); at 0 HP an event boss does not die: it is
  DAZED (`event_daze`, no contact damage) until the controller moves it; `offstage` ('wait' | 'ko'): no AI, not solid,
  not hittable, drawn small in the background (`BossFx.drawScaled`); `holdIntro` (its intro ends but the fight waits
  for the downbeat). Per type: `STAGE_LOOK` (which of its states to draw for wait / ko / daze) and its rage switch.
- **Shared boss bar**: BossHud asks the controller (`hudBar()`) instead of the bosses.
- **Smart food director**: `bossdrops` rewritten (needs-based); outside the event only on Extreme / Xtra as today.
- **Free Play**: levels with `"event": true` get a highlighted EVENT card at the top of the grid.

**Steps** (each committed, tested and pushed; music first because the user must listen to the joins):

- [x] 1. (0.5.61) MUSIC IN PIECES: `crab_mashup.py` renders the pieces (intro 8 · Tantrum loop 24 · seam · Icy loop 24 · seam
  · Gloomy loop 16 · seam · Groove loop · seam · 4 final variants 16 at 170 · end 8 · outro 8) with ONE master gain,
  a cut point every 4 bars, the cue map and a preview of every cut → seam join. Catalog entry.
- [ ] 2. ADAPTIVE PLAYER + scenes + darkness fade (engine pieces, no gameplay yet).
- [ ] 3. The level and the controller's main part: intro silhouettes, Tantrum → Icy → Gloomy → Groove with seams,
  transitions, re-intros, shared bar, 2-damage turns, dazed until the cut, no rage, Groove decks without rage,
  checkpoints per crab.
- [ ] 4. The final: tag team (random, enraged), background waiting / KO crabs, the four hazards, Gloomy's blackout,
  Groove's golden note, the stage (speakers, a big varied crowd), variants switching at cuts.
- [ ] 5. The end: chain explosion on the coda, the outro on the empty stage, results / ranking on the stage screen,
  the exit to Free Play; the Free Play event card.
- [ ] 6. Smart food director.
- [ ] 7. Online co-op: everything through the controller's snapshot, +1 per extra player, spectate until the next
  seam, server-side checkpoints; Protocol + 1.
- [ ] 8. Tests (`mashup_rules` + the usual battery), docs, release.

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
