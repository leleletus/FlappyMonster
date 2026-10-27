# Mega Mashup de los Cangrejos (Crab Mega Mashup) — the script

**Status: BUILT (0.5.62), not played by the user yet.** The design is the user's (answers of 2026-10-27). Level
`mashup_cangrejos` (Free Play, first card); director `src/world/entities/types/directors/crabmashup.lua`; harness
`mashup_rules` (+ `GAME=1`: the real game).

An EVENT boss rush: the four giant crabs — Mega Crabby (Tantrum), Icy Mega Crabby, Mega Gloomy Crabby and the Groove
Crab — one after another, **each in its own arena and with its own music**, then a FINAL where they tag-team on a new
stage, and a chain-explosion defeat. The music is ADAPTIVE: each crab's part loops for as long as the player needs and
only moves on, at a clean cut point, once the crab has taken its damage. Reached from **Free Play only** (a special
event card); single player and online co-op.

## The flow

```
event intro (8 bars, once, ON THE FINAL STAGE: the four in the background, one spotlight per bar; bar 5 → Tantrum's arena) → TANTRUM ⟲ → seam → ICY ⟲ → seam → GLOOMY ⟲ → seam → GROOVE ⟲ → seam
  → FINAL ⟲ (tag team, random order, 4 music variants) → END (chain explosion) → OUTRO ⟲ (empty stage, exit)
⟲ = loops until the crab has taken its damage; it then waits for the next CUT POINT (every 4 bars) to leave
```

## Rules

- **Damage per turn**: a crab moves on after taking **4 damage** in its turn (0.5.63, the user: "2 is too easy"; it
  was 2), any way. It is also the CAP: never more than that in one turn (the last hit only takes what is left). Online
  **+2 per extra player** (1 player 4 · 2 → 6 · 3 → 8 · 4 → 10), cap included.
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
- [x] 2. (0.5.62) ADAPTIVE PLAYER + scenes + darkness fade (engine pieces, no gameplay yet).
- [x] 3. (0.5.62) The level and the controller's main part: intro silhouettes, Tantrum → Icy → Gloomy → Groove with seams,
  transitions, re-intros, shared bar, 2-damage turns, dazed until the cut, no rage, Groove decks without rage,
  checkpoints per crab.
- [x] 4. (0.5.62) The final: tag team (random, enraged), background waiting / KO crabs, the four hazards, Gloomy's blackout,
  Groove's golden note, the stage (speakers, a big varied crowd), variants switching at cuts.
- [x] 5. (0.5.62) The end: chain explosion on the coda, the outro on the empty stage, results / ranking on the stage screen,
  the exit to Free Play; the Free Play event card.
