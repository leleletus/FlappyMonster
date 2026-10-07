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
