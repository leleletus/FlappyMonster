# OST presentation videos

`tools/video/make_ost.sh [boss …]` renders one video per boss theme OFFLINE with the real game code (not a screen
recording) into `FlappyMonster_pruebas/videos/`. Needs `ffmpeg` and `~/.venvs/fm-music` (numpy, soundfile) or
`FM_PYTHON`. `tools/video/ost/main.lua` is the LÖVE app; `tools/video/spectrum.py` computes the visualiser.

## Details

**v2 (2026-10-03, with the FINAL soundtrack; the description further down is v1, kept for the bulb details):**
`tools/video/make_ost.sh [megagummy megacrabby miniboss1 snowboss megacrabby_ice megagloomy mirror]` → one video per
BOSS theme, `FlappyMonster_pruebas/videos/<track id>.mp4`. Audio = the track's intro + loop once, NO fade-out (ends
where the track ends). The boss runs its REAL AI against an invisible, immortal dummy player (the "lure",
`PlayerAdventure` with `immortal`, scripted input: wanders around the arena centre, stops, jumps now and then; no
`Interactions`, so it never hurts the boss) through the real `BossZones` controller, at `PACE` 0.85; the boss's HP
drops by itself along the song (`SHOWS[...].hp`, `phase2`, `rage`) to show later phases; the Mirror laughs every
`laugh` s (`onPlayerDeath`). Overlay: logo ×6 bopping on the beat; a dark bottom BANNER with title, boss name, time
elapsed / total in the boss's accent colour; a 64-bar spectrum VISUALIZER (from `tools/video/spectrum.py`: per-frame
log bands 40 Hz-12 kHz, each normalised to its own peak) whose already-played bars are lit = the progress bar. The
camera is raised so the arena floor sits above the banner. v2.1 (after the user watched them): ALL TEXT IN ENGLISH (shared in
English; boss names as in `assets/lang/en.lua`); `love.graphics.setDefaultFilter('nearest')` like game.lua (the Mirror
was BLURRY: it draws a player body, whose images don't set their own filter); the lure only walks on SAFE cells (the
arena's main floor row, no thin ice / water, inside the visible width) and teleports back to one when stuck, inside a
block or in water (it used to get wedged in the scenery and the boss attacked a wall for the whole video); it waits at
the LEFT side, still, until the boss intro ends (a Mega Crabby lands on its own spot only if no player is near — with
the lure in the centre it fell in a corner); in arenas wider than the screen (Snowball: 24 tiles) the camera follows
the boss smoothly; the logo sits TOP-LEFT and fades to 16 % while the boss passes behind it. `love tools/video/ost <boss> 20` = a 20 s test; `SHOT=n`
saves frame n to the save dir. Needs `~/.venvs/fm-music` (numpy, soundfile) or `FM_PYTHON`.

TRACK NAMES (user): the game's own versions are called **Crab Tantrum (X)** — catalog `name` of `tentacle_nes` (NES),
`tentacle_winter` (Winter), `tentacle_gloomy` (Gloomy), `tentacle_chip` (Chip / Chip instrumental); ids and files keep
`tentacle_*` (levels reference the ids). Only the original recording stays "Tentacle Tantrum".

`tools/video/make_ost.sh [megacrabby megacrabby_ice megagloomy]` → `FlappyMonster_pruebas/videos/crab_tantrum_<x>.mp4` (outside
the repo; 1280x720, 30 fps, H.264 + AAC, the full track once with a 2 s fade-out). `tools/video/ost/main.lua` is a
LÖVE app that renders OFFLINE with the real game code (not a screen recording): the boss's REAL arena level (its zone
of guarida_cangrejo_rey / glaciar_cangrejo / gruta_lugubre, with sky, decorations, water, snow, particles), frame by
frame into a canvas piped raw to ffmpeg; `love.timer.getTime/getDelta` are replaced by a virtual clock so everything
that animates from the timer runs at video time. `Sound` is a silent stub (the boss makes no sound; its fx and
particles stay). The boss does its real INTRO (an invisible dummy player enters the zone), then the tool takes over:
idle state (`ready`), one gesture every 8 bars through the boss's own update (Megas: `rest` + `restKind` = claw
punches / spike flex / roar; Mega Gloomy: `ping` ring / `taunt` / `roar`), and it gets ANGRY in the last quarter
(Megas: hp → 30 %, so anger symbols + shards; Gloomy: `rage` crystals). The Flappy Monster logo bops on every beat
(`SHOWS[...].bpm`; stronger on the bar's first beat) and the track title is in the corner. Mega Gloomy only: a light
BULB hangs from the zone ceiling and swings one full cycle every 8 beats — three fake decorations with `light` are
injected into `level.decorations` so `Darkness` lights the arena and the boss as it moves. Every 16 bars the bulb
FAILS: it flickers, stays off for 2 bars (only the crab's glowing points show) and flickers back on. Now and then, at
random, it also dims in a short flicker. The cable and the bulb glass are drawn BEFORE `Darkness` (so they go dark
with the scene); only the lit filament and its halo are drawn after it, scaled by how lit it is.
