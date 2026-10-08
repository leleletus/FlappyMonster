# Startup intro (the mtvemo logo)

**What:** the first thing shown when the game starts: black → fades to white → the six letters of the mtvemo logo
appear one by one, each on a note of a short melody → a final chord with a small "beat" of the whole logo → fades
to black → title. About 4 s; any button or a touch skips it (fades out in 0.25 s and cuts the melody).

**Files**

| File | Role |
|---|---|
| `src/states/menu/StartupState.lua` | the state (`startup`); timings at the top (`T_WHITE`, `T_FIRST`, `T_HOLD`, `T_OUT`, `T_SKIP`) |
| `assets/startup/mtvemo_logo.png` | the logo, **drawn by the user — never regenerate or edit** |
| `assets/startup/parts/*.png`, `assets/startup/logo.json` | the six letters **in pixel art** and where each goes; written by `tools/art/ui/make_logo_parts.py`: each loose stroke goes to its letter, then the logo is reduced to 1/16 (`PX`; a pixel is black when ink covers ≥ `COVER` of its block) → 104x58 px, ink 87 px wide |
| `assets/sounds/jingles/startup.wav` | the melody; written by `tools/sounds/startup.py` |

**Flow:** `game.lua` starts in `update` with `after = 'startup'`; `StartupState` then goes to `title`. It is shown
only at boot (returning to the title from the menus does not replay it; after an auto-update the game restarts, so
it shows once, after the update).

**The melody:** six notes in D major, one per letter of "MTVemo" every 0.15 s (D5 A5 F#5 B5 A5 D6), then a D add9
chord that rings while the logo is whole. 25 % pulse + triangle, like the rest of the game's sound. `NOTE_STEP` and
`CHORD_AT` in the state must match `STEP` and `CHORD_AT` in the generator. **Verified by numbers only** (2.6 s, peak
-2 dBFS, no clipping): it has not been listened to.

**Drawing:** the white screen covers the logical screen (`WINDOW_W` × `WINDOW_H`, read at draw time). The logo is
pixel art like the rest of the game: nearest filter, INTEGER scale (ink ≈ 56 % of the screen width → ×8 at 1280),
letters rise in whole logo pixels, and the "beat" on the chord is a one-pixel hop.

**Tests:** `startup_intro` — boot goes through `startup`; black at the start, white with no ink before the first
note, the melody plays once and exactly with the first letter, all letters by the chord, black at the end, title at
the planned time; skipping.

**Decisions:** requested by the user on 2026-10-08 ("black screen that fades to white, revealing my logo with a
short representative melody, then fade back to black"); cutting the logo by letters to animate with the music was
the user's suggestion. History: the first version (3.89) drew the smooth original scaled down — the user: it does not fit the game's style,
make it pixel art. The first pixel version (1/8, ×4) was "considerably higher resolution than it should be": halved
to 1/16 (×8); 1/20 was tried and the strokes turn uneven. Then: "the letters are not symmetric and look deformed,
especially the two Ms and the last O" → each letter is now reduced on a grid centred on its own axis and averaged
with its mirror image (the e and the o also top / bottom), so both halves are identical; the M sits one pixel
left so it does not touch the V. Not yet judged by the user: the melody.
