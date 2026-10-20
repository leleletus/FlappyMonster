# Credits

**What:** a rolling credits film. It plays after the story's ending film (ending → **credits** → results) and can be
watched any time from **Settings → CRÉDITOS**. On black, the remastered logo drops in; after 16 beats everything
scrolls up while a medley of the game's own soundtrack plays — one theme per island, two boss themes and the Mirror
boss (theme, rise, climax) — each credit block entering from the bottom exactly when its song starts, with that
island's creatures walking (or swimming) underneath. Then the empty mirror appears and the shards fly into it, the
whole mirror shines with "¡GRACIAS POR JUGAR!", and **Claudio** walks in, dances on the beat and waves goodbye.
Skippable like every film (hold a button 1 s). About 2:53.

**Files**

| File | Role |
|---|---|
| `assets/story/films.json` → `credits` | the timeline: 13 scenes, each with `bpm`, `beats`, `cues` and `src` (track of the catalog, part, start bar, bars: where its music comes from); `bars: false` (no cinema bars) |
| `assets/story/credits.lua` | the TEXT, one block per scene (headings are language keys `credits.*`; proper names are not translated) and each block's `parade` (creatures, by animation set) |
| `src/story/films/credits.lua` | the film: layout and scroll, the mirror, Claudio's dance |
| `tools/music/credits_music.py` | builds `assets/music/story/story_credits.ogg` (catalog `story_credits`) from the `src` of each scene |
| `assets/legal/THIRD_PARTY_LICENSES.txt` | the FULL texts of every third-party license (written by `tools/legal/make_licenses.py`: LÖVE's own `license.txt` with everything it bundles, the `libs/` headers, `tools/legal/OFL-1.1.txt` for the font, the music references and trademarks) |
| `assets/images/enemies/claudio/claudio_dance-Sheet.png` | Claudio's dance frames (arms up, wave, wave high): made by `tools/art/enemies/make_claudio_extras.py baile` from the user's `claudio_idle.png` (only the arms move); `assets/anim/claudio.json` sequences `cheer` and `wave` |
| `src/states/menu/SettingsState.lua` | the CRÉDITOS button |
| `src/states/story/StoryMapState.lua` | ending → credits → results |

**Sync:** the film and the music come from the same table. Every scene lasts exactly `src.bars` bars at its `bpm`
(the script asserts that each source loop is a whole number of bars at that tempo), so every song change falls on
its picture; the film follows the music clock while it plays (`Film`). The scroll speed is ONE constant: the
smallest that lets every block (text + creatures) fit in its song and lets the last block (`bola`) leave the top
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
are listed in `SCROLL`) and `credits_music.py`.

**Tests:** `story_film` (all films, `FILM=credits` alone): the 13 scenes in order with their lengths, the music lasts
exactly the film, every block enters at the start of its song and fits in it, the last one is out before the Mirror;
captures `film_credits_*.png`. `story_flow` goes through ending → credits → results.

**Decisions / history**
- 2026-10-20 (3.105.0): requested by the user (after the ending; logo on black, scroll, a medley of the best themes —
  one per island, especially the Mirror boss —, animated sprites, Claudio's dance and goodbye at the end, all
  licences credited). ~3:15 "if it fits without being too slow": it came to 2:53 at 43 px/s.
- First layout let the last block (the tools) leave during the Mirror theme: the scroll had to run at 64 px/s and
  the screen was empty most of the time; the tools went to the libraries' block and the Mirror theme became the
  monster flying across while the last lines leave.
- Legal note (also in known-debt): crediting the quoted motifs is courtesy, not a licence; for a commercial release
  they should be rewritten or licensed.
- Not yet judged by the user: the medley's sound (not listened to), the cut points, the scroll speed, the dance.
