# Sound effects and music playback

`src/audio/Sound.lua` is the global `Sound`: it loads every effect and every catalog track at start, plays effects
with per-sound gain and distance attenuation, runs the cave echo, and plays music (intro + loop, level / boss
override, online sync). `src/audio/Music.lua` reads the catalog `assets/music/index.json`.

**All sounds are files** (no procedural audio). To add one: a WAV in `assets/sounds/<group>/` (usually written by a
generator in `tools/sounds/`), one line in the catalog `assets/sounds/index.json` (`id`, `file`, and if needed `gain`
so its loudest 100 ms sit at about −12 dBFS, `range` × the hearing distance, `echo` its weight in cave echo, `stream`,
`note`), then `Sound.play('id')`. (Before 2026-11-02 these were `load(...)` lines and `GAIN` / `RANGE` / `ECHO_W`
tables in `Sound.lua`; "no GAIN entry" below means no `gain` field.) The `sounds` harness checks that every name
played in code is loaded and that levels are in range.

On the server `Sound` is a stub that turns plays into events; see [netcode](../architecture/netcode.md) for who hears
what (`SHARED_SOUNDS`, `PRIVATE_SOUNDS`). Sounds can also be NOISE that enemies hear in dark levels
([dark-levels](../gameplay/dark-levels.md)).

## The Sound module

- `src/audio/Sound.lua` — Sound.play(name,pitch,vol), playMusic(name), stopMusic, tracked sounds, per-sound `gain` from `assets/sounds/index.json` baked at load. ALL sounds are files (no procedural audio): add one with load('name', 'assets/sounds/<group>/x.wav', 'static') in Sound.load(), then Sound.play('name'). Folders: player/, enemies/<enemy>/ (shared ones in enemies/common/), bosses/<boss>/, items/, mechanics/, traps/, water/, jingles/, ui/, flappy/, fireworks/. Images: assets/images/<thing>/ (bosses/<boss>/), all lowercase; music: assets/music/snake_case.wav

- `src/audio/Music.lua` — MUSIC CATALOG from assets/music/index.json (id, name, file | intro+loop, volume, loop, level, boss). Sound loads every track from it (`Sound.loadTrack`); `level=false` tracks (boss, menus, youWin) are not offered as level music. Adding a song = file + one index entry. Level JSON `"music": id` (editor: Nivel tab → Música, ▶ preview). Music ALWAYS starts from 0 when (re)started: `stopMusic`/`playMusic` stop and rewind even a PAUSED source (it used to resume where it was after leaving a level from the pause menu); `AdventureState:exit` calls `Sound.leaveMatch()` so retrying (game over) or re-entering starts like the first time (harness `sp_boss RETRY=level`). `Sound.playMusic('level')` resolves: `setLevelMusic` override (boss) → `setBaseLevelMusic(level.music)` → 'classic'. Online the client re-seeks the level track every 1 s to the server clock (`Sound.syncMusic('level', t)`; tick 0 = round start), so all players hear the same point of the song (tested: ≤0.1 s).

## UI sounds (0.5.36)

`tools/sounds/ui.py` → `assets/sounds/ui/`: `levelEnter` (entering a level from the world map: falling sweep +
bells as the iris closes), `countTick` / `countGo` (the start countdown). At ≈ −12 dBFS, no GAIN entry. Not listened
to by anyone yet.

## Hurry up! (0.5.215)

