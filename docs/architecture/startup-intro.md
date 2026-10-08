# Startup intro (the mtvemo logo)

**What:** the first thing shown when the game starts: black → fades to white → the six letters of the mtvemo logo
appear one by one, each on a note of a short melody → a final chord with a small "beat" of the whole logo → fades
to black → title. About 4 s; any button or a touch skips it (fades out in 0.25 s and cuts the melody).

**Files**

| File | Role |
|---|---|
| `src/states/menu/StartupState.lua` | the state (`startup`); timings at the top (`T_WHITE`, `T_FIRST`, `T_HOLD`, `T_OUT`, `T_SKIP`) |
| `assets/startup/mtvemo_logo.png` | the logo, **drawn by the user — never regenerate or edit** |
| `assets/startup/parts/*.png`, `assets/startup/logo.json` | the six letters cut out and where each goes; written by `tools/art/ui/make_logo_parts.py` (each loose stroke goes to its letter; 29 near-invisible specks of the source are left out) |
| `assets/sounds/jingles/startup.wav` | the melody; written by `tools/sounds/startup.py` |

**Flow:** `game.lua` starts in `update` with `after = 'startup'`; `StartupState` then goes to `title`. It is shown
only at boot (returning to the title from the menus does not replay it; after an auto-update the game restarts, so
it shows once, after the update).

**The melody:** six notes in D major, one per letter of "MTVemo" every 0.15 s (D5 A5 F#5 B5 A5 D6), then a D add9
chord that rings while the logo is whole. 25 % pulse + triangle, like the rest of the game's sound. `NOTE_STEP` and
`CHORD_AT` in the state must match `STEP` and `CHORD_AT` in the generator. **Verified by numbers only** (2.6 s, peak
-2 dBFS, no clipping): it has not been listened to.

**Drawing:** the white screen covers the logical screen (`WINDOW_W` × `WINDOW_H`, read at draw time); the logo's
ink is 56 % of the screen width, linear-filtered with mipmaps (it is not pixel art; the user's logo is the one
exception to the pixel-art rule).

**Tests:** `startup_intro` — boot goes through `startup`; black at the start, white with no ink before the first
note, the melody plays once and exactly with the first letter, all letters by the chord, black at the end, title at
the planned time; skipping.

**Decisions:** requested by the user on 2026-10-08 ("black screen that fades to white, revealing my logo with a
short representative melody, then fade back to black"); cutting the logo by letters to animate with the music was
the user's suggestion. Not yet judged by the user: the melody and the look of the animation.
