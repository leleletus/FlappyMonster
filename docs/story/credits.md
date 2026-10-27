# Credits

**What:** a rolling credits film. It plays after the story's ending film (ending → **credits** → results) and can be
watched any time from **Settings → CRÉDITOS**. Over the Flappy mode's brick background (repeating both ways, drifting
sideways, rising slowly with the text and slowly changing colour), the remastered logo drops in; after 16 beats
everything scrolls up while a medley of the game's own soundtrack plays — one theme per island, two boss themes and
the Mirror boss (theme, rise, climax) — each credit block entering from the bottom exactly when its song starts. Under
each block a **live stage**: a little strip of that island that is really PLAYED by the game (its enemies, bombs,
mortars, trampolines, thin ice, lava, the real Mega Crabby and Mega Ice Crabby, with their sounds) while the monster,
driven by a small bot, runs, stomps, ground-pounds, dies and respawns. Then **the final fight**: the monster against
the Mirror in its arena, full screen, PLAYED with the game's real physics (not animated) and identical every time;
the monster wins at the end of the Mirror's music, the Mirror explodes, flies at the camera, **crashes into the
screen** (broken glass), slides down and falls away, and "¡GRACIAS POR JUGAR!" appears. It ends there. Skippable like
every film (hold a button 1 s). About 2:45.

**Files**

