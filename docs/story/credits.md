# Credits

**What:** a rolling credits film. It plays after the story's ending film (ending → **credits** → results) and can be
watched any time from **Settings → CRÉDITOS**. Over the Flappy mode's brick background (repeating both ways, drifting
sideways, rising slowly with the text and slowly changing colour), the remastered logo drops in; after 16 beats
everything scrolls up while a medley of the game's own soundtrack plays — one theme per island, two boss themes and
the Mirror boss (theme, rise, climax) — each credit block entering from the bottom exactly when its song starts. Under
each block a **live stage**: a little strip of that island that is really PLAYED by the game (its enemies, bombs,
mortars, trampolines, thin ice, lava, the real Mega Crabby and Mega Ice Crabby, with their sounds) while the monster,
driven by a small bot, runs, stomps, ground-pounds, dies and respawns. Then the empty mirror appears and the shards
fly into it, the whole mirror shines with "¡GRACIAS POR JUGAR!", and **Claudio** walks in and dances on the beat
while the monster flies around him, and they wave goodbye. Skippable like every film (hold a button 1 s). About 2:45.

**Files**

| File | Role |
|---|---|
| `assets/story/films.json` → `credits` | the timeline: 13 scenes, each with `bpm`, `beats`, `cues` and `src` (track of the catalog, part, start bar, bars: where its music comes from); `bars: false` (no cinema bars) |
| `assets/story/credits.lua` | the TEXT, one block per scene (headings are language keys `credits.*`; proper names are not translated) and each block's `stage` (its live stage) |
| `src/story/films/credits.lua` | the film: background, layout and scroll, the live stages' life (start 160 px before entering, played while visible, dropped when gone), the mirror, Claudio's dance and the flying monster |
| `src/story/LiveStage.lua` | a LIVE STAGE: an `AdventureState` in demo mode (like the menu background) on a set, at fixed 1/60 s steps with its own seeded random generator (the same every time; particles and decorations use the normal one), real sounds, fixed camera, no sky (`demo.noSky`), no boss-zone control (`demo.noBossCtl`: bosses start fighting at once, no intro, music or bar). The credits BOT: walks side to side (stopping now and then), jumps walls, gaps, water and lava and at enemies ahead (to stomp them), ground-pounds when something is under it (enemies, breakable blocks), swims, jumps when stuck. `stats` (kills, explosions, deaths) for the tests |
| drawing of a stage | into its own canvas, then its left, right and bottom edges are FADED in pixel steps (the alpha × `assets/images/fx/fade_edge.png`, `tools/art/fx/make_fades.py`, premultiplied) so the ground never ends abruptly; and the whole strip fades out as it rises (gone when its bottom reaches mid-screen: `FADE_TO`, `FADE_LEN`), so the previous section is never seen above the next one |
| `assets/story/sets/credits_*.json` | the 8 stages (20×6 cells: rows 1-4 air, 5 ground; real levels, they open in the editor), written by `tools/levelgen/make_credits_sets.py` |
| `tools/music/credits_music.py` | builds `assets/music/story/story_credits.ogg` (catalog `story_credits`) from the `src` of each scene |
| `assets/legal/THIRD_PARTY_LICENSES.txt` | the FULL texts of every third-party license (written by `tools/legal/make_licenses.py`: LÖVE's own `license.txt` with everything it bundles, the `libs/` headers, `tools/legal/OFL-1.1.txt` for the font, the music references and trademarks) |
| `assets/images/enemies/claudio/claudio_dance-Sheet.png` | Claudio's dance frames (arms up, wave, wave high): made by `tools/art/enemies/make_claudio_extras.py baile` from the user's `claudio_idle.png` (only the arms move); `assets/anim/claudio.json` sequences `cheer` and `wave` |
| `src/states/menu/SettingsState.lua` | the CRÉDITOS button |
| `src/states/story/StoryMapState.lua` | ending → credits → results |

**Sync:** the film and the music come from the same table. Every scene lasts exactly `src.bars` bars at its `bpm`
(the script asserts that each source loop is a whole number of bars at that tempo), so every song change falls on
its picture; the film follows the music clock while it plays (`Film`). The scroll speed is ONE constant: the
smallest that lets every block (text + its stage; the stage's two top air rows overlap the end of the text) fit in its song and lets the last block (`bola`) leave the top
before the Mirror's rise; each block's position is computed so that its top enters the screen (92 % of the height)
at the start of its scene. Changing the text re-computes the layout by itself; changing a scene's song or length
means editing `films.json` and re-running `credits_music.py`.

**The medley:** map theme ("Rumbo a las islas", the logo), pradera_1, costa_1, fortaleza_1, nieve_1, cuevas_1,
volcan_1, crab_tantrum_normal, snowball_boss, mirror_boss (A, the rise D and the climax E: one shared gain, so the
rise stays soft and the climax loud), victory (Claudio, then its first beat held as the final chord). Every cut is on
a bar line; each piece is RMS-matched to −15 dBFS; a 12 ms crossfade and a noise-channel crash hide the change of key.
**Verified by numbers only: not listened to.**

**Content** (the user's answers, 2026-10-20): ORIGINAL IDEA djvemo (the first Flappy Monster and ideas for the
remake); REMASTERED mtvemo (serqwjahk): direction, design, programming, art, music, levels and story; ENGINE LÖVE 11.5;
CONSOLE AND MOBILE love-nx (retronx-team), love-android; LIBRARIES baton, bitser, classic + json.lua, sock.lua,
hump.timer, lovesize; TOOLS; INSIDE LÖVE (its bundled libraries) + where the full licenses are; FONT Press Start 2P
(CodeMan38, OFL 1.1); SOUND (2A03 / VRC6 / N163 style, trademarks note); MUSICAL MOTIFS "Tentacle Tantrum" and "Winter
Fallympics" (Jukio Kallio · Daniel Hagström), "It's Me, It's Verity" (Horror Skunk), "Spider Dance" (Toby Fox, the
inspiration for an effect). Claude appears only as Claudio (the user's choice: no credit line).

**How to extend:** a new credit = a line in `assets/story/credits.lua` (+ its keys in `es.lua` and `en.lua`); a new
third-party component = an entry in `tools/legal/make_licenses.py` (and re-run it) and a line in the credits; a new
song in the medley = a scene in `films.json` with its `src`, a `draw` in `src/story/films/credits.lua` (scroll scenes
are listed in `SCROLL`) and `credits_music.py`. A new or changed stage = its function in
`tools/levelgen/make_credits_sets.py` (re-run it) and `stage = 'credits_<id>'` in its block; watch it with
`run.sh story_film STAGES=1 [STAGE=credits_x]`.

**Tests:** `story_film` (all films, `FILM=credits` alone): the 13 scenes in order with their lengths, the music lasts
exactly the film, every block enters at the start of its song and fits in it, the last one is out before the Mirror,
the 8 live stages are played and things happen in them (≥ 8 enemies killed, ≥ 2 explosions, the monster dies at
least once); captures `film_credits_*.png`. `STAGES=1`: each stage alone for 25 s with what happened and 4 captures. `story_flow` goes through ending → credits → results.

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
