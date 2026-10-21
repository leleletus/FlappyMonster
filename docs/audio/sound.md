# Sound effects and music playback

`src/audio/Sound.lua` is the global `Sound`: it loads every effect and every catalog track at start, plays effects
with per-sound gain and distance attenuation, runs the cave echo, and plays music (intro + loop, level / boss
override, online sync). `src/audio/Music.lua` reads the catalog `assets/music/index.json`.

**All sounds are files** (no procedural audio). To add one: a WAV in `assets/sounds/<group>/` (usually written by a
generator in `tools/sounds/`), one `load('name', path, 'static')` line in `Sound.load()`, a gain in the `GAIN` table
so its loudest 100 ms sit at about −12 dBFS, then `Sound.play('name')`. The `sounds` harness checks that every name
played in code is loaded and that levels are in range.

On the server `Sound` is a stub that turns plays into events; see [netcode](../architecture/netcode.md) for who hears
what (`SHARED_SOUNDS`, `PRIVATE_SOUNDS`). Sounds can also be NOISE that enemies hear in dark levels
([dark-levels](../gameplay/dark-levels.md)).

## The Sound module

- `src/audio/Sound.lua` — Sound.play(name,pitch,vol), playMusic(name), stopMusic, tracked sounds, per-sound GAIN baked at load. ALL sounds are files (no procedural audio): add one with load('name', 'assets/sounds/<group>/x.wav', 'static') in Sound.load(), then Sound.play('name'). Folders: player/, enemies/<enemy>/ (shared ones in enemies/common/), bosses/<boss>/, items/, mechanics/, traps/, water/, jingles/, ui/, flappy/, fireworks/. Images: assets/images/<thing>/ (bosses/<boss>/), all lowercase; music: assets/music/snake_case.wav

- `src/audio/Music.lua` — MUSIC CATALOG from assets/music/index.json (id, name, file | intro+loop, volume, loop, level, boss). Sound loads every track from it (`Sound.loadTrack`); `level=false` tracks (boss, menus, youWin) are not offered as level music. Adding a song = file + one index entry. Level JSON `"music": id` (editor: Nivel tab → Música, ▶ preview). Music ALWAYS starts from 0 when (re)started: `stopMusic`/`playMusic` stop and rewind even a PAUSED source (it used to resume where it was after leaving a level from the pause menu); `AdventureState:exit` calls `Sound.leaveMatch()` so retrying (game over) or re-entering starts like the first time (harness `sp_boss RETRY=level`). `Sound.playMusic('level')` resolves: `setLevelMusic` override (boss) → `setBaseLevelMusic(level.music)` → 'classic'. Online the client re-seeks the level track every 1 s to the server clock (`Sound.syncMusic('level', t)`; tick 0 = round start), so all players hear the same point of the song (tested: ≤0.1 s).

## Distance attenuation

`Sound.setListener(x, y)` (the local player; camera centre when spectating)
and an EMITTER: `Sound.setEmitter/clearEmitter/withEmitter(x, y, fn)/playAt`.
Every `Sound.play` while an emitter is set is scaled by distance
(`Sound.NEAR` 480 px full volume → `Sound.FAR` 1400 px silent). No emitter =
full volume (UI, own actions). `Sound.RANGE[name]` multiplies NEAR/FAR per sound
(boss sounds carry across the arena). Per-sound volume: `GAIN` table at the top of
Sound.lua (baked into the samples at load). AdventureState sets the emitter around each
entity update; the server sets `_emitX/_emitY` around each player step,
collision pass and entity update, and sound events carry `x, y`; each client
attenuates with its OWN listener (`Sound.playAt`). New world sounds need
nothing special as long as they're played from those update loops.

## Shared / private sounds