| File | Role |
|---|---|
| `src/story/CreditsFight.lua` | the final fight's PILOT: the monster's buttons each 1/60 s step, from where the Mirror is and what it does (below) |
| `assets/story/sets/credits_espejo.json` | the fight's arena (20×11, full screen; `espejo()` in `tools/levelgen/make_credits_sets.py`): ash over basalt, two side platforms and a high one, the Mirror with its props for the credits |
| `assets/images/fx/screen_crack.png` | the broken screen glass of the finale (`tools/art/fx/make_screen_crack.py`, drawn at ×5) |
| `assets/story/films.json` → `credits` | the timeline: 13 scenes, each with `bpm`, `beats`, `cues` and `src` (track of the catalog, part, start bar, bars: where its music comes from); `bars: false` (no cinema bars) |
| `assets/story/credits.lua` | the TEXT, one block per scene (headings are language keys `credits.*`; proper names are not translated) and each block's `stage` (its live stage) |
| `src/story/films/credits.lua` | the film: background, layout and scroll, the live stages' life (built 160 px before entering, invisible and frozen until it APPEARS: it fades in as it enters — 0 with 3 rows in view, 1 with its ground in view (`PLAY_FROM`) —, played from the moment it starts to show, dropped when gone), random fireworks (`src/ui/Celebration.lua`, more often at the climax and the goodbye), the mirror, Claudio's dance and the flying monster |
| `src/story/LiveStage.lua` | a LIVE STAGE: an `AdventureState` in demo mode (like the menu background) on a set, at fixed 1/60 s steps with its own seeded random generator (the same every time; particles and decorations use the normal one), real sounds, fixed camera, no sky (`demo.noSky`), its SOUND through a proxy (effects at `LiveStage.GAIN` = 0.5 of the game's volume × the strip's fade; music calls ignored, so a respawn never starts the level's track), no boss-zone control (`demo.noBossCtl`: bosses start fighting at once, no intro, music or bar). The monster is driven by the MENU BACKGROUND's bot (`src/ai/Bot.lua`, careful mode: it jumps over, stomps or waits for nearby enemies) on each strip's navigation graph (`assets/nav/credits_*.json`, `run.sh bot_nav BUILD=1 -- assets/story/sets/credits_x.json` — rebuild after changing a strip); instead of a finish line it TOURS varied goals (`LiveStage:_pick`: an enemy to stomp, a bomb to light, a star, any node of the graph — a ledge, across a pond — or the other end), resting a moment at each. `stats` (kills, explosions, deaths, goals, jumps) for the tests |
| drawing of a stage | into its own canvas, then its left, right and bottom edges are FADED in pixel steps (the alpha × `assets/images/fx/fade_edge.png`, `tools/art/fx/make_fades.py`, premultiplied) so the ground never ends abruptly; and the whole strip fades out as it rises (gone when its bottom reaches mid-screen: `FADE_TO`, `FADE_LEN`), so the previous section is never seen above the next one |
| `assets/story/sets/credits_*.json` | the 8 stages (20×6 cells: rows 1-4 air, 5 ground; real levels, they open in the editor), written by `tools/levelgen/make_credits_sets.py`; `openTop` (no ceiling over them); the two boss strips have a 10-row zone like their real arenas, rising above the strip, so the ceiling the bosses and their Crabbies climb to is out of view |
| `tools/music/credits_music.py` | builds `assets/music/story/story_credits.ogg` (catalog `story_credits`) from the `src` of each scene |
| `assets/legal/THIRD_PARTY_LICENSES.txt` | the FULL texts of every third-party license (written by `tools/legal/make_licenses.py`: LÖVE's own `license.txt` with everything it bundles, the `libs/` headers, `tools/legal/OFL-1.1.txt` for the font, the music references and trademarks) |
| `assets/images/enemies/claudio/claudio_dance-Sheet.png` | Claudio's dance frames (arms up, wave, wave high): made by `tools/art/enemies/make_claudio_extras.py baile` from the user's `claudio_idle.png` (only the arms move); `assets/anim/claudio.json` sequences `cheer` and `wave` |
| `src/states/menu/SettingsState.lua` | the CRÉDITOS button |
| `src/states/story/StoryMapState.lua` | ending → credits → results |

**Sync:** the film and the music come from the same table. Every scene lasts exactly `src.bars` bars at its `bpm`
(the script asserts that each source loop is a whole number of bars at that tempo), so every song change falls on
its picture; the film follows the music clock while it plays (`Film`). The scroll speed is ONE constant: the
smallest that lets every block (text + its stage; the stage's two top air rows overlap the end of the text) fit in its song and lets the last block (`bola`) leave the top
before the final fight; each block's position is computed so that its top enters the screen (92 % of the height)
at the start of its scene. Changing the text re-computes the layout by itself; changing a scene's song or length
means editing `films.json` and re-running `credits_music.py`.

**The medley:** map theme ("Rumbo a las islas", the logo), pradera_1, costa_1, fortaleza_1, nieve_1, cuevas_1,
volcan_1, crab_tantrum_normal, snowball_boss, mirror_boss (A; the fight on its rise D and climax E: one shared gain, so
the fight starts soft and gets loud), victory (the finale, then its first beat held as the final chord). The 0.5.49
ending reused the same music sections (scenes renamed rise/climax/bye → fight/fight2/finale): `story_credits.ogg` did
not change. Every cut is on
a bar line; each piece is RMS-matched to −15 dBFS; a 12 ms crossfade and a noise-channel crash hide the change of key.
**Verified by numbers only: not listened to.**

**Content** (the user's answers, 2026-10-20): ORIGINAL IDEA djvemo (the first Flappy Monster and ideas for the
remake); REMASTERED mtvemo (serqwjahk): direction, design, programming, art, music, levels and story; ENGINE LÖVE 11.5;
CONSOLE AND MOBILE love-nx (retronx-team), love-android; LIBRARIES baton, bitser, classic + json.lua, sock.lua,
hump.timer, lovesize; TOOLS; INSIDE LÖVE (its bundled libraries) + where the full licenses are; FONT Press Start 2P
(CodeMan38, OFL 1.1); SOUND (2A03 / VRC6 / N163 style, trademarks note); MUSICAL MOTIFS "Tentacle Tantrum" and "Winter
Fallympics" (Jukio Kallio · Daniel Hagström), "It's Me, It's Verity" (Horror Skunk), "Spider Dance" (Toby Fox, the
inspiration for an effect). Claude appears only as Claudio (the user's choice: no credit line).

**The final fight** (scenes `fight` + `fight2`, 48 beats at 158 = 18.2 s; `finale`, 28 beats at 132):
- A live stage (`LiveStage.new('credits_espejo', 31, { pilot, immortal })`) drawn full screen; it is built (and its camera
  set) in the last beat of `mirror` and played from the first frame of `fight`. The monster is driven by
  `CreditsFight` instead of the menu bot (immortal: the Mirror's hits only knock it). The Mirror (props in the set: HP 3,
  copy delay 1.4 s, no dodge, no random steps, an arena attack every 3 s, 1.3 s pause after its dive) fights for real:
  it copies the monster's inputs with a delay, dives from its floating mirror and leaps from the platforms.
- The PILOT: runs away from the Mirror's attack mark to an open spot (never under a platform: its dive lands on the
  platform and stays there); between hits it moves around the arena (and the Mirror copies it); in an attack window
  (`FIGHT_WINDOWS` = {3, 12.5} s, then always) it goes for it — right after its dive (`recover`), or by standing still
  next to it until the Mirror, replaying that stillness, also stands still, and then jumping (second jump at the top)
  and GROUND-POUNDING it within the copy delay. Pound = 2 HP and KO; a hit while KO = the last one. When it wins it hops.
- Same every time: fixed 1/60 steps, the stage's own seeded random, and the camera set before the first step. Result:
  pound at 6.50 s, final hit at 15.63 s (the music of the fight lasts 18.23 s) at any frame rate (`FIGHT=1 FPS=30/47/144`).
  Its `DEATH_HOLD` is infinite: it keeps exploding (its real 'dying_hold' blasts) until the finale takes it. If, on some
  other machine, it were not defeated when the finale starts, the finale gives it the last hit (safety net).
- `finale` cues: `fly` 1 (the film takes the Mirror out of the arena: it flies in an arc to the screen centre, growing to
  ×4 and flipping — never rotated —, drawn with its own render in the 'dying_fall' look: X eyes), `crash` 3 (screen
  crack ×5, white flash, shake, ice-break + explosion + ground-pound sounds), `slide` 7 (slips down the glass), `fall`
  10 (drops off the bottom), `thanks` 12 ("¡GRACIAS POR JUGAR!" drops in, under the impact; the arena dims). Ends there.

**How to extend:** a new credit = a line in `assets/story/credits.lua` (+ its keys in `es.lua` and `en.lua`); a new
third-party component = an entry in `tools/legal/make_licenses.py` (and re-run it) and a line in the credits; a new
song in the medley = a scene in `films.json` with its `src`, a `draw` in `src/story/films/credits.lua` (scroll scenes
are listed in `SCROLL`) and `credits_music.py`. A new or changed stage = its function in
`tools/levelgen/make_credits_sets.py` (re-run it) and `stage = 'credits_<id>'` in its block; watch it with
`run.sh story_film STAGES=1 [STAGE=credits_x]`. The fight: `run.sh story_film FIGHT=1` (`FIGHTDBG=n`: positions every
n frames; `FPS=n`; captures `fight_NN.png`); after changing the arena, the Mirror's props or `CreditsFight`, check that
the final hit still lands in the last 3.2 s of the fight music.

**Tests:** `story_film` (all films, `FILM=credits` alone): the 13 scenes in order with their lengths, the music lasts
exactly the film, every block enters at the start of its song and fits in it, the last one is out before the fight,
the 8 live stages are played and things happen in them (≥ 8 enemies killed, ≥ 2 explosions, the monster dies at
least once), `final`: the fight was played, the Mirror fell IN the fight and the finale flew it away; captures
`film_credits_*.png` (7 of the finale). `STAGES=1`: each stage alone for 25 s with what happened and 4 captures, and the
bot neither jumps in place (≤ 3 jump sounds within 32 px in 3 s) nor trembles (≤ 5 direction changes on the ground in 1 s);
`JUMPDBG=1` / `BOTDBG=n` trace it. `FIGHT=1`: the fight alone (above). `story_flow` goes through ending → credits → results.

**Decisions / history**
- 2026-10-20 (3.105.0): requested by the user (after the ending; logo on black, scroll, a medley of the best themes —
  one per island, especially the Mirror boss —, animated sprites, Claudio's dance and goodbye at the end, all
  licences credited). ~3:15 "if it fits without being too slow": it came to 2:53 at 43 px/s.
- First layout let the last block (the tools) leave during the Mirror theme: the scroll had to run at 64 px/s and
  the screen was empty most of the time; the tools went to the libraries' block and the Mirror theme became the
  monster flying across while the last lines leave.
- Legal note (also in known-debt): crediting the quoted motifs is courtesy, not a licence; for a commercial release
  they should be rewritten or licensed.
- Judged by the user (0.5.3): see below.
- 2026-10-20 (0.5.3), the user watched them: "good", with things to improve: the pufferfish, the Fortress Gummy and
  (maybe) Gloomy walked backwards; the monster was barely visible (black on black); the background should not be
  plain black (the Flappy bricks, looping both ways with their colour changes); the Claudio + flying monster part
  was a bit long ("maybe mix them?"); Mega Crabby and Mega Ice Crabby had no claws or head spikes; and MORE things
  happening (falling, jumping, dying, bombs exploding and destroying enemies, with sounds) — always with the game's
  real physics, never simulated. The creature parades (animation sets drawn by hand, all flipped the same way, so
  the ones whose art faces the other way walked backwards, and the Megas without their separately drawn claws) were
  replaced by the live stages, where every creature is the real entity. The Mirror theme scene went from 8 to 6 bars
  (the flight moved to the goodbye) and the goodbye from 10 to 7 bars, with the monster flying a figure-eight around
  Claudio: 2:53 → 2:45; scroll 43 → 57 px/s (the stages make each block taller). Not judged yet: how the stages play,
  the sound of the effects over the music, the speed.
- Then, the user: the strips ended abruptly ("they should fade out") and the previous section was still visible at
  the top when the next one began (lava and basalt above the Mega Crabby): edges faded with the stepped mask, and
  each strip fades out before the next section's strip arrives.
- 0.5.4, the user: stage audio at half the game's volume and fading with its strip; a death in pradera restarted the
  level's music on respawn and ruined the sync (music calls from inside a stage are now ignored); the strips'
  ceiling was far too low — Crabbies hung upside down a hand above the ground, "MUY RARO" (the out-of-map ceiling:
  `openTop`; in the boss strips the boss zone's top edge, which Megas and minions also walk: the zone got its real
  arena height, 10 rows, above the strip. Side walls were tried and rejected by the user — climbing the invisible
  edge is fine —, and so was disabling the climbing attacks: "make the zone's ceiling higher, like its original
  size"); things exploded before the strip was in view (play from `PLAY_FROM`); the ending: the monster now flies in
  and LANDS next to Claudio for the goodbye; a livelier Claudio dance (hops with squash and stretch, side steps, a
  big jumping spin, double-time cheer); random fireworks. Not judged yet: all of it, and the audio was not listened to.
- 0.5.5, the user: the stages should APPEAR the way they disappear — the strip came in frozen and then suddenly came
  to life, moving and making sounds: they now fade in (sound included) and are played from the first visible frame.
- 0.5.6, the user: Claudio was much bigger than the monster (drawn at 8×; now at his animation set's own scale, 4×,
  as in the game, and the monster lands closer); the monster only walked and jumped, walked and jumped — "very
  repetitive and stale", use something like the main menu's bot: the hand-made side-to-side bot was replaced by the
  menu's navigation bot touring varied goals.
- 0.5.49, the user: (1) the credits bot "jumps many times without really moving (only the sound), trembles and acts
  weird", in pradera after dying while jumping a Gummy: three bugs of the shared bot (`src/ai/Bot.lua`, so the menu
  background got the fixes too): the enemy-dodge check simulates a GHOST player and the ghost's jumps played real
  sounds (up to 4 in one frame) — the ghost is now silent and makes no noise; at its goal point it fell through to the
  "brute force towards the tile centre", a few px away on the other side, and flipped left/right every frame and
  jumped in place — it now stands still; in a pond (off the graph) it jumped from the bottom without the second jump
  and never got out — the brute-force jump now does the second jump when needed (water, or the first did not rise a
  tile); walking into a solid body (the Mega Crabby) it was pushed back a few px each frame and that never counted as
  stuck — "pushed back against the input" now counts, and a blocked walk tries one hop and then waits. (2) The beach
  strip had meadow crabs (`crabby_river`): now the coast `crabby`. (3) The ending (the rising mirror, the shards and
  Claudio's dance) replaced by the final fight above — the user's own words: "a pre-recorded fight (REAL GAME PHYSICS)
  where the monster defeats the Mirror and it explodes, flies off and crashes into the screen; when it falls, thank you
  for playing appears and it ends there". Claudio's dance frames (`claudio_dance-Sheet.png`, the `claudio` animation
  set) are no longer used by the credits; key `credits.bye` removed. Building it found that drawing a live stage
  changed what happened in it (the volcano decorations spawn embers with the stage's random only when they were
  drawn): the decorations' update now runs with the normal random. Not watched by the user yet.
