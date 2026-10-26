# Startup intro (the mtvemo logo)

**What:** the first thing shown when the game starts: black → fades to a dark starry sky → a gold COIN with the
M·T·V monogram spins in from above and lands → to its right the six letters "MTVEMO" (chunky, sunset gradient,
3D edge) fall one by one, each landing on a note of a short melody, squashing and stretching → on the final chord
coin and letters hop one pixel → one shine crosses coin and name → three sparkles → fades to black → title. About
5.8 s; any button or a touch skips it (fades out in 0.25 s and cuts the melody).

**Files**

| File | Role |
|---|---|
| `src/states/menu/StartupState.lua` | the state (`startup`); timings at the top (`T_IN`, `T_HOLD`, `T_OUT`, `T_SKIP`; `T_FIRST` comes from the JSON) |
| `assets/startup/logo_anim.png`, `logo_anim.json` | the animation as pre-drawn frames: 30 fps, each frame 262x123 cut from a 320x180 screen (`x`, `y` = where), repeated frames stored once (`frames` = sheet index of every instant), `noteAt` / `chordAt` = first note and chord in animation seconds |
| `assets/startup/sky.png`, `stars.png` | the sky (1x180 bands, stretched to the screen) and the stars (320x180, tiled) |
| `tools/art/ui/make_mtvemo_logo.py` | draws everything (`--apply`: design D) and the proposals A-D (`FlappyMonster_pruebas/logo_mtvemo/`) |
| `assets/sounds/jingles/startup.wav` | the melody; written by `tools/sounds/startup.py` |

**Flow:** `game.lua` starts in `update` with `after = 'startup'`; `StartupState` then goes to `title`. It is shown
only at boot (returning to the title from the menus does not replay it; after an auto-update the game restarts, so
it shows once, after the update). The frame sheet is released on `exit`.

**The melody:** six notes in D major every 0.15 s (D5 A5 F#5 B5 A5 D6), then a D add9 chord at 0.90 s that rings
while the logo is whole. 25 % pulse + triangle. The letters fall every 0.15 s and land 0.22 s after starting:
`noteAt` (1.27) is the first landing, `chordAt` = `noteAt` + 0.90 the hop. `STEP` / `CHORD_AT` in
`tools/sounds/startup.py` and `D_NOTE_AT` / `D_CHORD_AT` in the generator must agree. **Verified by numbers only**:
it has not been listened to.

**Drawing:** pixel art like the rest of the game: nearest filter, the 320x180 screen at the largest INTEGER scale
that fits (×4 at 1280x720), centred; the sky fills the whole logical screen, the stars tile around.

**Tests:** `startup_intro` — boot goes through `startup`; the sheet holds every frame; black at the start, sky with
no logo before the animation, the melody plays once and exactly with the first landing, more logo at the end than
mid-melody, black at the end, title at the planned time; skipping.

**Decisions:** requested by the user on 2026-10-08 ("black screen that fades to white, revealing my logo with a
short representative melody, then fade back to black"); cutting the logo by letters to animate with the music was
the user's suggestion. History: the first version (3.89) drew the smooth original scaled down — the user: it does not fit the game's style,
make it pixel art. The first pixel version (1/8, ×4) was "considerably higher resolution than it should be": halved
to 1/16 (×8); 1/20 was tried and the strokes turn uneven. Then: "the letters are not symmetric and look deformed,
especially the two Ms and the last O" → each letter is now reduced on a grid centred on its own axis and averaged
with its mirror image (the e and the o also top / bottom), so both halves are identical; the M sits one pixel
left so it does not touch the V. Not yet judged by the user: the melody. 2026-10-25, the user: "redesign my pixel-art logo completely, it doesn't matter if it doesn't look like the
original; prettier, animated and good; propose ideas and show me before implementing". Proposals: A "Arcade"
(falling sunset letters, shine, sparkles), B "Tele" (a CRT TV with a face that switches on, letters hop below), C
"Moneda" (a spinning coin with the M·T·V monogram, the name slides out). The user: "mix the coin with the arcade"
→ D, implemented (0.5.35). The old logo (the user's drawing, its pixel letters and `make_logo_parts.py`) left the
repo: `FlappyMonster_originals/startup_logo_antiguo/` and `herramientas_retiradas/`. Not yet judged by the user in
the game: the timing with the melody.