- [x] 6. (0.5.62) Smart food director.
- [~] 7. (0.5.62, PARTLY: everything through the director's snapshot, +1 per extra player, ranking with names; NOT yet the
  return of a spectator at the next seam — it lives in the server's player list) Online co-op: everything through the controller's snapshot, +1 per extra player, spectate until the next
  seam, server-side checkpoints; Protocol + 1.
- [x] 8. (0.5.62) Tests (`mashup_rules` + the usual battery), docs, release.

## How it is built (0.5.62)

- **Level** `assets/levels/mashup_cangrejos.json`, from `tools/levelgen/arenas/make_mashup_cangrejos.py` (regenerating
  it loses editor changes): the boss zones of `guarida_cangrejo_rey`, `glaciar_cangrejo`, `gruta_lugubre` and
  `isla_del_groove` copied with their tiles, decorations, boss walls and phase blocks, 3 columns of rock between them,
  and a new final stage (28-column zone on sand, open sky, boss walls, the finish to the right). Zones 1-5 are `event`
  zones; 5 scenes (`Scenes.lua`). The player starts on the stage. Crab props (generic Boss props, group "Evento"):
  `event`, `mashupRole`, `fixedHp`, `rageMode` ('never' in their turns, 'always' in the final), hp 4 / +2 per player (0.5.63);
  the arena Groove `decksFromStart`, the final Groove `bigStage` (it draws the big stage: three crowd rows with the
  islands' Gummies, six speakers — also while it waits in the background).
- **Director** (`crabmashup`): music clock (piece, point, lap, pending switch) read from `cues.json`; phases wait →
  intro → crab / seam … → final → end → outro. A crab at 0 calls `crabDown` (Boss:damage) → `eventFrozen` (no AI,
  stars, only bounces) and the next cut is requested. Seams fade to black (0.45 s), move the players (`moveTo`:
  scene, camera cut, spawn), put the next zone in 'intro' (players frozen, cinema bars with its name) and start its
  intro; the fight starts with its loop. Final: the active crab comes down with its own intro (`swap`); the others are
  `offstage` ('wait' / 'ko', drawn at half size in the background with one of their own states: `LOOK`); hazards on
  the music's events (`cues.json` pops / music-box notes): Groove notes every even bar, Icy icicles (0.55 s crack
  warning), Gloomy blackout every 8 bars (`level.darkness` fade), Tantrum's reserve Crabbies from the ceiling every 8
  bars. End: one crab bursts on bars 5-8. Outro: zone cleared (walls down, finish open), results on the stage screen
  (time is not kept; damage, hits, falls per player — online with names: `level.playerNames`).
- **Checkpoints**: AdventureState passes `eventCheckpoint` (the crab you were on, 5 = the final) to the retry.
- **Music**: `Sound.followAdaptive` follows the director (`BossZones.adaptive`); online the director's netPack carries
  piece + point (interpolated) and the client's music follows it.
- **Known limits** (to judge playing): the crabs' own timers are not tuned for 2-HP turns; the Groove's hop length in
  the final is its 150 BPM one (the final runs at 170); the waiting crabs' hazards and their rate are first guesses;
  the results screen is plain text on a panel.

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
- 0.5.62, while it was being built: the user moved the EVENT INTRO onto the final stage ("the bosses must be on the
  final stage during the intro, and when the normal Mega Crabby's part starts the scene changes to its arena: I think
  it looks better"). Built so: bars 1-4 a spotlight per crab on the stage, bar 5 a fade to Tantrum's arena.
- Same session, the user saw boss walls blink for a frame in the online tests → the server's "entities near you" was
  measured from a dying player's body (it falls below the level); now from where they look, and the client keeps far
  entities as they were (docs/architecture/netcode.md).
- 0.5.63, the user's first look ("macabre bugs"): (0) the level started on a sunny coast and turned to night at once,
  with the whole stage popping in → the level's own sky is the stage's (night coast), its scene is on from the first
  frame, and the big stage SETS UP during the intro (speakers rise, the ball comes down, the crowd peeks in: the
  Groove's entrance timeline driven by the intro's music point); (1) the Groove crab was missing from the intro → the
  stage is wider than the screen and its slot was off-camera: the four slots now sit around the stage's centre, 4
  cells apart, vertically centred ("not floating up high"), and the camera looks at the stage's centre in its intros
  (`z.focus`); the player starts there too, in view; (2) 2 HP per turn was too easy → 4, +2 per extra player; (3) the
  Icy loop's last part (the breath) had an out-of-tune bass: the riff cell (root, 4th, MINOR 3rd) was played over
  major chords (B♭, C) → there it plays its chord's notes (root, 5th, its own 3rd); (4) the Groove crab only moved its
  trampoline during its entrance → in the event, once landed, it dances to the transition's beat (and while waiting
  in the final's background); (5a) its DJ decks came out without their platforms → event zones now take their phase
  from their bosses like the others (`BossZones`: the phase blocks); (5b) every hop sent it far away and it came back
  much later from under the ground → its hop is timed in its own song clock from the bar number, and in the event
  that clock started at 0 while the bar came from the event's music: the Groove's clock now comes from the event's
  music (`GC:songNow`). `mashup_rules` checks hops inside the zone and the platforms.