- Sounds decided only by the server (the causing client doesn't predict them) go in
  `Protocol.SHARED_SOUNDS` (helmetBreak, pufferPrick): the server sends them with no
  owner, so everybody hears them. New sounds: `tools/sounds/mechanics.py` (switch,
  helmet, puffer), levelled with `Sound.GAIN` to ≈ -12 dBFS (harness `sounds`).

## Sound test (secret, for developers) — 0.5.14

`src/states/menu/SoundTestState.lua` (state `sound_test`). From the TITLE screen: ↑ ↑ ↓ ↓ ← → ← → with the arrows or
the d-pad, or 7 quick taps on the version number (bottom right) on a phone. Two lists: every track of
`assets/music/index.json` (with its intro + loop, as in the game; pending tracks are skipped) and every sound loaded by
`Sound.load` (copies of the game's sources, so their `GAIN` is applied). Options (◀ ▶): list, loop, pitch (0.25–3),
volume, echo and room (OpenAL effects `love.audio.setEffect`; "not available" where the platform has none), and
position (seek ±5 s). It plays on its OWN sources and leaves the game's music and voices alone. Mouse / touch
(0.5.21, the user: everything must work without keyboard or pad): two tabs MÚSICA / EFECTOS above the list, a ▶ / ■
button on the card, a position bar that seeks on tap and drag, rows (tap = choose, tap again = play / stop; drag =
scroll; wheel too), either half of an option (◀ / ▶); the mouse hover selects rows and options. Harness `menu_flow`
(`soundtest`, keyboard and touch).

## Water sounds and the extra life are original (0.5.15)

The user noticed (2026-10-20) that `glugluglu`, `drowning`, `airGasp` and `waterWarning` were taken from Sonic 1 and
that `oneUp` sounded like Mario's. All five are now generated by `tools/sounds/water.py`, each with EXACTLY the old
duration (the drowning kills when its audio ends, `DROWN_AUDIO_DUR`) and the same loudness (its loudest 100 ms), so
`GAIN` still holds. The old files are kept outside the repo in `FlappyMonster_originals/sounds/`.
- `drowning` (12.1 s), 3rd version, remade from scratch (0.5.17; the user: the 2nd, with drums and a diminished hit,
  sounded odd — the unease must come from how strange it is, closer to the original). Takes the SHAPE of Sonic 1's
  (a short chip figure that never stops, rises in pitch every bar and speeds up, and ends on a held note) without its
  melody: band-limited pulses and a triangle, no drums, no reverb — a 12.5 % pulse TRILL in 16ths between the fifth and
  the minor sixth (E – F over A minor, the semitone pair of the recipe), a 25 % pulse arpeggio of the minor chord in
  8ths, a triangle bass on the root jumping octaves. EVERYTHING rises one semitone per bar (A minor → F minor in ~9
  bars) while the tempo goes 140 → 236 BPM. Ending (0.5.18; the user: the held chord sounded forced, like stopping
  on purpose, and the hand-over to the glug should be organic): in the last 1.6 s the player SINKS — the figure keeps
  going but slows down (−45 %), each note falls a little more (down to −5 semitones) and a low-pass filter closes
  (16 kHz → 300 Hz, as if heard under water); the trill keeps rubbing to the end and it all lands on the low, muffled
  TONIC (resolved) that fades exactly where the glug's dull thump comes in.
  (0.5.17 ending, discarded: the figure stopped and the tonic minor chord was held high with a tremolo.)
  (2nd version, 0.5.16, discarded: four channels with drums, the E–F motif with a minor third on top, octave bass and
  a dry diminished hit on E at the end — "suena rara".)
- `oneUp`, 2nd version (0.5.16; the 1st "boing" sounded odd): a fast arpeggio up a G major chord (G5 – B5 – D6 – G6)
  and a short sparkling trill G6 – D7 that fades.
- `waterWarning`: two dry chip blips on the same two notes. `airGasp`: an inhale (noise through a rising band-pass)
  and a pop. `glugluglu`: rising-pitch bubbles that space out and fade, after a dull thump.
- Not listened to by anyone yet: judged by numbers only.

Focus (0.5.15): on PC the game keeps sounding without window focus (the sound test is used with other windows in
front); levels still pause. On phones the app in the background is silent.