`src/audio/Hurry.lua`: when `Hurry.AT` (60) seconds of the level's time limit remain (`Sim.limitOf`; online, the
round's clock in timed modes), `hurryUp` plays once, the music goes SILENT (`DUCK_K` 0: it keeps running, not paused nor restarted — the user, 2026-11-14) for `DUCK` (2.9 s, the jingle's length) and comes back
`RATE` (2^(3/12) = ×1.189, three semitones: the next step of the jingle's 0 / +1 / +2 staircase) faster once the jingle ends — `Sound.setMusicRate`, which LÖVE also raises in pitch (about two semitones), kept for tracks
that start later; `Hurry.reset` (entering / leaving the level state) sets it back to 1. Single player and the online
client; not the menu demo, not King of the Hill (its mode has `hurry = false`: its clock is already the round's countdown)
nor the story bonus matches. Since 0.5.216 every level's HUD clock COUNTS DOWN (what is left of the limit; the user: "it
wasn't clear when time runs out"), so the warning matches the clock turning red at 1:00. `story_flow`
`prisa`. Not listened to yet.

## Hurry-up jingle

`tools/sounds/hurry.py` (standard library only) → `assets/sounds/jingles/hurry.wav` (`hurryUp`, 2.99 s file, 2.83 s of
sound from 0.03 s, 44.1 kHz mono): played once when 60 s of the level's time limit remain, over the ducked music. v3
follows a measured formula for RISING TENSION: a 2-note motif → the same motif +1 semitone → +2 → a long
closing note that dies away. Parameters at the top of the script (`TONALIDAD`, `BPM` 140, `REPETICIONES` 3,
`SEMITONOS_PASO` 1, `PASO` 6 sixteenths = 3 eighths = 0.643 s between motif onsets, `CIERRE` 8 sixteenths = 0.857 s).
Variant **D** (picked by misclick on 2026-11-14; the real pick was F): an original motif in C major built from "la llamada"'s 4th — G5 on the beat, C6 on the eighth
offbeat — with a lower E5 alternating on the "e" / "a" sixteenths and a triangle C3; the steps go G–C, G♯–C♯, A–D, and
the close leaps another 4th to G6 (the 5th, la llamada's last note, left open) over a held G2 with a 1-bit DPCM kick
and a noise crash. Onsets every 3 eighths = the "3" of the house 3+3+2 tresillo run as a hemiola. Timbres: lead = 2A03
pulse with a 12.5 → 50 % duty sweep (vibrato on the closing note), doubled an octave up by the countdown beep (25 %
pulse, 2 ms attack, exponential decay, 6 kHz low-pass — the sound the player already hears as "time"); accompaniment =
short 12.5 % pulse; bass = triangle; crash = 15-bit LFSR noise. Levelled like the rest (loudest 100 ms at −12 dBFS,
peak −5.9 dBFS, RMS −16.2 dBFS, no clipping). `VARIANTES=1` also writes `FlappyMonster_pruebas/hurry/hurry_{D,E,F}.wav`
+ `.mid` (the default run always writes the score to `hurry.mid` there): **E** la llamada's 3rd C6–E6 (G5 below), the
stairs reach D6–F♯6 and the close rises a half step to G6 (F♯ as leading tone); **F** D's motif with a 4-3-5 sixteenth
arpeggio (E5 G5 E5 C5) instead of the repeated note and a C3–G2 bass. Verified by numbers only (windowed FFT): motif
pitches 782.5/1045.0, 829.1/1107.2, 878.5/1173.1 Hz, step ratios 1.0595-1.0596, onsets 0.029 / 0.673 / 1.312 / close
1.956 s. `Hurry.DUCK` should cover the 2.835 s of sound (same for D2 and F2). Its helpers (`pulse` — duty may now be a function of time —, `saw`, `triangle`, `env`, `finish`…) are reused by `tools/sounds/jingles.py`. Not listened to by anyone yet.

**v3.2 — F2, the installed default.** Correction from the user: picking D was a misclick, the real pick was **F** (D's
motif with the 4-3-5 sixteenth arpeggio), and they liked D2's density more than D. F2 = F + D2's treatment: the
arpeggio completed to continuous sixteenths C5 E5 G5 G5 E5 C5 (accented offbeats), the C6 repeated on the last two
sixteenths of each step, an 8th octave triangle bass C3–C4–G2 (F's C–G), 16th hi-hats, a snare mid-step, the
three-stroke snare roll into the close and D2's close (G6 over G2, fading D6–B5 sixteenth tremolo). 82 notes (F: 33),
all 18 sixteenths before the close attacked. Measured: steps 782.5/1045.0 → 829.1/1107.2 → 878.5/1173.1 Hz (ratios
1.0595-1.0596), onsets 0.029 / 0.673 / 1.312 / close 1.956 s, close 1571.1 Hz over 98.0 Hz, sound 0.030 → 2.865 s
(**2.835 s**; file 2.99 s), loudest 100 ms −12.0 dBFS, peak −5.8 dBFS, RMS −15.3 dBFS, no clipping. Copy in
`FlappyMonster_pruebas/hurry/hurry_F2.wav` + `.mid` (`VARIANTES=1` writes D2, D3, F2). Not listened to by anyone yet.

**v3.1 — D2 (kept as a file).** The user chose D and approved the ×1.19 music speed-up, then: "it's good, but
too CALM for what it should be — too few notes; fill the empty spaces with more notes for more tension and hurry". D2
keeps D's identity (same motif, same three +1 steps, same G6 close, same 2.83 s) and fills it with RHYTHM, not a new
tune: E5 on every sixteenth (accented offbeats), the motif's C6 repeated on the last two sixteenths of each step, an
8th-note octave triangle bass C3–C4–C3, 16th noise hi-hats, a snare (noise + 1-bit DPCM body) mid-step, a three-stroke
snare roll into the close, and under the long G6 a decaying D6–B5 sixteenth tremolo with hi-hats so the close never
goes still. 82 notes against D's 27; all 18 sixteenths before the close have an attack (D: 15). **D3** (alternative, more
"alarm"): the whole motif as repeated sixteenths G5 G5 C6 C6 C6 C6, offbeat E5, a C3 sixteenth bass, 8th hi-hats and a
snare roll swelling through the whole third step; G5 tremolo under the close. Both in `FlappyMonster_pruebas/hurry/`
(`hurry_D2/D3.wav` + `.mid`; `VARIANTES=1` writes them, `VARIANTES=todas` every variant). D2 measured: steps
782.4/1045.0 → 829.1/1107.2 → 878.5/1173.1 Hz (ratios 1.0595-1.0596), close 1571.1 Hz over 98.0 Hz, sound 0.030 →
2.865 s (2.835 s), loudest 100 ms −12.0 dBFS, peak −5.9 dBFS, RMS −15.4 dBFS, no clipping. Not listened to by anyone yet.

History (keep these verdicts):
- v1 (0.5.215): two-tone siren B5–F6 ×2 then la llamada G5–C6–E6–G6 into a C major chord with crash (1.62 s, a copy in
  `FlappyMonster_pruebas/hurry/hurry_v1_rechazado.wav`). The user: "it feels out of place and MORE MELODIC than it
  should be; it doesn't blend with the rest of the game".
- v2 (0.5.216): three non-melodic alerts, `hurry_{A,B,C}.wav` in the same folder — **A** (installed) the countdown beep
  at 1760 Hz doubled at 880 Hz, three groups of three; **B** flat 50 % square D6–A5 hi-lo ×3; **C** three rising
  "whoops" 520→1250 Hz. The user: "it doesn't quite convince" — it lacked RISING TENSION, hence v3's chromatic stairs.
- v3 D (above, kept as `hurry_D.wav`): chosen over E and F, but "too calm, too few notes" → D2. Density must come from
  rhythm and repetition, never from a new melody (v1's lesson).
- The pick of D was a MISCLICK: the user meant F, and liked D2's density → F2 (installed). D2 and D3 stay as files.

## Jingles remaster (fanfare, finish, sad trombone)

`tools/sounds/jingles.py` (standard library only, reuses `hurry.py`'s helpers) → `assets/sounds/jingles/`
`fanfare.wav` (`fanfare`, level won, 1.12 s), `finish.wav` (`finish`, reaching the goal, 0.43 s), `sad_trombone.wav`
(`sadtrombone`, fail, 1.54 s). Same notes and timings as the originals (measured from them): fanfare G4 C5 E5 G5
(85 ms each) · E5 G5 · C6 held with vibrato over a soft C major chord and a triangle bass C–G–C; finish C5 E5 G5 C6
with a triangle doubling two octaves down; sad trombone G4 F♯4 F4 E4 "wah" notes, each a band-limited sawtooth bending
down through a two-pole low-pass that opens (400→2400 Hz in 70 ms) and closes, the last one with a widening vibrato.
44.1 kHz, PolyBLEP pulses, attack/decay envelopes, loudest 100 ms at −12 dBFS (peaks −6.0 / −6.7 / −9.2 dBFS, no
clipping). `VARIANTES=1` also writes `<name>_nuevo.wav` next to the untouched originals in
`FlappyMonster_pruebas/jingles_originales/`. `tick.wav` was not remade. Not listened to by anyone yet.

History: the originals had no generator — raw 50 % square waves at 22050 Hz with flat volume and aliasing. The user:
they sound "low quality, like recorded with a phone" and clash with the rest of the effects; do not use them as a
style reference.

## The world map's cannon

`tools/sounds/map_cannon.py` (reuses `megacrabby.py`'s helpers and `story.py`'s `save`) → `assets/sounds/story/`:
`cannonLoad` (the hero drops in: hollow iron clonk + a short comic boing), `cannonFuse` (0.6 s crackling hiss),
`cannonBoom` (low thump, crack and a smoky tail), `cannonWhoosh` (air passing by, filter up and down), `cannonLand`
(dull thud + a little bounce). Each at −12 dBFS, no GAIN entry. Played by `StoryMapCannons`
([world map](../story/world-map.md#cannons-between-islands)). Not listened to by anyone yet.

## The Penguin's sounds

`tools/sounds/penguin.py` (reuses `jungle_enemies.py`'s helpers) → `assets/sounds/enemies/penguin/`: `penguinSquawk`
(it sees you and dives: a short nasal two-beat honk), `penguinSlide` (belly rub on snow and ice with an icy hiss: it
starts sliding / the sled starts). ≈ −12 dBFS, no GAIN entry. Not listened to by anyone yet.

## The Snowball's sounds

`tools/sounds/snowball.py` (reuses `jungle_enemies.py`'s helpers) → `assets/sounds/enemies/snowball/`: `snowballWindup`
(snow packing: crunches speeding up), `snowballLaunch` (a soft "fffump" + rolling hiss), `snowballShove` (a low snowy
"pomf" + a short high giggle: it shoved someone; the online client plays it when it predicts the shove),
`snowballBonk` (dull thud + falling snow dust: against a wall). Played by the data enemy on entering its states
(`sounds` in `assets/enemies/snowball.json`). ≈ −12 dBFS, no GAIN entry. Not listened to by anyone yet.

## The Scorpion's sounds

`tools/sounds/scorpion.py` → `assets/sounds/enemies/scorpion/` and `assets/sounds/bosses/giantscorpion/`: the rattle (`scorpionRattleJoin`,
`scorpionRattleSplit`: 3 wooden clicks in one file per gesture, so the rhythm survives online), `scorpionClick`,
`scorpionSting`, `scorpionSnap`, `scorpionSkitter`, `scorpionStrike`, `scorpionPull`, `scorpionHiss`. The rattle sits at ≈ −14
dBFS to avoid saturating away the wood, the rest ≈ −12; no GAIN entry. `--apply` only rewrites the rattle; `--others`
rewrites the rest, which comes out slightly different each time its random stream changes. Not used by any entity yet.
Not listened to by anyone yet. Woods to compare: `FlappyMonster_pruebas/escorpion/sonidos/`.

`tools/sounds/tifon.py --apply` → `assets/sounds/bosses/tifon/`, Tifón (the Supreme Gust): `tifonRoar`, `tifonWarn`,
`tifonBlow` (2.6 s), `tifonInhale` (2 s), `tifonGulp`, `tifonBoom`, `tifonCough`, `tifonCharge` (1 s), `tifonThunder`,
`tifonChain`, `tifonHail`, `tifonVane`, `tifonSpin`, `tifonDizzy`. Noise and sines only; ≈ −12 dBFS (hail −15, chain −14),
no GAIN entry. The user approved them from the previews (2026-11-04) without asking for changes. Not used by any entity yet.

`tools/sounds/netcopter.py --apply` → `assets/sounds/bosses/netcopter/`, the Net-Copter (plan 5c): `netFire` (net leaves the
cannon), `netSnare` (the net wraps the monster), `netSnag` (it catches on a solid and comes apart), `pedalSqueak` and
`propWhir` (short ticks, rate-limited on the boss: pedal 0.7 s / whir 0.55 s, faster while crossing), `balloonPop` (phase 2
starts), `clawServo` (claw warning), `bombLob` (the lobbed bomb) and `leakHiss` (phase 2 air leak, every 1.8 s); round 2
(2026-11-08): `clawOpen` (the claw opens during the warning: ratchet, spring, finger clack) and `clawSnap` (it snaps shut
at the end of the sweep: iron clack + thud), once per claw attack each, generated after the others so the earlier files
stay byte-identical. Noise and sines only; ≈ −12 dBFS (squeak and leak −15, whir and snag −14), no GAIN entry. Replaced the placeholders `cannonWhoosh`,
`bombIgnite`, `gustPop` and `megaWindup` on this boss. Never listened to by a person. Previews:
`FlappyMonster_pruebas/netcopter/sonidos/`. The hit shake is the fx `shake_tick` (0.15 s).

## The 0.5.96 enemies' sounds

`tools/sounds/jungle_enemies.py` → `assets/sounds/enemies/{mole,piranha,carnivoreplant}/`: `moleDig` (the mound moving:
soft earth grains), `molePop` (it pops out), `moleBite` (two tooth clicks), `piranhaBite` (a dry, high snap at the top of
its leap), `plantRustle` (the plant's warning: trembling leaves), `plantSnap` (it shuts: wet low thud + click),
`plantCrunch` (it eats something), `plantBite` (the bite, shared by the Plant and the Carnivorous Queen's Lanzas: teeth, crunch grains, jaw thud, wet tail; `tools/sounds/plant_bites.py`), `queenBite` (the Queen's own, lower and heavier; same tool). Not listened to. The piranha's leap reuses `waterSplashOut` / `waterSplash`; the dizzy mole,
`stunned`. All at ≈ −12 dBFS (−11.6 to −14.1, harness `sounds`), no GAIN entry. Not listened to by anyone yet.

## Avalanche and Cable car sounds (2026-10-29)

`tools/sounds/avalanche_cablecar.py` (previews in `FlappyMonster_pruebas/mecanicas_heladas/sonidos/`, `--apply` writes
the game's): `avalancheRumble` (`traps/avalanche_rumble.wav`, 1.2 s: low rumble growing, cornice cracks speeding up),
`avalanchePour` (`traps/avalanche_pour.wav`, 1.3 s, repeated while it pours: heavy snow whoosh over a rumble),
`cablecarMove` (`mechanics/cablecar_move.wav`, 0.6 s, repeated while moving: cable hum + two wheel clacks),
`cablecarStop` (`mechanics/cablecar_stop.wav`, 0.35 s: metal thud, clang and a short squeal). The generator levels
each to −12 dBFS (loudest 100 ms), no GAIN entry. Played with `Sound.playAt` from the nearest point / cabin. Not
listened to by anyone yet.

## Door sounds (2026-10-29)

`tools/sounds/door.py` (previews in `FlappyMonster_pruebas/puertas/sonidos/`, `--apply` writes the game's):
`doorClick` (`mechanics/door_click.wav`, 0.3 s: a dry metal latch clack and a dull thunk; played at the door AND at
each linked Activator), `doorOpen` (`mechanics/door_open.wav`, 1.0 s: rough grinding with a low rumble; pitch 0.85 when
it starts closing), `doorThud` (`mechanics/door_thud.wav`, 0.4 s: heavy low thud with dust). Each at −12 dBFS, no GAIN
entry. Not listened to by anyone yet.

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

`src/states/menu/SoundTestState.lua` (state `sound_test`), entered from the secret DEBUG MENU
([menus](../architecture/menus.md#debug-menu-secret)); BACK returns to it. (Until 0.5.163 the title code opened the sound test
directly and ◀ in its list opened the film test.) Two lists: every track of
`assets/music/index.json` (with its intro + loop, as in the game; pending tracks are skipped) and every sound loaded by
`Sound.load` (copies of the game's sources, so their `GAIN` is applied). Options (◀ ▶): list, loop, pitch (0.25–3),
volume, echo and room (OpenAL effects `love.audio.setEffect`; "not available" where the platform has none), and
position (seek ±5 s). It plays on its OWN sources and leaves the game's music and voices alone. Mouse / touch
(0.5.21, the user: everything must work without keyboard or pad): a ▶ / ■ button on the card (the list is switched
with the LISTA option — tabs above the list were tried and removed in 0.5.22, "se salen un poco de lugar"), a position bar that seeks on tap and drag, rows (tap = choose, tap again = play / stop; drag =
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
