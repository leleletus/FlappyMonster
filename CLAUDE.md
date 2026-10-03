# FlappyMonster — project map for Claude

LÖVE 11.x game (Lua / LuaJIT). Two games in one: the original Flappy mode
(`PlayState`) and **Adventure** — a platformer with a single-player mode
(`AdventureState`) and an online mode backed by an **authoritative server**
(`server/main.lua`). Code comments are in Spanish; keep that. Player-facing
text is translated (es/en, see *Languages* below) — never hardcode it. The
level editor is a dev tool and stays in Spanish.

Run: `love .` (game; `main.lua` is the update bootstrap, the game is `game.lua`) · `love . --editor [assets/levels/x.json]` (level editor)
· `love server` / `love server --headless` (server, port 22122).
Quick syntax check of everything: `for f in $(git ls-files '*.lua' | grep -v resources/); do luajit -bl "$f" >/dev/null || echo "$f"; done`

## Communication (user preference, IMPORTANT)

Chat replies to the user ONLY: ENGLISH, as short as possible (save tokens): results,
numbers, what's left. Explain in detail only when the user asks. This does NOT apply to
code, comments (Spanish), commits, docs or game text — those keep their usual rules.

## Golden rules

1. **Everything that affects gameplay must run identically in 3 places**:
   single player (`AdventureState`), the server (`server/main.lua`), and the
   online client (`OnlineAdventureState`, which only *predicts the local
   player* and *renders* everything else from snapshots).
2. Gameplay code must not touch `love.graphics` / real `Input` / real `Sound`
   outside render functions — the server stubs `Sound` (collects events),
   `Input` (per-tick bitmask stub) and, headless, `love.graphics.newImage`
   (returns a fake with real dimensions).
3. Globals used everywhere: `Sound`, `Input`, `TILE_PX`(64), `PLAYER_SCALE`(6),
   `GUMMY_SCALE`(4), `ADV_GRAVITY`, `ADV_JUMP_VEL`, `ADV_MOVE_SPD`,
   `WINDOW_W/H`, fonts `FONT_SMALL/MED/BIG` (Press Start 2P), `DEBUG_HITBOX`.
4. Visual style is 8/16-bit pixel art: integer positions (`math.floor`; the states round
   the CAMERA to whole pixels when drawing — fractional cameras left 1-px seams between
   blocks that only showed with the window scaled up), hard
   rectangles, black drop shadows offset 2-4 px, no rounded/smooth UI in-game.
5. EVERY image and sound the game uses is a real ASSET FILE (assets/images/..., assets/sounds/...),
   never only drawn/synthesized in code, so the user can edit or replace it. Generators are fine
   (tools/sounds/*.py, tools/ui/make_sprites.py …) as long as their output files are committed
   and loaded by the game; code only places/animates them. When a generator REDESIGNS an
   existing image, the original goes OUTSIDE the repo (`tools/ui/originals.py`:
   `/home/mtvemo/FlappyMonster_originals/<same path>-orig.png`, or `$FM_ORIGINALS`) and the
   generator always starts from it. `*-orig.png` is gitignored: never commit backups. The
   user's `.aseprite` source files live there too (same relative paths; gitignored), and so
   does reference audio (`music/TentacleTantrum.wav`). Design previews for the user go to
   `/home/mtvemo/FlappyMonster_pruebas/<thing>/vista_previa.png` (also outside the repo).
6. Data-driven catalogs: new tiles/entities/decorations/modes are a new file
   + one name in a list. The editor and server pick them up automatically.
7. Don't commit the many ` M` files in git status (they're mode-only changes).

## Screens, scaling and platforms (PC / Switch / Android)

- The game draws in a LOGICAL resolution: height 720, width `WINDOW_W` = 720 ×
  aspect (clamped 4:3..21:9) — 1280 on PC/Switch, e.g. 1600 on a 20:9 phone,
  960 on a 4:3 tablet. That is for MENUS only: inside a level (`AdventureState`,
  `OnlineAdventureState` enter/exit → `src/ui/View.lua` `lockGameplay/unlock`) the view
  is FIXED at 1280x720, scaled with letterbox bands, so every device sees exactly the
  same area (boss arenas!). `View.apply()` in `love.load`/`love.resize`. `main.lua` sets it in `love.load` AND `love.resize` (the
  PC window is resizable; Android rotates). **Never compute layout from
  `WINDOW_W/H` at file load time** (a `local X = WINDOW_W - ...` at the top of a
  module keeps 1280 forever): compute it when drawing (see
  `OnlineRoomState:_layout`, `ModeSelectMenu` `fit()`/`panelX()`).
- `lovesize` scales/letterboxes and sets a SCREEN-pixel scissor. So:
  (1) when rendering into a canvas, `love.graphics.origin()` AND
  `setScissor()` first, restore after (scene canvas in Adventure/Online states,
  level thumbnails in ModeSelectMenu); (2) to clip UI use `src/ui/Clip.lua`
  (`Clip.push(x,y,w,h)` / `Clip.pop()`: transformed + intersected scissor).
  Don't use stencils (Switch/Android backbuffers may lack a stencil buffer).
- Mouse/touch → logical coords in `main.lua` with the same scale as lovesize.
- **Touch controls in levels** (`src/ui/TouchControls.lua`, shared by Adventure/OnlineAdventure):
  drawn in SCREEN pixels after lovesize (`game.lua` calls `top:drawScreen()`), so on wide phones
  they sit in the black letterbox bands. D-pad (left: ←/→/↓, diagonals ↓+dir for the crouch
  jump; ↓ in the air = ground pound) + big jump button (right). Touch zones = the whole lower
  left/right halves (finger direction from the pad centre, slide allowed); above 30 % of the
  height nothing counts (HUD/pause). Sprites `assets/images/ui/touch/dpad-Sheet.png` (7 frames
  40x40) and `jump-Sheet.png` (2 frames 32x32) from `tools/ui/make_sprites.py`, integer scale,
  D-pad ≈ 30 % / jump ≈ 22 % of the screen height (the user found 40 % too big), 0.38 alpha over
  the game (0.7 in bands). Harness `touch_layout` (8 phone/tablet sizes) and `sp_boss MOBILE=1`.
- Testing other screens: run the REAL main.lua from a scratch app with a
  custom window size and `love.system.getOS = function() return 'Android' end`
  (Input.isMobile), plus a local server/bot for the online menus.
- Networking: `NC:connect` resolves the server name in a thread
  (`src/network/Resolver.lua`, LuaSocket) — ENet's own DNS lookup blocks the
  main thread (froze the Switch on reconnect). Failed/closed clients destroy
  their ENet host (deferred to the next `NC:update`). Peer timeout 10 s.

## Languages (i18n)

- `src/Lang.lua`: `local L = require 'src/Lang'` → `L('hub.create')`,
  `L('mode.hunt.left', { n = 3 })` (`{var}` interpolation). Missing key → es →
  the key itself. Files with a local `L` layout table (OnlineRoomState,
  OnlineLoginState, Notify) import it as `Lang`.
- Texts: `assets/lang/es.lua` / `en.lua` — nested tables by screen (`common`,
  `hud`, `menu`, `hub`, `room`, `oadv`, `results`, `msm`, `mode`, `srv`, `boss`,
  `notify`, `err`...). Add a key to BOTH files. New language = copy es.lua +
  one entry in `Lang.LANGUAGES`.
- Translate at DRAW time: option lists store keys (`LIST_BTNS`, pause opts,
  `PMENU_LABELS`) and draw `L(key)`; layouts must measure the real text
  (`fitText`, `FONT:getWidth(L(..))`) — English/Spanish differ in length.
- Modes: text fields are keys `mode.<id>.label|tagline|objective|empty_hint`
  resolved on read by `ModeTypes` (`m.label` is already translated).
  `reasonText(reason)` and `rank` notes return KEYS; `Modes.reasonText(mode,
  reason)` translates. Boss names: `boss.<type>` (every boss type in EVERY language file); a level can
  give one boss its OWN name like level names — props `title` (Spanish) / `title_en` (`title_<lang>`), editor
  group "Nombre" of every boss (`Boss.props`); `Lang.bossName(type, props)` = custom name in the current language
  (no title_en → the Spanish one) or the type's translated name; used by `Boss:title()` (bars, intro cinema) and
  Free Play cards (`LevelCatalog` `info.bossNames`). Harness `lang_names` (also warns about levels without name_en).
- Server messages: `Lang.message(key, args, extra)` → `{key, args, msg(es)}`;
  clients show `L.fromServer(data, fallbackKey)` in their own language.
  `round_end` carries `reason` + `noteKey` (plus Spanish text for old clients).
  Lang reads files with `love.filesystem.read` (the server patches it).
- `src/Settings.lua`: player options saved as `options.cfg` in the save dir
  (NEVER a name like settings.lua: the save dir shadows the game's modules).
  `SettingsState` = language selector (main menu → CONFIGURACIÓN).
- Level names: JSON `"name"` (Spanish) + `"name_en"` (+ `name_<lang>` for new languages);
  show them with `Lang.localName(t)` (FreePlay cards, mode menu, online room; the server sends
  `name_en` / `levelName_en` too). Editor: Nivel → General → "Inglés".
- Big menu buttons are TEXT drawn with `src/ui/PixelFont.lua` (the 5-px font of
  the old button images, accents included): `PixelFont.draw(text, x, y, scale,
  alpha)`, `.width`, `.height`. No text baked into images.

## Automatic updates

- `main.lua` is only the BOOTSTRAP (never auto-updated, like `conf.lua`; keep
  it small): mounts the active update slot over the installed game, then
  `require 'game'` (the real client entry, `game.lua`). Crash guard: a new
  version is `pending` until it runs 10 s without errors; an error (or 3
  unconfirmed boots) rolls back to `previous` and marks it `bad`.
  Disabled when running from the repo folder (`love .`); `FM_UPDATE=1` forces it.
- The mount is VERIFIED (`version.txt` must read the active version; relative path,
  then absolute save path). If it doesn't take effect (the Switch looped: download →
  restart → old version.txt → "update" again → restart...), main.lua goes back to the
  installed game, sets `nomount` = installed version and `UPDATE_BLOCKED` (UpdateState
  skips; retried when the installed version changes = reinstall). Every boot writes
  `<save>/update/boot.log` (no console on Switch). Updater guards: never reinstall the
  ACTIVE version (even if version.txt disagrees), never delete its slot, max 2
  unconfirmed installs of one version (`tryVer/tries`, cleared on confirm). main.lua
  changes only reach a device by reinstalling. Harness `update_boot` (FM_UPDATE=1).
- Save dir: `update/state.lua` {active, previous, pending, boots, bad, trash},
  `update/slots/<version>/` = only the files that differ from the installed
  game + `.manifest.lua` (hashes, so the next update doesn't rehash).
- `src/update/Updater.lua` + `src/states/UpdateState.lua` (first state; goes
  to the title at once when offline/up to date; also entered from the online
  login when the server rejects the version). Downloads only changed files
  (sha256-checked), copies unchanged ones from the old slot, then
  `love.event.quit('restart')`. Files deleted from the repo can't be hidden if
  the INSTALLED build has them (only matters for directory scans).
- Server `server/updates.lua`: publishes a snapshot of `git ls-files` (game.lua,
  input.lua, settings.lua, version.txt, src/, libs/, assets/) into
  `server/published/current/` ONLY when `version.txt` changes (checked at start
  and every 30 s, hashing in a thread) and serves it over ENet:
  `upd_manifest` / `upd_get {path, offset}` → `upd_chunk` (48 KB). That
  message contract is FROZEN (installed clients rely on it). The server must
  be run from the repo root (it needs `git`).
- RELEASE = bump `version.txt` in master (+ git pull/restart the server). Bump it
  too whenever `Protocol.VERSION` changes, or old clients can't join.
- `SERVER_HOST`/`SERVER_PORT` in settings.lua (`FM_SERVER=localhost` for tests).
- In-match connection indicator: `src/ui/PingIcon.lua`, sprites `assets/images/ui/ping/ping-Sheet.png`
  (5 frames 20x12: 0 = red X, 1..4 bars; bottom-left, bottom-CENTRE when touch controls show): level from ENet RTT AND the age of the last snapshot (RTT freezes when packets
  stop): 4 green, 3-2 yellow, 1 red, 0 = red X (no snapshot for 1.5 s / disconnected);
  improves after 0.6 s, big drops at once. `OnlineAdventureState.lastSnapAt`.

## Directory map

```
main.lua            BOOTSTRAP only (mounts updates, see Automatic updates) → game.lua
game.lua            client entry; state machine registry; editor hook (--editor)
settings.lua        global constants; requires src/world/Tiles (defines TILE_* ids)
input.lua           baton-based Input (keyboard/gamepad/touch VirtualPad)
src/Sound.lua       Sound.play(name,pitch,vol), playMusic(name), stopMusic, tracked sounds,
                    per-sound GAIN baked at load. ALL sounds are files (no procedural
                    audio): add one with load('name', 'assets/sounds/<group>/x.wav', 'static')
                    in Sound.load(), then Sound.play('name'). Folders: player/, enemies/<enemy>/ (shared ones in enemies/common/),
                    bosses/<boss>/, items/, mechanics/, traps/, water/, jingles/, ui/,
                    flappy/, fireworks/. Images: assets/images/<thing>/ (bosses/<boss>/),
                    all lowercase; music: assets/music/snake_case.wav
src/Music.lua       MUSIC CATALOG from assets/music/index.json (id, name, file |
                    intro+loop, volume, loop, level, boss). Sound loads every track from it
                    (`Sound.loadTrack`); `level=false` tracks (boss, menus, youWin) are
                    not offered as level music. Adding a song = file + one index entry.
                    Level JSON `"music": id` (editor: Nivel tab → Música, ▶ preview).
                    Music ALWAYS starts from 0 when (re)started: `stopMusic`/`playMusic` stop and
                    rewind even a PAUSED source (it used to resume where it was after leaving a
                    level from the pause menu); `AdventureState:exit` calls `Sound.leaveMatch()`
                    so retrying (game over) or re-entering starts like the first time
                    (harness `sp_boss RETRY=level`).
                    `Sound.playMusic('level')` resolves: `setLevelMusic` override (boss)
                    → `setBaseLevelMusic(level.music)` → 'classic'. Online the client
                    re-seeks the level track every 1 s to the server clock
                    (`Sound.syncMusic('level', t)`; tick 0 = round start), so all players
                    hear the same point of the song (tested: ≤0.1 s).
                    Generated music: `tools/music/tentacle_chip.py` → `tentacle_chip.ogg` + `.mid`
                    ("Tentacle Chip", boss track): chiptune modelled on an ANALYSIS of
                    TentacleTantrum.ogg (92.5 BPM 4/4 with a 3+3+2 tresillo groove — beat
                    trackers read it as 123 BPM —, 36-bar form ×2, offbeat skank) with
                    its own coherent G-minor harmony and a NEW melody built on one motif (the
                    G–F#–G neighbour note); seamless loop (tail folded onto the start).
                    `--instrumental` → `tentacle_chip_instrumental.ogg`: no melody, extra layers
                    only there (pad, tresillo rhythm chords, cowbell/claps/congas/timbales, fx).
                    `tools/music/menus_chip.py` → a chiptune take on `menus.ogg` (the user's theme;
                    140 BPM, 18 bars, boogie bass, sixth chords, blues lick in phrase 2). REJECTED by
                    the user: the game keeps the original `menus.ogg`; the script + .mid stay.
                    `tools/music/tentacle_nes.py` → `tentacle_nes.ogg` + `.mid` (catalog id
                    `tentacle_nes`, boss track): Tentacle Tantrum recreated as REAL Famicom music (2A03 +
                    VRC6 + Namco 163 emulation: 60 Hz driver, quantized periods, 32-step triangle,
                    15-bit LFSR noise, 1-bit DPCM kick/snare, non-linear DAC curves). Melody and bass
                    on N163 wavetables built from the harmonic fingerprint MEASURED on the original's
                    notes (one wave per section); drums from measured curves (kick 275→160 Hz then
                    F#2, a deep ~47 Hz boom in the break, very short bright snare); per-instrument gains
                    FITTED (bounded least squares) so each section's octave-band spectrum matches the
                    original's, then percussion raised to its percussive/harmonic ratio (0.21).
                    `tools/music/famicom.py` = the shared Famicom engine (Chan/play driver, 2A03/VRC6/
                    N163 renderers, noise, DPCM, DAC curves, band_power); the NES generators import it.
                    `tools/music/melody_nes.py` → `level_nes.ogg` (catalog `classic`, the default level
                    music; replaces level.ogg) and `boss_nes_intro.ogg` + `boss_nes_loop.ogg` (catalog
                    `boss_nes`), all + .mid, from the level song's MIDI (`tools/music/ref/melody.mid`, local
                    only). Level = faithful, one Famicom channel per MIDI instrument, at 137.5 BPM (level.ogg's
                    real tempo; the MIDI says 140). Boss = the SAME NOTES (recognizable; transposing A→A♭,
                    fifths from every bass note and a sustained noise "fizz" made it sound out of tune and
                    saturated — don't), boss style from timbres (dark bell/organ/clean choir on the long notes),
                    VRC6 power chords whose 5th is used only if it's in the harmony (else octave), short noise
                    hits on chugs, double kick, tom fills; 140 BPM, 4-bar intro, loop from the riff (bars 9-36 +
                    1-8). Gains fitted PER INSTRUMENT GROUP (bounded around musical base levels) to level.ogg /
                    the original boss remix's band spectrum; then a fixed drum push (×1.6 level, ×2 boss) with a
                    fixed kick/snare/cymbal split (chasing the originals' HPSS ratio buried the melody). Notes from the Musescore MIDI
                    (`tools/music/ref/`, local only, copyrighted, gitignored), everything the MIDI lacks
                    or gets wrong from the ogg analysis: drums (tresillo kick tuned to F#2, snare 2&4,
                    four-on-the-floor break), chords per half bar, and the finale's B–C#–D# bass.
                    `tools/music/winter_nes.py` → `winter_nes.ogg` + `.mid` (catalog `winter_nes`, the Snowball
                    Boss fight in lago_helado / jefe_nieve): "Winter Fallympics" (winter.ogg, the user's) as loaded
                    Famicom music from `tools/music/ref/winter.mid` (local only), with winter.ogg as the truth:
                    185 BPM, 144 bars, F major, song starts at 0.045 s of the ogg; MIDI and ogg agree bar by bar
                    (beat DTW) except DYNAMICS (bars 45-60 = a −10 dB drum break → chords ×0.2, arps ×0.45, mix
                    −5 dB) and the BASS: the ogg has it at F1/F2 under the MIDI's F3 → triangle sub 2 octaves down
                    (1 if below E1) + short N163 "slap" an octave down. Mix = per-group levels relative to the lead
                    (`LEVEL_DB`, RMS while playing; fitting the ogg's bands left chords/bells at ~0 % and the bass at
                    33 %), then a MEASURED octave-band EQ toward the ogg (`eq_to_ref`, 70 %, ±5 dB). Energy: drums
                    ~40 %, lead ~19 %, bass ~17 %, backing ~19 %; band shape within ±2 dB of the ogg in the main
                    sections. Energy additions: ghost 16th hats, snare roll every 8 bars, crash on section entries,
                    intro kicks (the ogg has a low hit there). `REPORT=1` prints the numbers without exporting.
                    ESCALATION (user: the repeated "Christmas" motif = Music Box bars 21/29/37/117/125 sounded
                    copy-pasted, the final not epic): the ogg doesn't get louder (it's limited), it gets DENSER
                    and brighter each time (spectral peaks: motif 15.5→21.9, Smooth Synth 85-116 15→26). So
                    `escalate()` adds layers without touching a MIDI note (bell octave / thirds / two-octave
                    sparkle, lead octave + thirds, a 16th "shimmer" arpeggio of the harmony, bass 8ths) and
                    drums on a separate 'x' bus (open hats, four-on-the-floor, crashes, rolls, tom fill, noise
                    risers before 45/61/117), growing per repetition. Layers take the gain of the instrument
                    they double (`LAYER_OF`/`LAYER_K`; normalizing them as a group flattened the climb). In the
                    final the MIDI lead (8-Bit Square) is ~6 dB under the previous melody → doubled on the VRC6
                    saw. Break 45-60: the melody stays (only the low end goes) and it rebuilds from bar 53 (the
                    first version cut the chords ×0.2: the melody vanished at 0:57 and jumped back at 1:18).
                    MIDI ERRORS FIXED from the ogg (2:09 on): the "8-Bit Sine" pad repeats one 16-bar
                    cycle 3× but the ogg changes the harmony → `PAD_FIX` (bar → dyad, voiced like the ogg:
                    B♭ with F on top, C with G on top, A7 as G/C#); the ogg also plays that pad 1 and 2
                    octaves up (strings `str*`, group 'strings'); in the final the motif is harmonized a
                    fifth above (`lay_bell5`), the lead is an octave higher than the MIDI's 8-Bit Square
                    (`lay_leadsaw` at +12) and an F pedal holds bars 121-123 / 129-132 (`lay_ped*`).
                    Same method over the WHOLE song (motif passes too): `CHORD_FIX` snaps the Pop Synth comp
                    to the ogg's chord (passes 2-3 of the motif = B♭ B♭ C C, like the final; same rhythm and
                    register) but ONLY sustained stabs (≥ 6 sixteenths): the short ones are little lines
                    (C/E → B♭/D → A/C in bars 12/28/36, bar 44) and snapping them sounded "different and weird"
                    to the user (the triad metric flags passing tones as wrong chords — don't trust it there), `COMP_LOW` doubles the comp an octave down only where the ogg does (even bars;
                    in the odd F/A bars it added a low A → A minor), the fifth harmony is on every motif pass
                    (from bar 22, growing), F pedals in 33-35 / 41-44 and a G in 36, bar 20's chromatic step
                    also an octave up (`COMP_HIGH`). Result: confident chord mismatches 15 → 2 (intro riser,
                    bar 26 ambiguous), missing notes 966 → ~780 over the song. The final was then SLIMMED (user: overloaded
                    and too strong for chiptune): no duplicate octave, no thirds above, no bell unison/thirds/
                    double octave, 2-octave pedal, softer shimmer/pump/hats, crash every 2 bars.
                    `tools/music/tentacle_winter.py` → `tentacle_winter.ogg` + `.mid` (catalog `tentacle_winter`, the
                    Icy Mega Crabby: jefe_cangrejo_helado arena + glaciar_cangrejo): a NEW arrangement, not a blend of
                    the two files (both are 185 BPM). FOUNDATION = tentacle_nes (imports its `load_midi`/`voices`/
                    `HARM`/`chord_at`/`section`: melody note for note, bass, harmony, drum patterns); PALETTE and
                    DRIVE = winter_nes (imports its `Song`, instruments, kit, `LEVEL_DB`: LEAD = winter's Smooth Synth
                    N163 + MUSIC BOX doubling every note an octave up + winter's pulse lead, saw only added in the
                    final — with the VRC6 saw as main lead the user still heard Tentacle's instrument —, harmonized
                    lead in chorus/final, hollow strings, pad, tri sub + slap, low comp doubling,
                    8th "pump" bass, offbeat open hats, four-on-the-floor, crashes, shimmer) + sleigh bells. FORM
                    (172 bars, 223.1 s): Tentacle pass 1 (72) | 4-bar BRIDGE (`bridge()`: IV–IV–V–V of the new
                    section, B♭ B♭ C C = exactly the chords of winter's CHRISTMAS MOTIF, which carries the bridge
                    alone on the music box (`MOTIF_F`; a lead cell from Tentacle's final used to play over it: the
                    user had it removed); drums emptied then a snare build + toms + riser, swelling strings; a bare
                    cut was "abrupt") | a NEW SECTION = winter's 1:48 melody (Smooth Synth, bars 85-116) + BOTH passes
                    of the motif from winter's final (117-132) as its payoff; the tail of pass 2 (129-132) is the
                    HAND-OFF (`handoff()`): winter's lead is muted there (`Part.mute`), Tentacle's lead voice already
                    sings the CHORUS phrase (its bars 25-26, then 25 and 34) over winter's backing while the music box
                    answers with motif fragments, and the last bar is turned from D minor into C (V) with a snare
                    build + riser, so the chorus arrives with a phrase already heard instead of replacing the
                    section; with winter_nes's WHOLE arrangement
                    (class `Part` wraps the song while `W.build` runs: keeps only those bars, shifted), UNTRANSPOSED
                    (F major): enters from the final's D# through B♭ (its dominant) and that C resolves into
                    Tentacle's CHORUS (D minor: V → vi, same scale as the motif) | pass 2 = chorus, scales, final only
                    (`SKIP2` 24 bars), which KEEPS the winter section's intensity to the end (user: after the hand-off
                    it must not let up): octave pulse + saw on the lead, shimmer, high strings, 16th hats, four-on-the-
                    floor, crash every 2 bars, snare fill every 4, scales in full time (not half-time), 16th pump bass
                    and 8th kicks in the final, riser + toms into the loop (levels: W 0, pass 2 −0.5…−0.1 dB). Going back to the riff after that payoff sounded like "the song
                    restarted" and made the track a minute longer than the originals (an earlier version had the
                    section in F# major to cadence into the F# minor riff). The motif appears only in those two places,
                    where its own chords are: v1 put it in the gaps of Tentacle's melody (other keys, bent by fits)
                    and the user found it forced in almost every appearance — don't graft a motif onto another song's
                    sections. SECTION CHANGES must not also be instrument changes (user: entry and exit felt
                    strange): the winter melody is sung by the SAME voice as Tentacle's (`Part.note` adds the music box
                    + pulse to `lead3`), Tentacle's chop (on the notes of winter's pad) and tresillo kick run under the
                    whole winter section, winter's shimmer + high strings already play in the last 8 bars before the
                    bridge and stay (fading) over the first 8 bars of the chorus that follows (with octave pulse/saw),
                    and the section is levelled in the mix (`W_DB` −0.8). Boundary jumps (MFCC, 4 bars before vs
                    after): motif→chorus 14.4 (−1.3 dB), final→bridge 25.3 (ordinary section changes: 15-31). MELODY VARIATIONS (`vary`, so it isn't
                    tentacle_nes note for note; all derived from the melody itself): chorus = an ANSWER in the bars
                    the melody leaves empty (27, 31, 35, 39): the previous bar's phrase in sequence a diatonic third
                    down (pass 2: a sixth up), avoid notes snapped to the chord, never over an original note. The
                    `vary` groups notes with `bar_strict`
                    (no tolerance) ON PURPOSE: that is how the approved answers were built. Everything else uses
                    `bar_of` with a 1/64-bar tolerance — the MIDI starts some notes a hair BEFORE the bar line, and
                    the riff's first note of pass 2 counted as pass 1 and played alone in the bridge (the "missed
                    dissonant note" at 1:33). The
                    riff, scales and final stay as the original: riff mordents + octave-up bars were tried and the
                    user found them odd. Strings swap to the root (or drop) when the lead rubs them. Break bell plinks have NO echo (winter's
                    3/16 echo on offbeat plinks sounded out of phase). Strength = sustained
                    BODY, not louder drums: with the kick at +1.5 dB the crest factor was 11 dB vs winter's 9.7 and
                    sections 1-2 dB weaker → kick +0.3, bass 0, pad −5, master −9.3 LUFS (no quiet stretches like
                    winter's intro). Measured vs winter 85-116 (rms −10.5, 64 spectral peaks/frame, crest 9.7):
                    sections −11.9…−10.7, 65-93 peaks, crest 9.9-10.7.
                    `tools/music/worldmap_nes.py [isla ...]` → the WORLD MAP music "Rumbo a las islas" (an original
                    tune, 120 BPM, C major, A-B-A = 24 bars = 48 s loop; verified by numbers only): SIX arrangements
                    with the SAME melody, chords, tempo and length — catalog `map_pradera|costa|fortaleza|nieve|
                    cuevas|final` — each with its own instruments and a LEITMOTIF that answers the melody in the bars
                    where it holds (4, 8, 12, 20, 24): meadow pulse + bird trill; coast steel drum, calypso bass,
                    rising marimba; fortress VRC6 saw + march snare rolls + triplet fanfare; snow music box an octave
                    up, sleigh bells, falling bells; caves music box with cave echo, half time, drips; volcano saw +
                    octave pulse, 8th bass, double kick, "eruption" hits. `StoryMapState:_music` plays the island
                    nearest the hero and `Sound.switchMusic(name)` jumps to the other arrangement at the SAME
                    position (the beat goes on, only the instruments change).
                    `tools/music/worlds_nes.py <track>` → the ISLANDS' level music (original tunes; phrases as note lists,
                    `song()` = intro·A·A'·B·[8-bar percussion solo]·A'', `build(..., isle=)` = the arrangement). Meadow:
                    `pradera_1` (G major, 136), `pradera_2` "Galope" (C major, 144, flute, galop rhythm), `pradera_bonus`
                    (152, four-on-the-floor + solo). Coast: `costa_1` "Calipso" (F major, 122: steel-drum N163 lead, calypso
                    bass 1-1y-3, marimba 8th arpeggios + a rising marimba motif, 16th shaker), `costa_2` "Arrecife" (B♭ major,
                    108: ocarina pulse, pad, bossa clave on the rim, bubbles; wave-like melody in long notes — the water
                    levels), `costa_bonus` (costa_1 at 138 + solo; cala_de_los_muelles). USER'S RULES for a world's second
                    track: change KEY, RHYTHM and TIMBRE and give it its OWN melody, never the mode or a transposition;
                    long notes are chord tones; ornaments stay in the scale (both asserted by a check); bonus = faster +
                    an intense percussion solo.
                    `tools/music/gloomy_nes.py [jefe|cueva]` → the DARK levels' music (verified by numbers only):
                    (1) `tentacle_gloomy.ogg` (catalog `tentacle_gloomy`, the Mega Gloomy fight: jefe_lugubre arena +
                    gruta_lugubre zone): Tentacle Tantrum (imports tentacle_nes's `load_midi`/`voices`/`chord_at`/
                    `section`: melody + bass note for note) SLOWER (150 BPM, times × 185/150), cave-like and LESS
                    LOADED (no saw, no 2nd voice, no pad/chop; bass = triangle only), with the SPIDER effect of Toby
                    Fox's "Spider Dance" (the user's brief): LEGS = 2A03 pulse 12.5 %, very short envelope, constant
                    16ths in groups of 8 on the chord's minor pentatonic + the blue note (♭5 passing to the 5th;
                    `LEG8`), never stopping — foreground (envelope ×1.0, octave up in intro/break) when the melody
                    rests, background (×0.4) under it; PAUSES at the end of every 8-bar phrase (half a bar of chromatic
                    run down, then half a bar of SILENCE except the melody; crash on re-entry = the "drop"); a second
                    DESYNCED pattern of 6 notes against the 8 (`LEG6`, VRC6, from the chorus on); register jumps every
                    4 bars; lead on a hollow N163 wave (odd harmonics) with a short bend-in + fast vibrato on long
                    notes and an echo 3 sixteenths later; dry drums (kick, short-mode noise "claw clacks" on 2 and 4,
                    offbeat hats only in chorus/final). Form: 4-bar intro (legs alone, then bass) + the 72 bars once
                    (121.6 s). Mix = per-group dB relative to the lead (`level`), legs capped at 50 % of the melody in
                    1-5 kHz while it sings, master −11 LUFS. (2) `dark_cave.ogg` (catalog `dark_cave`, LEVEL music of
                    the dark caves: gruta_lugubre, cueva_oscura): slow (72 BPM, 32 bars, 106.7 s), tense, D minor that
                    never resolves (ends on A major + a silence). The CONTRAST the user asked for: dark below
                    (triangle drone, a deep two-beat "heartbeat" kick, a swelling N163 pad) vs delicate above (a MUSIC
                    BOX with cave echo — sample-domain `delay` — and water drips: pulse blips with an upward chirp).
                    The music box sings a real lullaby (`BELL`): a 2-bar idea — climb the chord in quarters and rest on
                    a half note, then step down and rest — in sequence over each chord, 8-bar phrases A A' B A'', every
                    long note a chord tone, ending on the leading tone (v1 chopped Tentacle's riff cell in slow motion:
                    the user liked the atmosphere but "the melody doesn't make much sense musically"); in phrase 3 the boss's LEGS are heard far away (one group
                    of 8 now and then). Master −13 LUFS (ambient: SFX and silence carry the tension), catalog volume
                    0.8. Both loops are seamless (`fold`: the tail is added onto the start).
src/entities/
  PlayerAdventure.lua  THE player physics (shared by SP, server and client prediction)
  OnlinePlayer.lua     remote player renderer (tinted by player color, name tag)
  DeadEyes.lua         X eyes: draw() for the player sprite (9x16);
                       drawPair(midX, midY, sep, scale) for any other sprite's eyes
src/world/
  Level.lua            loads JSON, collision queries, render, vents/bubbles
  Tiles.lua (+tiles/)  tile types & materials registry (recipe at top of file)
  Entities.lua         entity type list TYPES (recipe at top of file)
  entities/Entity.lua  base class: movement, states, stomp, knockback, net hooks
  entities/EntityTypes.lua  registry, COMMON props, render wrapper for common states
  entities/Props.lua   editable property kinds (int, number, bool, enum, text, patrol, point,
                       points = ordered list of cells, e.g. boss waypoints; editor has
                       numbered draggable handles + add/remove buttons)
  entities/Interactions.lua  player<->entity rules (kill/hurt/stomp/pickup/checkpoint/GP)
  entities/types/*.lua gummy (helmet), crabby, pufferfish, spikefall, star, extralife, checkpoint, mortar, mirror,
                       rainspike (orchestrated spike), spikerain (the orchestrator),
                       miniboss1 (Nave Malvada), megacrabby (Mega Crabby),
                       trampoline (4 defs: up/down/left/right),
                       crabbytramp (Crabby trampolín, subclass of crabby), cryo (Congelador),
                       flood (editor-only placeholder for a Floods area),
                       bomb / bombobject (bombs, see Bombs), bossglass, bosswall, cryo (Freezer),
                       snowboss (Gran Bola de Nieve), phaseblock (Bloques de fase), crabby_ice (Crabby helado: 4 defs),
                       megacrabby_ice (Mega Crabby helado), megagummy (Rey Gummy), gummy_ice (Gummy helado),
                       gloomy (Crabby lúgubre: niveles a oscuras)
  AutoScroll.lua       auto-scrolling camera levels (see below)
  Floods.lua           rising/falling water areas (see below)
  BossZones.lua        boss arenas (see below)
  Decorations.lua (+decorations/)  foliage registry (see Decorations below)
  Modes.lua (+modes/)  online game modes: hunt, race, koth (ModeTypes.lua documents the API)
  PointAreas.lua       point zones (King of the Hill), see below
src/network/
  Protocol.lua         VERSION (bump on incompatible change!), input bits, own-state pack
  NetworkClient.lua    NC singleton (NC:on/off, NC:send, NC.myId)
  Predictor.lua        local prediction + reconciliation (re-sim is SILENT: Sound muted)
  SnapshotBuffer.lua   interpolation buffer for remote stuff
src/states/            Title, MainMenu, Play (flappy; HUD: big score in PixelFont with a black margin +
                       shadow (`boxed`), pops on each point and flashes yellow every 10; best with the
                       crown → "¡NUEVO RÉCORD!" blinking once beaten; difficulty plaque top-left in its
                       colour; game-over card. Labels use PixelFont because FONT_* lack uppercase
                       accents; harness `flappy_hud`). Difficulty pacing = `DIFFICULTIES` in settings.lua:
                       pipes spawn by DISTANCE (`spacing`), speed ramps per pipe passed (`ramp` up to
                       `rampMax`), the gap moves at most `maxJump` from the previous one; easy/normal were
                       reworked to be faster (user: "very slow, boring"), `flappy_hud BOT=1` proves them
                       beatable at top speed), Adventure (SP), FreePlay (SP level
                       hub), Online* (login, hub, room, adventure, results, error), Pause
src/editor/            Editor.lua (UI+tools), EditorModel.lua (data/save/validate), ui.lua
src/fx/Particles.lua   Particles.emit(kind,x,y) — kinds: gp_land, gp_start, block_break,
                       oneup, spawn, spike_land, spike_pop, collect, checkpoint,
                       boss_hit, boss_blast, boss_big_blast, mortar_blast, fire_puff, ember,
                       exhaust, smoke, sparks, mega_* (Mega Crabby), shake_small/shake_big (screen shake:
                       states add Particles.shakeOffset() to the camera when drawing)
src/ui/PixelIcons.lua  small pixel icons = PNGs in assets/images/icons/<name>.png (crown,
                       mode icons skull/flag/hill: a new mode icon is just a file); drawn
                       at integer scale with a 1-px drop shadow
Character restyles keep EVERY pixel of the user's original shape and only add the new style
                       (dark navy outline, highlight top-left, soft shade bottom-right):
                       `tools/ui/make_crab_redesign.py --apply` (Crabbies, Mega Crabby body + claws,
                       trampolines, and ALL spikes: one pixel-art steel spike scaled to each original
                       canvas — crabby/Mega 38x38, tiles/falling 32x32, Nave Malvada 26x27 down, icon 8x8);
                       `tools/ui/make_player_redesign.py --apply --mix` (the monster + Mirror pieces + life icon: almost-black
                       body with a lighter volume edge on thick parts, shaded white face — the user's mix of A and D);
                       `tools/ui/make_flappy_redesign.py --apply` (Flappy pipe + Background.png: same shapes, bevel/volume);
                       `tools/ui/make_gummy_redesign.py --apply` (Gummies, helmet, dead.png; the WINGS are a new design: curved
                       leading edge + fan of 3 long feathers, 2 flap frames, still 9x13). Both read the
                       originals kept outside the repo, so they can be re-run safely.
Small enemy sprites drawn by hand as character maps: `tools/ui/make_enemy_extras.py --apply` (preview in
                       FlappyMonster_pruebas/extras/): CRUSHED Crabby `crabby/dead.png` and crushed Icy Crabby
                       `crabby_ice/dead.png` (each Crabby skin loads its own `dead.png`; they used to share
                       gummy/dead.png, fine while everything was white), the guard's parachute, the Icy Mega's icicle
                       field (the Mega Crabby's CLAWS are NOT generated any more: after two proposals from this script — a
                       raised hermit-crab pincer and a fat shore-crab one — the USER drew them: `bosses/megacrabby/
                       claw_left-Sheet.png`, 2 frames 10x7 like the Icy Mega's, no bristles; never overwrite it).
                       Drawn at `CLAW_K` 0.7 (at the body scale, 1.0, the user found them enormous), `CLAW_X` 4.8, `CLAW_Y` −1.4,
                       `CLAW_IN` 1.5) with the Mega's shared claw animation (`pose2d`); art only, not hitboxes.
Spikes are images too: assets/images/spikes/spike.png (tile spikes, rotated/flipped
                       for the 4 directions; falling spike) — SPIKE SKINS: level JSON `"spikeSkin": "ice"`
                       (editor Nivel → Fondo y clima → Pinchos; `src/world/SpikeSkins.lua` LIST = id + PNG, new skin =
                       PNG + one line) → `spike_ice.png` (`tools/ui/make_ice_spikes.py`) for tile AND falling spikes
                       (spikefall/rainspike `wantsLevel` → `levelRef.spikeSkin`); render only. Set in the snowy
                       levels (lago_helado, torre_viento, icy arenas; retheme 'snow' theme + make_jefe_nieve write it;
                       their Crabbies are Icy Crabbies too: retheme `ICY_CRABS` swaps crabby/crabbytramp), crabby/spike.png and
                       bosses/miniboss1/spike.png (stretched in height while they grow)
Tile textures: assets/images/tiles/ (breakable, platform, platform_drop via the tile
                       def's `texture`; finish.png = the checkerboard, its wave + gold
                       frame stay in finish.lua). Stone, border (very hard compact rock) and deep
                       stone are 2x2-cell drawings (`texture.span = 2`: each cell draws its part
                       by column/row, so marks continue across blocks) kept VERY simple (flat
                       colour + a few short marks away from the edges; the user rejected busy
                       Voronoi cracks). **Lava** = tile `danger` (id 3, label "Lava"): lava.png /
                       lava_top.png (exposed top), 4 frames of a hand-drawn pattern shifted 4 px =
                       flowing; `src/fx/LavaFx.lua` (render-only bubbles that pop + droplets +
                       glow, like IceDrips). **Deep stone** (`deep_stone` 36, "Roca abisal", also a
                       mini block). Platform (non pass-through) = riveted steel girder. All these +
                       mortar and checkpoint sprites + sand_blend from `tools/ui/make_world_art.py`
                       (originals outside the repo). Terrain: dirt.png, grass.png
                       (grass cap over dirt, only when the top is in the air; covered grass
                       = dirt.png), grass_blades.png (3 variants of 16x4 above exposed tops)
                       from `tools/ui/make_terrain.py`; the light edges on faces in the air are
                       still drawn by code (neighbour-dependent). Mini blocks (ctx.quarter) draw
                       THEIR quarter of the texture at the same scale (seamless with big blocks).
                       **Sand** (`sand` 35, material sand, also a mini block): sand.png +
                       `sand_blend.png` (dithered band in the neighbour's colours, frame 1
                       dirt/grass, 2 stone, 3 deep stone, 4 border), drawn per HALF cell (big sand =
                       4 halves; sand mini blocks too) towards any neighbour half cell —
                       big block or mini block, `SubTiles.kindAt(level, gx, gy)` — so the change
                       is never abrupt. A mini block inside a block is NOT a validator warning.
src/fx/SpriteStrip.lua animation strips (frames side by side in one PNG):
                       SpriteStrip.load(path[, frameW]) → :frameAt(t, fps), :draw(i, x, y, r, sx, sy)
server/main.lua        authoritative sim (see below)
assets/levels/*.json   levels (server scans this dir; files starting with _ hidden)
```

## Player (`PlayerAdventure`)

- Fields: `x,y` = sprite center; `vx,vy`, `onGround`, `facing`, `frame`
  (1..3 walk/fall anim, 2 = rising/GP, 5 = crouch; dying uses monstrito4),
  `puff` (squash scale), `hp/hpMax` (3), `lives`, `invT` (invulnerability), `hurtT`
  (red flash only),
  `gpPhase` nil|'windup'|'fall', `gpLanded` (true only the step it lands),
  `stunT`, `dying/alive/deathPhase` ('freeze'→'jump'→'fall', `alive=false`
  when off-screen → caller subtracts a life and respawns).
- `update(dt, level)` reads global `Input.pressed/down` ('jump','crouch',
  'move_left','move_right'). Ground pound = press crouch in the air.
- Crouch: on the ground can't walk but CAN jump (crouch jump; the held direction
  sets vx = ±ADV_MOVE_SPD at takeoff, air control while airborne). Stays crouched
  in the air while crouch is held; `canStand(level)` = headroom for the standing
  box — without it the player is ALWAYS crouched (1-tile-high tunnels). While
  crouched `moveAndCollide` and contact hazards use the crouched boxes (feet
  anchored); no GP without headroom; no 'headBump' sound while crouched.
  `crouching` is in own-state flags (protocol v14 for the new rules).
- Oxygen bubbles: `Level:checkVentOxyCollision` = visible circle of bubble1
  (offset -3.5,-10.5 from b.x,b.y, r 24.5 + 6 px pad) vs the whole outer box.
  F1 draws the circles; breathing point = `getHeadPoint` (top of head).
- `hurt(n)` = n damage (default 1), returns true if it killed; otherwise grants HIT_INV
  (1.6 s) invulnerability + red flash (`hurtT`). ONE invulnerability system for every
  cause (`invT`, `grantInvulnerability(t)`, `isInvulnerable()`): no damage, no deaths
  except drowning / `die(nil, true)`, no pushes (`isPushProtected()`: knockback, recoil,
  squash; the push of the SAME hit still applies via `hitNow`), bosses' solid bodies are
  passed through, and it BLINKS (`invulnAlpha`; others see `PF_INVULN`).
- `bounce(vy)`, `knockback(dirX)` (GP shove + stun), `die()`, `respawn()`.
- Sounds: 'jump', 'step', 'dies2' (death), 'dies' (non-lethal hit), 'gpStart',
  'gpImpact', 'stunned', 'headBump'.
- Any NEW field that affects physics must be added to
  `Protocol.packOwnState/applyOwnState/isValidOwnState` (and VERSION bumped),
  otherwise reconciliation desyncs.

## Entities

**Flexibility rule (user's priority): base behaviours live in the BASE and a type only switches them on** — never
copy another entity's code. Guide: `docs/entidades/COMO_CREAR_UN_ENEMIGO.md` (every def field, trait and hook).
Switches on the type def: `traits = { needsPound, diesWithBlock, solidFull, renderFront, wantsLevel, freezeFloats }`
(copied onto each instance by `Entity.create`), `noises = { sound = tiles }` / `noise` (see Noise), `summons`,
`activatable`. In the base: RESERVE minions for ANY entity (`Entity:makeReserve` + default `netAtRest/netRest`; hook
`onMakeReserve`), stock crawler (`Crawler.mixin(Class)`: rotated boxes, surface normal, release, no fall while
attached; `Crawler.entityAhead`), block-break deaths (`Level:forStanders`, crawlers included), and for bosses
`Boss:enter(st)`, `Boss:zoneBounds()`, `Boss:minions(level)`, `Boss:nearestPlayer(level)`, `Boss.strike(pa, hit, dir)`
(the Snowball Boss's, now shared) and `src/fx/BossFx.lua` (`stars` = stun stars, `anger` = anger symbols, `target` =
landing mark; sprites in `assets/images/bosses/common/`). Asset layout: enemies `assets/images/<enemy>/`, EVERY boss
`assets/images/bosses/<boss>/` (megacrabby and megacrabby_ice moved there), sounds `player/` (incl. the flashlight
`light_*.wav`), `enemies/<enemy>/` (bomb, crabby, gloomy, gummy, mortar, pufferfish; `common/` = explode, respawn), `bosses/<boss>/`, `ambience/`...

- Instance = `Entity.create(cls, placement)`; placement `{type,col,row,sub,props}`.
  `x,y` = center; hitboxes `outerW/H`, `innerW/H` from `tuning.hitbox` × sprite size.
- Hooks: `loadAssets, sizeImage|sizePx, init, updateCustom(dt,level)->true,
  onWalk/onIdle/onDead/onStomp, canBeStomped, isBodyDisabled, getHazardBoxes,
  netPack()/netApply(a,b,f), render(camX,camY)`.
- `level.players` = list of active PlayerAdventure (entities "see" players).
  `level.liveEntities` = entities list.
- `Interactions.check` returns kill/hurt/stomp/pickup/checkpoint; `run()` also
  applies the ground-pound impact (`poundZone` kills, radius knockbacks).
  Entities can override interaction completely with `e:interact(pa)` (see boss).
  Hazard boxes may carry `effect = 'hurt'` (1 HP) instead of the default kill.
- Solid entities: `isSolidBody()` → put in `level.solidBodies` each step.
  `Cls.solidFull = true` = solid like a block (sides, stand on top, head bump;
  e.g. mortar); otherwise sides only (bosses: the top is the stomp zone).
- Editor hook: `Cls.drawEditorOverlay(props, cx, cy, zoom)` draws extra help
  when the entity is selected (mortar detection radius).
- A type file may return a LIST of defs (Entities.lua registers each), e.g.
  trampoline.lua → 4 palette entries sharing one class.
- Trampolines (top/bottom faces need 120 px/s; UNDER WATER 25: the slow fall never reached 120 and only a ground
  pound launched): `solidFull` bodies with `bouncyFace`. The player's
  `moveAndCollide` records `pa.bodyHit = {o, face, speed}` (face of the BODY it
  hit this step). `e:interact` returns `'launch', vx, vy` when the face and
  speed match → `pa:launch(vx, vy)` + `e:onLaunch(pa)`; predicted on the client
  (`Predictor:recordLaunch`). States ready → bounce (0.1 s: everyone touching
  bounces) → extended (`cooldown`, just a wall) → retract → ready.
- Crabby spike hazard = tile-spike proportions (base rectangle, 60% × 40% of the
  visible spike: `spikeDims` in crabby.lua), like `Level._spikeHitbox`.
- Crabby hooks: `drawTopper(cx, baseY, progress, dir)` (spike by default) and
  `bounceRotation()`; `Interactions.defaultCheck(pa, e)` = the normal rules, for
  entities whose `interact` only overrides some cases.
- `pa:squash(dirX)`: flattened for `squashT` (1.8 s): crouch sprite squashed to
  `SQUASH_K` (0.55) anchored at the feet, hitbox 20 px, stunned, stars at the
  flattened head, sideways hop. Own-state index 28; others see it via `PF_SQUASH`.
- `pa:launch(vx, vy)`: sideways launches set `ctrlLockT` (no input, no
  friction, NO stun/stars) instead of stunT. Own-state index 29 (protocol v12; v13 = flood entity type; v14 = crouch jump).
  Side trampoline faces trigger at any push speed; top/bottom need 120 px/s.
- Tile hitboxes are REAL for entities: platforms are slabs (`platform` h 0.72,
  `platform_drop` h 0.36). `Entity.moveAndCollide` snaps to the hit face of the
  tile hitbox (and of `solidFull` bodies via `Level:bodyAt`), in ≤16 px
  vertical sub-steps. `collisionAt` always uses the real shape. The PLAYER's
  landing also accepts `Level:onewayCellAt` (a one-way tile counts from its top
  face down to the cell bottom; with its prevFoot check a fast fall/GP can't
  skip a thin plank). Anything else that FALLS (Crabby/Crabby-trampolín drop,
  falling spikes, mortar fire) uses `Level:landingCross(x, y0, y1)`: hit only if
  it crossed a top face FROM ABOVE this step (never catches the slab it hung
  from, never tunnels). Walkers' edge probe is 4 px past the surface (half a
  tile fell out of thin slabs → turned every frame).
- Entities vs solid objects: walkers/crawlers collide with `solidFull` bodies
  (trampolines, mortars) like blocks (crawlers climb them: `Level:entitySolidAt`).
  Touching a body's bouncy face → `Entity:touchBody` → `Entity:launch(vx,vy)` →
  common state 'launched' (gravity, lands → walk; patrol bounds dropped). Flyers
  aren't launched. Crawlers: `Crawler.supportBody` (face from the normal).
- Ceiling Crabbies detect players while hidden (`canDropNow`/`isHiding`) and drop
  straight from the shell (`dropHidden`). STUCK UPSIDE DOWN (`drop_stuck`: spike in the floor, body above it): `self.y`
  is where the SPIKE is, so everything about the body uses `stuckHeadY` (spike base + `topperDy` art px: the ice spike /
  icicle sit 2 px into the shell there too — it left a 2-px gap) and `stuckCenterY`: `getOuterBounds/getInnerBounds`
  (the stomp box used to sit on the spike, under the visible body), and the drawing, which places each frame by its
  VISIBLE rows (`sk.inset`: the icy sink frames have empty top rows, so flipped they appeared at the top, detached,
  and grew DOWN towards the spike; now the body grows up out of the spike and stays attached; no claws on partial
  frames). Stomped while stuck (`Crabby:stomp`): `flipped = true` and `y` on the floor, so the crushed sprite lies
  upside down where the spike was (both travel in snapshots). Harness `icecrabby_rules clavado` (+ `LOOK=1` →
  icecrabby_techo.png: ceiling hide/unhide and the stuck sequence with its box). A wall-walking one RELEASES the crawl when
  it starts falling (`releaseCrawl` at drop_fall; otherwise the stomp rules kept
  seeing a ceiling normal and a stuck Crabby killed whoever jumped on it) and, once
  back on the ceiling, clears `dropped` → it drops again (a plain ceiling Crabby
  stays a floor Crabby). Trampoline crush: `pa:squash` + hurt + invulnerability for
  `PlayerAdventure.SQUASH_T` + 1 s, and it lands walking AWAY (`crushDir`).
- **Flyers** (`props.movement == 'fly'`): the vertical bob is a TARGET
  (`baseY + sin`) reached with `moveAndCollide` (stops at floors/slabs/solid
  bodies instead of clipping into them). A flyer already embedded > `EMBED` px in a
  face ignores it (gets out instead of flipping every frame); one blocked ahead by an
  entity doesn't turn if it can't go the other way (entity behind, patrol limit or
  wall: `Entity:canGo`) and, after turning for an entity, ignores entities for
  `FLY_TURN_CD` 0.8 s (it passes through): no convulsing, no pinning at a limit.
  The `flyers` harness uses fixed random sequences: `SEED=n` tries others.
  **FREE FLIGHT** (`src/world/entities/FreeFlight.lua`; common props `flyMode` = 'route' | 'free' and `flyRange`
  tiles around its home; or `e.freeFly` + `e.flyArea` {x0,y0,x1,y1} set by whoever spawns it): instead of going back
  and forth it picks a DESTINATION inside its area — a point where its box fits with margin (`FF.fits`) and that it
  reaches in a straight clear line (`FF.clear`) — flies to it with smooth steering and picks another on arrival / when
  slowed (`BLOCK_T`) / on timeout. Half the picks go to the candidate nearest a player (a real obstacle), the other
  half explore: the least-visited 3-tile sector of its area (`ffSeen`), farthest on ties. Never trapped: under a
  platform / in a pocket / in a corner it only accepts destinations with a clear path; with none in sight, short
  escapes in 8 directions; INSIDE something (a boss wall appeared on it) it goes to the nearest free spot through it
  (`ffGhost`, no collisions). Sim only (SP/server; clients draw snapshots). Any flying entity can use it. Harness
  `mechanics vuelo_libre` (out of a U pocket, from under a platform, out of a block; ≥ 11 of 15 sectors visited, never
  still > 2.5 s, never inside a block, approaches the player). Wings:
  `EntityTypes.drawWings` in the render wrapper (so every flying entity type gets
  them, behind the body): `assets/images/wings/wings-Sheet.png` (LEFT wing, 2
  frames 9x13, root at the right edge) + its mirror, integer scale; placed
  SYMMETRIC on the VISIBLE body: the opaque box of the type's `editor.sprite` (first
  frame if `editor.frameW`), measured once, with facing and flip (sprites are not
  always centred in their canvas); no sprite → outer hitbox. Harness `flyers` (every level, all enemies as
  flyers).
- Wall Crabby stomp (Interactions.defaultCheck): in the air, falling onto its top
  end OR coming from the open side (player centre beyond its outer face) =
  'stomp' with 4th return dirX = cnx → `pa:bounce(vy, dirX, soft=true)` (vx 300 +
  ctrlLockT, no stun); predicted via `recordBounce(vy, dir, soft)`. Protocol v15 (v16: King of the Hill; v17: crawler turn in snapshots; v18: MegaCrabby;
  v19: boss walls, Mega minions/pounce; v20: post-hit protection; v21: unified invulnerability;
  v23: boss intro + Mega emotes; v24: subtiles, dirt/grass; v25: connected floods; v26: generic links `to`; v27: ON/OFF blocks; v28: generic boss intros; v29: Mirror arena attacks; v30: boss broken glass; v31: special enemy deaths; v32: bombs; v33: snow/ice/thin ice; v34: sand; v35: deep stone; v36: freezer; v37: Snowball Boss; v38: Snowball Boss rebuilt, zone phases, phase blocks; v39: Icy Crabby; v40: Icy Mega Crabby; v41: Rey Gummy + reserve Gummies; v42: icicle field, guard entries/parachute, free flight; v43: dark levels, flashlight, Gloomy Crabby).
- **Crawler** (`src/world/entities/Crawler.lua`): surface-following movement
  (floor ↔ walls ↔ ceiling, concave and convex corners) for Crabbies with prop
  `wallWalk` (`Crabby.WALL_PROP`, off by default so old levels don't change).
  State `cnx/cny` (surface normal), `cdir`, `cattached`; rests at outerH/2 from the
  surface (same as a normal Crabby, attach snaps pixel-exact); corners are a rigid
  90° rotation about the corner measured pixel by pixel (no jump); `Crawler.angle` for
  drawing (Crabby renders "as floor" inside a rotation), `Crawler.toWorldBox`
  to rotate local boxes (spike, trampoline). Corner turns are part of the SIM
  (`Crawler.beginTurn/advanceTurn`, scalar fields `turnT/turnDur/tsx/tsy/tsang/
  tonx/tony` so the server rewind copies them): the surface switches at once,
  but `Crawler.pose(e)` (feet rolling around the corner + angle) is where the
  body really is. Hitbox, inner box, spike and trampoline boxes use
  `Crawler.poseBox`, stomp rules use `e:surfaceNormal()` (pose normal), and
  render draws the same pose. Net: `Crawler.netPack/netApply` (surface code + turn
  progress+1; the client starts the turn from its last drawn pose and runs it on its
  own clock), shared by Crabby and MegaCrabby. Big crawlers can lengthen the turn
  (`e.turnLength`, `e.turnMax`) and an entity can add solidity (`e:crawlSolidAt`).
  Detaches on knockback / drops and
  re-attaches on landing. Net: surface code in Crabby.netPack (`Crabby.NET_N`
  = number of Crabby fields; subclasses append after it).
- **Crabby skins + Icy Crabby** (`types/crabby_ice.lua`, one palette card "Crabby helado" with selector
  "Se esconde bajo" = 4 defs: `crabby_ice` ice spike, `crabby_ice_icicle`, `crabby_ice_snow`, `crabbytramp_ice`).
  Crabby images live in a SKIN (`Crabby.SKINS.normal|ice`, `self.sk`, class field `skinId`; network image
  names are prefixed per skin). The ice skin (`assets/images/crabby_ice/` from `tools/ui/make_icecrabby_sprites.py`
  = the Icy Mega Crabby body at Crabby scale) SINKS row by row when hiding (`sink1..8.png`, same total time).
  The sink frames keep the 18x8 canvas with EMPTY top rows (`sk.inset[img]` = rows; hid = 1), so every cover
  (drawing, hazard box, trampoline box) sits on the VISIBLE shell top via `Crabby:headH(img)` (minus `topperDy`
  art px: the ice spike and icicle sit 2 px into the shell, like the Mega's spike); before, the cover floated up to
  32 px above the sinking shell. Harness `icecrabby_rules tapa_pegada` (measures the opaque top in the PNGs;
  `LOOK=1` → icecrabby_esconderse.png).
  SMALL CLAWS (user's pick "A: Mini Mega" of 3, `tools/ui/make_icecrabby_claws.py --apply A`): `crabby_ice/claw_left-Sheet.png`
  2 frames 7x7 (open / closed; right = mirror), skin field `claw` {file, w, x, y, inset} (art px like the Mega);
  render-only `Crabby:drawClaws` after the body, animated like the Mega's (continuous offsets in art px placed to the
  SCREEN pixel = quarter-art-pixel steps; integer art-pixel steps looked choppy, and clipping every frame against the
  feet line cut the bottom row whenever a claw dipped — now only sinking frames are clipped): walking = each claw sways
  on its own phase + random snaps, `idle` = eased raise with a double snap, hiding / out / drops = closed and SINKING with the shell row by row (`inset + 1`; rows under the surface are
  cut with a quad viewport), hidden / peeking / dead = none; mirrored on the ceiling. Harness `icecrabby_rules pinzas`.
  Covers (on floor, walls and ceiling): ice spike = the normal spike (kills); icicle = the Snowball Boss icicle,
  always an icicle, hazard `effect='hurt', dmg=2` + `onHurtPlayer` recoil (Interactions 'hurt' now takes the
  damage from `hb.dmg`), drops from the ceiling like the spike (2 HP) and sticks; trampoline = the Crabby
  trampolín (`TC:trampImages` overridden); SNOW = a mound in the `snow_pile` decoration style, drawn IN FRONT
  (`coverFront`: grows from the surface while the crab sinks behind; `noPeek`): harmless while hidden;
  touching it → 'snow_crack' (0.25 s, no damage) → 'snow_burst' (whoever still overlaps: 1 HP + recoil);
  landing on it = 'bounce' (thrown up, no damage, bursts under you); GP on it = stomp kill; from the ceiling
  it falls as a snow lump (1 HP + 0.8 s stun) and bursts on the floor. Every Crabby (normal and icy) throws
  small physical debris of the block under it while hiding/unhiding (render-only `Crabby:renderDig` →
  particle `crab_dig`, colours from the surface, along its normal). Harness `icecrabby_rules` (+`LOOK=1`),
  online `online_smoke LEVEL=tools/levelgen/arenas/crabby_helado.json WATCH=crabby_ice_snow`. Protocol v39.
- **Icy Mega Crabby** (`types/megacrabby_ice.lua`, "Mega Crabby helado", `boss.megacrabby_ice`): subclass of
  the Mega (ALL its states/attacks/intro/rests/death); art per class (`Mega.loadArt(dir, w, h, cw, ch, clawK,
  clawX, clawY, clawIn)` → `self.art`; the icy one 18x13 at MS 10 from `tools/ui/make_icecrab_sprites.py`,
  Paralomis birsteini, claws 1.0 of the body scale, lower). Minions = Icy Crabbies (`summons` maps the types).
  Three ice rules: (1) FROST CLAP after every charge that hit nobody ('clap': claws up, slammed OUTWARD flat on
  the floor at `CLAP_AT`) → two floor waves (`waves`, speed `waveSpeed`, 1.4 s, 34 px tall = jump them) that
  `pa:freeze(waveFreeze)`; then 'clap_stuck' (`clapStuck` s, claws in ice blocks). WEAK POINT = a frozen CLAW
  (`clawBoxes()`, outside the body): ground pound on one = 2 dmg (once per clap, then recover); a normal stomp
  on a claw bounces; the back keeps its head spike → immune bounce (the user: "how is it vulnerable with that
  spike?"). (2) ICICLE FIELD where the wall pounce lands (it used to leave a slippery frost patch: pointless on a
  floor that is already ice): `fields` {x0,x1,y,dir,t,life}, one at each side OUTSIDE the claws (`patchWidth` tiles in
  total, `patchTime` s): floor cracks blink for `FIELD_WARN` 0.45 s (no damage), then icicles sprout from the inside
  out (`FIELD_SPREAD`), one every 32 px where there is floor (`fieldSpikes`, a pure function of field + level: the client
  needs `levelRef`); touching one that is out = 1 HP + recoil (SP/server, `Boss.withPlayer`); they shatter at the end;
  cleared on death; `unsafeAt` keeps respawns out. Art `bosses/megacrabby_ice/ice_field-Sheet.png` (3 frames 8x16: cracks,
  icicle, glint; drawn rising with a quad). (3) RAGE: sharp ice shards on shell AND claws (user's
  pick: body "A: Esquirlas" + claws "B: Corona" of 4 options, `--rabia A --rabia-pinza B`; `rage_body-Sheet.png` 26x21 / `rage_claw-Sheet.png` 18x15, 2 frames
  normal/glint, from `make_icecrab_sprites.py --rabia A`: procedural tapered shards, coverage-rasterised) drawn
  by Mega.drawLocal hooks `drawBodyOverlay` / `drawClawOverlay` (same transform: follow squash/claws), white
  flash when they appear; no red pulse; anger symbols = vein + steam only (`angerKinds`, no scribble);
  icicle fields last `ragePatchTime`. Its head spike sits 2 art px lower (`Mega.loadArt(..., spikeDy)`). netPackExtra = the
  Mega's 9 fields + waves {id,x,y,dir,t} + fields {x0,x1,y,dir,t,life}. Arena `tools/levelgen/arenas/jefe_cangrejo_helado.json` (music `tentacle_nes`);
  real level **glaciar_cangrejo** "Glaciar del Cangrejo" / "Crab Glacier" (`levels_boss.py`, snow theme): thin ice
  over water, ice track with a snow-mound Crabby, ice-spike pit with an icicle Crabby, low ceiling with icicle/snow
  droppers, a wall-walking climber, an icy trampoline Crabby, then that arena grafted (zone from column 89).
  Harnesses: `icecrabby_rules` (mega_* cases, `LOOK=1` → icemega_look.png), `boss_sim`/`boss_intro`/`online_boss`
  with `LEVEL=` that arena. Protocol v40 (v42: icicle field).
- **Icy Gummy** (`types/gummy_ice.lua`, "Gummy helado"): the Gummy class with its own art folder (`artDir`;
  `Gummy.loadArt(dir)` / `Gummy:art()` = idle, walk1/2, dead per folder) — `assets/images/gummy_ice/` from
  `tools/ui/make_gummy_variants.py --apply-helado` (user's pick: option A "Escarcha" WITHOUT the icicles = the
  exact Gummy shape in ice + snow on its head). Same behaviour (walk/fly, helmet...). Used in the icy levels
  (lago_helado, torre_viento, glaciar_cangrejo; retheme `ICY_CRABS` also maps gummy → gummy_ice). Harness
  `icecrabby_rules gummy_helado`. MEGA GUMMY = the boss **Rey Gummy** (see Boss system; the user rejected a new
  20x20 body — like the Icy Mega Crabby, a Mega must keep the SMALL sprite's resolution: the 16x16 Gummy drawn
  at scale 10, 1-px edits only). Gummies can be RESERVE minions (`Gummy:makeReserve/netAtRest/netRest`, like
  Crabby): the Rey Gummy's royal guard.
- **Gummy helmet** (prop `helmet`, Gummies only; `assets/images/gummy/casco.png`
  drawn over the sprite on the same 16x16 grid, scaled `HELMET_K` 1.10 around its
  bottom edge; the outer box grows up by what the helmet sticks out). `Gummy:interact`
  has NO ambiguous case: player feet in the upper half (outer box overlap, feet ≤
  centre) → ground pound = `'stomp'` (dies, `onStomp` breaks the helmet: sound
  helmetBreak + fx helmet_break), falling/still = `'helmet'` (run: `pa:bounce` +
  `e:onHelmetBounce()`: sound helmetBounce + render-only bonk `bonkT`, helmet intact,
  no points), rising = nothing; from the side/below = normal Gummy rules (it hurts),
  and a normal stomp there is also turned into `'helmet'`. The GP landing
  `poundZone` kills it too. Client predicts `'helmet'` as a bounce (+ sound). Net:
  Gummy netPack {helmet, bonkT}. Harnesses `mechanics` (66 drops) + `online_helmet`.
- Stomp window fix (all floor enemies, `Interactions.defaultCheck`): a stomp also
  counts when the feet were above the stomp line one step before (`STEP_DT`); fast
  falls (≥ 20 px/step) used to skip the ~20 px window and die on contact.
- **Pufferfish** (`types/pufferfish.lua`, sheet `assets/images/puffer_fish/
  puffer_fish-Sheet.png`, 16x16 frames facing RIGHT: swim 1-2, half 3, full 4; scale 5):
  water-only enemy on a plane IN FRONT (moves through everything, `renderFront` = drawn
  after the players in SP and online). It explores its SWIM AREA: prop `area` (kind
  `points`, 3-24 cell centres = any polygon, concave OK; editor shows it filled via
  `love.math.triangulate`): picks random targets reachable in a straight line INSIDE the
  polygon (`segInside`), usually the farthest of 8 candidates (so it reaches the ends of
  every arm), sometimes rests; `px/py` = position without the bob. Swim frames swap at
  `SWIM_FPS` 2.5 (animation only; the swim speed is `speed`). States walk(swim) → warn (a player IN WATER within `range` tiles;
  pufferWarn) → inflated (hazard box = body ×0.85, `effect='hurt'`; pufferInflate + fx
  puffer_pop) → deflate (pufferDeflate) → `cooldown`. Not killable (not stompable, not
  an obstacle, can't be knocked/launched). Prick: `Interactions.run` calls
  `e:onHurtPlayer(pa)` only if the hurt really took HP → pufferPrick + `pa:recoil`.
  Placed in `mina_inundada` (3, one crossing walls). Sheet restyled by
  `tools/ui/make_puffer_redesign.py --apply` (a separate spike ring was tried and dropped).
- Sounds decided only by the server (the causing client doesn't predict them) go in
  `Protocol.SHARED_SOUNDS` (helmetBreak, pufferPrick): the server sends them with no
  owner, so everybody hears them. New sounds: `tools/sounds/mechanics.py` (switch,
  helmet, puffer), levelled with `Sound.GAIN` to ≈ -12 dBFS (harness `sounds`).
- Walkers never flip-flop when boxed in: `Entity:isBoxedIn` (can't walk either way —
  `canWalk` = `canGo` + no spike/entity ahead + ground ahead if `turnAtEdges` — or less
  than `MIN_ROOM` (half a tile) of total play from walls/limits/edges) → they switch to the
  IDLE state (`boxedIn`; idle animation, never a walk frame; the idle timer is held) and walk
  again as soon as there is room. 'idle' is in snapshots, so online looks the same. Harness
  `mechanics` case `encerrado`. Crawlers keep their own movement.
- Flyers (`movement='fly'`) NEVER go idle: pauses only for walkers on the ground; in
  the air (also stunned) they keep the walk animation (`Entity:animateWalk`).
- **Play recorder** (dev): `FM_RECORD=1 love .` → single-player runs are logged to
  `<save>/recordings/<level name>_<date>.csv` (every 0.1 s: cell, px, hp, lives, in
  water, air used; events: daño/muerte with a guessed cause ahogado/pincho/pez/enemigo,
  reaparece, checkpoint, meta). `src/PlayRecorder.lua`, hooked in AdventureState. To
  analyse how the user plays a level (editor → F5 also records).
- **Bombs** (`types/bomb.lua` living bomb, Enemigos; `types/bombobject.lua` Bomba objeto,
  Objetos; shared `entities/BombCore.lua`; effects `src/world/Explosions.lua`). Sprites
  `assets/images/bomb/`: `bomb-Sheet.png` / `bombObject-Sheet.png` (user's, 4 frames 15x16:
  idle, walk 1-2, about-to-explode), `*-fuse-Sheet.png` (lit fuse overlay, 8 frames = 2
  flicker variants) and `explosion-Sheet.png` (7 frames 48x48) from
  `tools/ui/make_bomb_sprites.py` (never overwrites; --force). Sounds bomb_ignite/fizz/blast/kick
  (`tools/sounds/bomb.py`; the blast is in the harness `LOUD` list, up to −4 dBFS, RANGE 4;
  the kick is metallic). The user's sheets were retouched by `tools/ui/retouch_bomb.py`
  (1x2 eyes, metal cap, rope-coloured fuse; originals kept OUTSIDE the repo, see Golden rule 5). Living bomb
  walks/flies like a Gummy (no helmet, breathes when idle), NO contact damage and NEVER lit by
  proximity: touching it KICKS it in the player's walking direction (`touchKick`, cooldown
  `KICK_CD`); stomping it = the player bounces (`'bounce'` + `e:onBounced(pa)` hook in
  Interactions) and it is kicked; a GP shove (`knockback`) kicks too. A kick (`Core.kick`)
  leaves the route and lights the fuse. States
  'lit' (physics, flashes frame 4↔1 faster and faster = `Core.litFrame`, turns red, fuse
  overlay + `fuse_spark` particles, bombFizz every 0.5 s) → 'exploding' (`Explosions.blast`,
  explosion sprite scaled to the hurt radius, fx `bomb_blast` + shake) → dead/gone. Bomb object:
  physics only (falls, bounces off walls, trampolines), lights on contact, harmless when still;
  FALLING (vy > 260) or THROWN (`throw(vx, vy, lit, fuse)`, for a future boss) → `'hurt'` 1 HP +
  `onHurtPlayer` stun; a kick never hurts the kicker. Launched onto spikes = it lights (short).
  **Explosions.blast(level, x, y, {kill, hurt, push} tiles, source)** — authoritative (SP +
  server): players (distance to their box) kill → `die()`, hurt → 1 HP + push, push → push
  only (`launch`, weaker farther; invulnerability protects); enemies ('Enemigos') hurt →
  `dieFling`, push → `knockback`; other bombs → `onBlast` (kick + short fuse = chain);
  breakable blocks within the hurt radius break, ON/OFF Activators toggle. Clients get all of
  it from snapshots/tile+fx+sound events. Editor overlay: the 3 radii (+ trigger range).
  Harnesses `mechanics` (bomba_*), `online_smoke WATCH=bomb` (arena `bombas.json`).
- **Special deaths** (`Entity:dieFling(dir)` / `dieBurst()`, states `dead_fling` /
  `dead_burst`, `Entity.SPECIAL_DEATH`): already dead, ghosts (no interactions), fly through
  everything, end like 'dead' (`finishDeath`: respawn or gone). Drawn from state + deadTimer
  + x,y (same online). `dead_fling` = the block under it broke (`Level:breakTile` →
  `Level:forStanders`: 'Enemigos' category standing on the cell), spins up and out.
  `dead_burst` = a LAUNCHED entity lands on spikes / `contact='kill'` material
  (`Entity:onDeadlyGround`): fx `enemy_burst` (flash, shell chunks, smoke) + shake. Hitting
  an ON/OFF Activator (`hitTile` toggle) makes enemies on it hop (vy −380), never kills.
  Trampolines: an UP launch gives walkers their walking speed forward (min
  `LAUNCH_MIN_VX`) and starts them exactly on top of the face (a climbing Crabby was half
  inside the box, hit it sideways and bounced in place forever). Harness `mechanics`.
- Hunt rejects levels whose stompable enemies respawn (`info.respawning`). The level
  info for modes comes from ONE function, `Modes.entityInfo(entities)` (server,
  editor Nivel tab, level_check).
- Projectiles: there is no global projectile system; an entity owns its
  projectiles (list), exposes them as hazard boxes and sends them in
  `netPack` with a stable id so the client interpolates them (see mortar).
- Type def fields: name, label, category, class, defaults, props, hide,
  editor={sprite}, pickup, checkpoint, placement='sub', ceilingOnly.

## Online flow

Server (`server/main.lua`):
- `initRoomSim(room)`: Level + `Entities.create` for each placement →
  `sim.enemies`; one `playerSims[pid] = {pa, idx, queue, score, isSpectator,...}`.
- `stepRoom`: per player `processPlayerInputs` → `stepPlayer` (decodes bits into
  the Input stub, `pa:update`, death→lives/respawn/spectate,
  `checkPlayerEnemyCollisions` with lag-compensation rewind), then
  `level.players = active`, `level:update`, `e:update` for each entity,
  collisions again, sound events merged, mode tick / end-of-round.
- Sounds: `Sound.play(name)` on server → `{type='sound', sound, playerId}` event.
  `playerId` = the player whose step caused it (client skips its own, since the
  prediction already played it). Entity sounds get `playerId=nil` → everybody.
  Sound events carry only a name (no pitch). Sounds in
  `Protocol.PRIVATE_SOUNDS` (e.g. 'waterWarning', the drowning alarm) are never
  broadcast: only their owner hears them, from its own prediction.
- Snapshot `"s"` (30 Hz, unreliable): `p` players `{idx,x,y,facing,frame,flags,
  lives,hp,score,drown,air%,place}`, `e` entities `{x,y,facing,state,frame,alive,
  deadTimer*100,breatheT*100,flipped, ...netPack()}`, `md` mode hud, plus own
  state `o`/ack `a` for the receiver.
- Events `"ev"` (reliable, tick-stamped): sound, score, tile, fx, pickup,
  checkpoint, finish, spectate, air_collected, round_end (+ custom).
- `game_init` sends roster (idx,id,name,color) + the level JSON text.

Client (`OnlineAdventureState`): builds `enemyRenderers` from the level (same
indices as server `sim.enemies`), applies interpolated snapshot data to them,
predicts the local player with `Predictor`, processes events at their render
tick (own-player events immediately). Player colors: `PLAYER_COLORS` in server,
delivered in roster → `self.roster[idx].color`.

Game modes: `requires(info)` decides which levels a mode lists
(`info` = {enemies, killable, finish, bosses, autoScroll, pointAreas}); a level
may also whitelist modes with JSON `"modes": [...]` (editor: Nivel tab → Modos
de juego) and set `"matchTime"` (s) for timed modes. Mode defs may set
`emptyHint` (shown when no level qualifies). `m.level` is available to modes.
Mode defs also carry the in-match objective panel (always visible): a compact
3-line panel (MODE / objective / status) at the top between the score and the
lives when it fits (`topFree = WINDOW_W - 832`), otherwise a single thin line
below the score. HIDDEN during a boss fight (the boss bars own the top centre:
y 48 + 72/boss); only a `big` countdown is drawn, below the bars. Texts: `objective` (one sentence) and
`hudLine(md) -> text, urgent, big` (status line from the server hud `md`;
`big` = giant number below, e.g. countdowns). Tile triggers a mode doesn't
list in `triggers` are hidden: `Modes.hiddenTriggers(mode)` →
`level.hiddenTriggers` (Level:render skips those tiles; thumbnails via
`drawPreview(..., mode)`), e.g. the finish is invisible in Hunt/KOTH.

**King of the Hill** (`modes/koth.lua`, icon 'hill'): timed (`matchTime`, default
150 s; hud `tl` = centiseconds left, big countdown ≤10 s). Any mode whose hud sends `tl`
turns the HUD TIME clock into a countdown (`roundEndAt` = levelTime + tl, smooth). Points come from
**Point Areas** (`src/world/PointAreas.lua`, entity `pointarea`: rect via
`corner` handle, props points/interval/contested; placeholder entity like
`flood`). `PointAreas.update(level, dt, players, award)` is authoritative (SP
and server: server adds ps.score/scoreT and pushes `score` {kind='zone'} +
`fx` 'points' + sound 'pointGain'); `clientUpdate` only drives the visuals
(occupancy, local progress bar via `drawProgress`). The level draws the zones
in `Level:render`. Rank: score, lives, earlier scoreT; nobody scored → no
winner; generic `last_standing` still wins. Hunt rejects levels with zones.
Balance (data, in the level JSONs): Point Areas give 4 points per second
(points 4, interval 1); enemies give 40% of their usual points (floor: 15→6,
10→4) and ALL of them respawn (`respawn` > 0).
KOTH levels: cumbre_cangrejo, rebote_real, marea_alta (`modes: ["koth"]`; they
list no mode until the user places a Point Area in them).

## Special blocks (tiles)

- `Level:hitTile(col,row)` = the ONE entry for "head bump from below / ground pound
  on top": breaks `breakable` tiles, turns `toggle` tiles into their other state
  (`toggle = '<tile name>'`, keeps water/spikes bits). Returns 'break'|'toggle'|nil;
  changes go to `brokenQueue {c, r, raw, kind}` → server event `tile` (+`k='toggle'`)
  → clients `setTileRaw` + fx/sound (online clients never change tiles themselves:
  `canBreak = false`). A GP toggles each block once and lands normally.
  `hitTile(c, r, from)`: `from` = 'head' | 'pound' → `Level:tileBump` (render-only,
  `level.tileAnim`, advanced in `Level:update`): head = hop up, pound = the same hop
  DOWN (0.22 s, 0.22 tile). Online: tile event field `from`.
- **ON/OFF Activators** (`switch_on` 13 / `switch_off` 14, labels "Activador ON/OFF",
  Mecanismos; textures `assets/images/tiles/switch_*.png`; fx `switch_hit`, sounds
  switchOn/switchOff). They drive linked activatable entities (floods, `links`) and
  **ON/OFF Blocks** (`switchblock_on.lua`, 4 tiles: `switchblock_on` 18 / `_on_x` 19,
  `switchblock_off` 27 / `_off_x` 28; `switchBlock = {kind, active, other}`; inactive
  variants `editorHide`): ON Block solid while its activator is ON, OFF Block while it's
  OFF; inactive = passable + outline texture. Source = level JSON `"blockLinks":
  [{col,row,from=[c,r]}]` or the NEAREST activator. `Level:updateSwitchBlocks` (after
  every toggle; swaps tile ids, queues `tile` events with `k='set'` = no fx) — a block
  never turns solid with a player/obstacle inside (`pending`, retried in `Level:update`,
  only where tiles are decided: SP/server). Editor: Conectar tool → pick an activator,
  then click/drag ON/OFF Blocks to (un)link; cyan lines = links, faint = nearest.
  Harness `flood_control` case `switchblocks`. Protocol v27.
- **Invisible block** (`hidden_block` 15, Plataformas): FULL-cell hitbox but
  `collision='oneway', dropThrough=false` (pass through going up / sideways, stand on
  top, can't drop); enemySolid for entities. Visibility is RENDER-ONLY per client:
  `Level:updateHiddenBlocks(dt, boxes)` (SP: the player; online: own predicted box +
  remote players via `PlayerAdventure.outerBoxAt`) → `level.hiddenVis[row*65536+col]
  = {age, left, hold, blink}`: appear anim while touched (box +1 px, standing on it
  counts), then hold 0.25 s, blink 0.9 s, gone. Editor/thumbnails draw a dashed ghost.
- **Snow / ice** (`snow` 29, material snow, joinGroup ground; `ice` 30, drawn at 0.78 alpha, SLIPPERY: material `friction = 0.2` scales the player's ground friction, ice + thin ice; harness `mechanics hielo_resbala`;
  joinGroup ice). Textures `tiles/snow.png`, `ice.png` (the user's originals kept outside the
  repo), from `tools/ui/make_snow_sprites.py` (never overwrites; `--force`).
- **Thin ice** (`thin_ice.lua`, 4 tiles 31-34: normal → `_1` damaged → `_2` → `_3` about to
  break; later stages `editorHide`): SOLID on every side, half a cell tall (hitbox top half),
  0.8 alpha, textures `thin_ice_0..3.png`. `Level:crackIce(c, r, n, from)` advances n stages
  (≥4 → breaks to empty/water): standing on it `Level.THIN_ICE_WEAR` (0.8 s) per stage
  (`Level:updateThinIce`, SP/server only), head bump 1, GP 3 (the player keeps falling if it
  breaks), explosion 4. Tile events `k='crack'|'icebreak'` → client `tileBump('crack')` (shake),
  fx `ice_crack` / `ice_break`, sounds iceCrack / iceBreak (`tools/sounds/ice.py`); SP gets the
  same through the `level.tileFx(kind, c, r)` hook.
- **Freezer** (`types/cryo.lua`, entity "Congelador", Trampas; liquid-nitrogen launcher): solid 1-cell
  block (`solidFull`; prop `phase` > 0 = only from that boss phase on, see Phase system), prop `dir` (right/left/up/down; sprite drawn facing right, rotated). States
  idle → windup (`windup` s: shakes, gauge glows, frost puffs, cryoWindup) → fire (stream grows/leaves at
  `STREAM_SPEED` 1800 px/s for `burst` s, cut at the first solid tile = `reach` in netPack; cryoBlast) →
  idle. `mode` 'interval' (`interval`, `firstDelay`) or 'switch' (`activatable`: fires when its linked ON/OFF
  Activator changes, `trigger` any/on/off; linking it in the editor sets switch) — boss arenas: fires with
  the gates. Stream = hazard box `effect='freeze', time` → `pa:freeze(t)` (own-state index 30 `iceT`,
  `PF_ICE` 128, protocol v36): no control (FROZEN_INPUT), keeps its pose, slides/falls; each jump/crouch
  press removes 0.22 s; on break cryoFree + fx `ice_shatter` + 0.7 s invulnerability. Enemies in the
  stream: `Entity:freeze(t)` → common state 'frozen' (`canFreeze`: category Enemigos only; mortar no;
  bosses no unless they override; `freezeFloats` = stays in place, pufferfish), deadTimer = time LEFT,
  falls (flyers too), harmless (`Interactions.frozenCheck`: landing on it / GP → 'stomp' kills a stompable
  one, else 'shatter' = thaw), `thaw()` resumes the previous state with its timer. Look: `src/fx/IceEncase.lua`
  (9-slice `fx/ice_block.png` around the body + ice tint shader, blinks the last 0.6 s), used by the
  EntityTypes render wrapper, PlayerAdventure and OnlinePlayer. Art `assets/images/cryo/` from
  `tools/ui/make_cryo_sprites.py`; sounds `traps/cryo_*.wav` from `tools/sounds/cryo.py` (cryoFreeze is a
  SHARED sound). Particles cryo_puff/cryo_mist/cryo_blast/ice_freeze/ice_shatter. Harness `mechanics`
  (cryo_*). Drawn from PIECES (`tools/ui/make_cryo_parts.py`, all 16x16 centred on the cell): body
  `cryo_body-Sheet` (always upright, 4 frames), cannon `cryo_cannon-Sheet` (drawn facing right, rotated to
  `dir`), feet `cryo_feet` (drawn facing down, rotated to the supporting side); `cryo-Sheet` = the classic
  assembly (editor icon). `Cryo:support()` (render only, needs `levelRef`: `wantsLevel`, also set by the
  editor) = the solid side holding it, never the firing side, preference floor → behind the cannon → sides →
  ceiling; nil = it HANGS: no feet, `cryo/chain.png` + `anchor.png` + `clamp.png` to the ceiling
  (`tools/ui/make_cryo_chain.py`; two side chains when firing up). Harness `snowboss_look` (snow_cryo.png),
  `online_smoke LEVEL=tools/levelgen/arenas/congelador.json WATCH=gummy WANT=frozen WANTICE=1`,
  `editor_open PLAY=tools/levelgen/arenas/congelador.json`.
- **Ice drips** (`src/fx/IceDrips.lua`, render-only, per client): tiles with `iceDrip` and air
  below grow drops (`fx/ice_drop.png`) that fall and splash. **Snowfall** (`src/fx/Snowfall.lua`):
  level JSON `"snow": true` (editor Nivel → Clima → "Nieve cayendo"), 3 depth layers of
  `fx/snowflakes.png`, visual only. Decoration `icicle` (Carámbano, `decorations/ice/icicle.png`,
  hangs from the top of its cell). Test arena `tools/levelgen/arenas/hielo.json`.
- Harness: `tools/tests/run.sh mechanics` (also covers the Gummy helmet, the
  pufferfish and thin ice: `hielo_*`). Protocol v22 (ON/OFF + invisible blocks + helmet + pufferfish).

## Dark levels, flashlight, noise and the Gloomy Crabby

- **Dark level** = JSON `"dark": true` (editor Nivel → Fondo y clima → "A oscuras (linterna)"). It AFFECTS
  GAMEPLAY (not just a look). The only light is each player's FLASHLIGHT: action `light` (keyboard F / LShift,
  gamepad X / Y, touch = small button above the jump: `TouchControls.update(active, level.dark)`, sprite
  `ui/touch/light-Sheet.png`). `PlayerAdventure:updateLight`: toggles; on = drains `LIGHT_TIME` 7 s; off = recharges in
  `LIGHT_RECHARGE` 9 s; if it runs OUT it turns off and can't be lit for `LIGHT_COOL` 3.5 s; `pa:blindLight(t)` (a boss
  hit) forces it off. Part of the SIM: input bit `IN_LIGHT_P` 64, own-state 31-33 (`lightOn`, `lightBat`, `lightCd`),
  others see `PF_LIGHT` 256. Protocol v43. Sounds lightOn/Off/Out/Dead.
- `src/world/Lights.lua` (pure geometry, shared by sim and drawing): cone towards `facing`, `RANGE` 5.2 tiles, `HALF`
  27°, cut by solid blocks (`Lights.ray`); `Lights.lit(level, x, y)` → true + the light's origin.
- `src/fx/Darkness.lua` (render): after the scene + water effect and BEFORE the HUD, a quarter-res canvas starts at
  `AMBIENT` and each player adds, in steps, a halo (always: you see yourself) and, lit, the cone traced with rays;
  then it is MULTIPLIED over the screen (no shaders/stencils). It restores the previous canvas (harness captures).
  What must always show is drawn after it: entities with `renderGlow(camX, camY)` (`Darkness.renderGlow`). HUD:
  `src/ui/LightHud.lua` (icon `ui/flashlight-Sheet.png` + 8 segments, under the lives).
- **Noise** (`src/world/Noise.lua`) = what enemies can HEAR, and what the player can use as a DISTRACTION (Gloomies go
  look where it sounded). GENERIC: everything that makes noise and how STRONG it is (radius in tiles) lives in two
  tables there — `Noise.R` (things that are not an entity's sound, emitted with `Noise.emit(x, y, Noise.R.x)`: pickup 4,
  life 5, thin-ice crack 4, ON/OFF switch 7, hitting a boss 8, ice break 8, breaking a block 9, a hurt player 10, a
  killed enemy 12, ground pound 15) and `Noise.SOUNDS` (SOUND names that are also noise: trampoline 8, helmetBounce 6,
  helmetBreak 8, mortarShoot 10, spikeHit 8, cryoBlast 9, pufferInflate 7, bombIgnite 4, bombKick 6, bombBlast 26).
  `Noise.bind(level)` wraps the current global `Sound.play` once: any listed sound played while simulating emits its
  noise where its maker is = `Noise.src(x, y)` (set by `Interactions.run` around each entity) or else Sound's emitter
  (`Sound.getEmitter`, set by the states around each entity update); no position → nothing (UI, the player's own
  sounds). A NEW entity needs no change here: its type def declares `noises = { itsSound = tiles }` (registered by
  `EntityTypes.register`) or, for a pickup, `noise = tiles`. WALKING AND JUMPING MAKE NO NOISE. `faint` 3.5 = the
  Mega Gloomy's echolocation mark. Only recorded in
  DARK levels, in `level.noises` of the level bound with `Noise.bind(level)` (AdventureState
  on enter, server every `stepRoom`; the online client binds nil). Listeners: `Noise.heard(level, x, y, sinceSeq, k)`.
  Every noise leaves a NOISE MARK (the user's rule made visible: noise → mark → that's where they go look): fx
  `noise_s` / `noise_m` / `noise_l` → `Particles.emit` forwards them to `src/fx/NoiseMarks.lua` (SP and online, same
  path as any fx) → a red "!" (`fx/noise_mark.png`) for 1.5 s + a ring growing to the hearing radius, drawn by
  `Darkness.renderGlow` over the darkness.
- **Gloomy Crabby** (`types/gloomy.lua`, "Crabby lúgubre", Cancrocaeca xenomorpha; art `assets/images/gloomy/`
  = the user's pick, option B "Fantasma", 9 frames 26x15 at scale 4 + `glow-Sheet.png`, from
  `tools/ui/make_gloomy_sprites.py --apply`: body hand-drawn, LEGS traced by code hip–knee–foot so every pose comes
  from the same legs; sounds `tools/sounds/gloomy.py`). ALMOST SILENT (the user found it noisy: silence is the
  level's tension): only a dry accelerating rattle before the leap (the first hiss "didn't fit the character") and the
  leap sound; what happens to it is an ICON floating over it (`gloomy/icons-Sheet.png`, 3 frames 7x9, thin, above it:
  the user PREFERRED these over a bigger/bolder version — reverted): "!" heard something, "?" searching, "…" lost the
  trail; `icon` in netPack. A different archetype: no route, never hides, never kills on touch (`onTouch = 'hurt'`),
  always a Crawler; in the dark only its two glow points show. NAVIGATION = PLAN, don't steer: `Gloomy:plan` simulates
  its own crawl (`Crawler.move` on a copy) in BOTH directions along the surface, up to `PLAN_MAX` or a full loop, keeps
  the one that passes nearest the goal and walks THAT whole path (`planLeft`) without changing its mind (re-steering
  every moment made it go back and forth and shake at corners and platforms: turning a corner flips which way is
  "closer"). At the closest point, or earlier if walking is a real detour (≥ 3 tiles and > 1.6× the straight line),
  it LEAPS to the goal when it is within `LEAP_MAX` 5 tiles with a clear line (ceiling → floor, wall → shelf); else it
  searches. States: 'walk' (wanders, random reversals, 'idle') → HEARS a noise → 'hunt' (to WHERE IT SOUNDED) →
  'search' (`searchTime` s around the spot: re-plans back when it strays > 2.5 tiles) → "…" → walk. SENSES a player
  within `senseRange` 2.6 tiles if moving (half if still) → 'crouch' (`leapWind` 0.45 s: glow blinks + rattle) →
  'leap' (ballistic; contact = 1 HP + recoil via `onHurtPlayer`; grabs whatever it touches, never sticks) → 'rest'.
  'taunt' (1.1 s push-ups, crouch ↔ idle frames, eyes blinking) after hurting a player, by leap or by touch. LIT by a
  flashlight → 'flee' (plans away from the light every `FLEE_PLAN` 0.6 s, ×2 speed; calms `calmTime` s after dark).
  NEEDS A GROUND POUND: class flag `needsPound` (generic, `Interactions.check`: a normal 'stomp' on such an entity
  becomes 'bounce'; the GP and its landing zone still kill; and contact from ABOVE such an entity never hurts — only
  from the side, or when `e:hurtsFromAbove()` says so = its own leap; after the bounce the player was still inside its
  box going up and took damage). Dies flung when the block it GRIPS breaks (floor, wall
  or ceiling: `Entity:standingOnCell` now handles crawlers, which have no `onGround`). Doesn't walk through other
  enemies: `Crawler.entityAhead(e, level)` (generic, shared with Crabby) → turns round and drops its plan.
  Net: {surface, turn, modeT, icon}. Can be a RESERVE minion (`makeReserve`). Test
  arena `tools/levelgen/arenas/cueva_oscura.json`. Harness `gloomy_rules` (cases `navega`, `marca`, `burla`...).
- **LIGHT MOODS (all levels, render only)**: `level.light` = JSON `"light"` (day | dusk | night | cave | none) or auto
  (`Level.lightMood`: background 'cave' → cave, time dusk/night → that, else day; editor Nivel → Fondo y clima → "Luz").
  `src/fx/Darkness.lua` draws them with the SAME light canvas as the dark levels (`Darkness.MOODS`: ambient colour that
  multiplies the screen, × strength of the lights): dusk warm, night cool and darker with torches/lava glowing, cave =
  PENUMBRA (playable). The PLAYER gives NO light in these (user: night must feel like night) — only in dark levels. With a `depth` biome, everything below the surface
  line is cave penumbra (stepped transition band) even on a day level. Light sources: decorations with `light`, TILES
  with `light` in their def (lava) and the players. Soft lights = `RINGS` stepped circles (flat discs looked wrong).
  Cave mood also turns the ECHO on by default (`level.echo`). What is HOT keeps glowing: tile lights with `emissive`
  (lava: the cell itself is never darkened, bigger glow), entities with `e:lights()` → {x, y, r, color, a} (the mortar's
  fireballs; `Darkness.render(..., entities)`), and the red-hot pixels of sky layers (`Sky` builds a glow image per layer
  from its bright orange/red pixels — craters, lava streams, magma veins — and `Sky.renderGlow()` redraws them after the
  darkness, with the same clip via `Clip`). Mortar fireball REDESIGNED (`tools/ui/make_biome_art.py mortar_flame`, 6
  frames; the user's original in `FlappyMonster_originals/assets/images/mortar/flame-orig.png`). `level_shots` draws the mood (`LIGHT=0` = without).
- **Glowing decorations**: a decoration type with `light = { r = px, color, a, dy, pulse }` (glow_mushroom,
  cave_crystals, torch, ice_crystal) adds a VERY subtle two-step light to the Darkness canvas (render only: it is not
  a flashlight for `Lights`). New luminous decoration = that one field.
- **Cave ambience** (render-only sound, per client; never Noise): `DecoFx.drip` (stalactites) and `IceDrips` play
  'dripFall' when the drop lets go and 'dripSplash' where it lands (`DecoFx.sound` → `Sound.playAt`, random pitch,
  attenuated, with the cave echo; QUIET on purpose: `DecoFx.AMBIENT_VOL` 0.35, ambience layers 0.04-0.14 — the user
  wanted them as background, not something that stands out); `src/fx/CaveAmbience.lua` (`tick(level)` from both level states, only when
  `level.echo`) plays far drips every 2.5-7 s, a rolling pebble every 14-32 s and a low rock rumble every 24-50 s at
  random pitch/volume. Files `assets/sounds/ambience/` from `tools/sounds/ambience.py`.
- Lives HUD: in dark levels the "x3" is white with a black shadow (black text was invisible).
- **Echo** (deep caves): level `echo` (default = `dark`; JSON `"echo": true/false` forces it; editor toggle "Eco")
  → `Sound.setEcho(1)` on entering the level (0 on `leaveMatch`). Every `Sound.play` schedules delayed, quieter,
  slightly lower repeats (`ECHO_DELAY` 0.21 s, ×0.5 each, up to 3) and the LOUDER it arrives (volume after distance ×
  `ECHO_W[name]`: a slam booms, a step barely) the more echo it leaves. Done with delayed clones in `Sound.update`
  (OpenAL effects aren't available on every platform). Music has no echo.
- **Mega Gloomy Crabby** (`types/megagloomy.lua`, "Mega Crabby lúgubre", `boss.megagloomy`; boss of the dark
  levels). Fourth version: MOSTLY terrestrial + its ceiling attack (v1 = "tedious, boring, confusing"; v2 lived on
  walls/ceiling and stabbed its legs down: odd; v3 was ground-only: the user wanted the ceiling launch back). ONE RULE,
  visible on screen: **it only attacks if there is a red "!", and it attacks THAT "!"**. Two sources of "!":
  (a) ECHOLOCATION 'ping' every `pingEvery` s (stops, raises the claws, snaps): ONE ring from its body that detects
  whoever it TOUCHES, even standing still and silent (user: echolocation doesn't need the target to make sound) →
  "!" there (`Noise.emit` faint + `tEcho`) → it JUMPS there ('pounce'); (b) player NOISES (see Noise: hit < hurt <
  kill < ground pound; jumps and steps are silent) = investigation points → it CHARGES toward them ('charge': dashed
  floor line to the wall `endX`; crouch under it or jump it). Either one within `CLAW_PICK` 4 tiles → CLAW instead.
  With a fresh "!" (`tAge ≤ FRESH` 4 s, cooldown over) → 'aim' (eyes blink, hiss, the attack's mark; `startAim`
  spends the "!"). CLAW ('claw'): the NEAREST claw aims at the player from its joint (`MG:clawAim()` = pivot +
  direction to `markX/markY`, used by sim, red dotted line and drawing alike): during 'aim' the mark FOLLOWS the
  player (`tPa`), any direction incl. up, locked the last `CLAW_LOCK` 0.2 s; the thrust hits along that line up to
  `CLAW_REACH` 240 px (`clawHit`) — the old horizontal box hit jumping players it didn't visibly touch. CEILING every
  `ceilingEvery` s (14; first at half): 'climb' (parametric path floor → nearest wall → ceiling, `MG:pathAt(u)`, body
  rotated by `ang`: ±90° wall, 180° ceiling) → 'ceil_ping' (a BIG ring, `RING_CEIL`) → 'ceil_wait' (mark = where the
  ring found a player, else straight below) → 'aim' (kind dive, target sprite on the floor; light doesn't cancel it)
  → 'dive' (launches itself there, flips to land upright, `slam`). After charge / pounce / dive it is 'tired'
  (`TIRED_T`): immune (bounce) unless a flashlight lights its body → 'dazzled' (covers itself with the claws + the
  usual STUN STARS orbiting over it = "vulnerable now"): stomp 1 / GP 2, one hit. Contact in an attack = 1 HP + push;
  LIT while aiming on the floor → 'flinch' ("…"), cancelled. Phase 2 (`phase2`): faster tables. RAGE (hp ≤ `rageAt`
  0.4): 'roar' (claws up), EVERYTHING × `rageSpeed` 1.45 (`MG:pace()` → table row + multiplier: walk, charge, aim,
  cooldown, climb, dive; like the Mega Crabby's `rageSpeed`), and it SHOWS like the Mega Crabby (`MG:angry()`): slight
  1-px tremble, soft reddish pulse, anger symbols (`BossFx.anger`, drawn in `renderGlow` so
  they show in the dark); 'shriek' every `shriekEvery` s (`level.lightScale` for `dimTime` s + reserve Gloomies);
  CRYSTALS grow ON THE CLAWS — never on the shell: crystals on the head look like spikes and the head is what you
  stomp. 'taunt' after an attack that hit somebody. DEATH is a crab's, not a robot's (`MG:defeat` override, no
  explosions): 'dying_curl' → 'dying_out' (`releasesZone`). x,y = centre of its SHELL (`BODY_ROW` 11, box 11x6 art
  px; legs don't count); art = the SAME pixel grid as the small one at scale 10 (`MEGA_B`, 9 frames 38x21 + glow).
  Intro: falls from the dark AT ITS EDITOR x (`onIntroStart` → `stand(level, self.x)`; it used to land at the zone
  centre wherever it was placed, while the camera looked at the editor spot). Music: zone `tentacle_gloomy`.
  CLAWS (user's picks): option B "Hoz" (long sharp sickle, 2 frames 14x7 `claw_left-Sheet.png`, right = mirror), at
  rest pointing INWARD ("C Ↄ": tips toward the body's centre) and LOW on the body (`CLAW_DY` 2 art px under the shell
  centre; the mockups had them too high); raised (ping, roar) = exact 90° turn, mirrored so the dorsal crystals face
  OUTWARD. `MG:clawPose(side, now)` → out, dy, raised, frame, outward (render-only). Rage crystals = mix of options
  B "Espinas" × C "Corona" (`CLAW_CRYSTALS`): `claw_rage_left-Sheet.png` (14x12: 5 crystal rows above the claw) +
  `claw_rage_glow-Sheet.png` (their tips, drawn in `renderGlow`). All from `tools/ui/make_gloomy_sprites.py --apply
  [--pinzas X]` (montages `pinzas` / `cristales` → `FlappyMonster_pruebas/gloomy/`). The USER then HAND-EDITED
  `body-Sheet.png`, `glow-Sheet.png`, `claw_left-Sheet.png` and `claw_rage_left-Sheet.png` (3.34.0): running `--apply`
  again would overwrite their work — don't, unless they ask (then port their edits into the generator first).
  netPackExtra: phase, frame, face, mark x/y (claw: the aim point), endX, attack kind (1 charge, 2 claw, 3 pounce,
  4 dive), light scale, icon, rage, ang·100, pings {id,x,y,t,max} (protocol v46). Arena
  `tools/levelgen/arenas/jefe_lugubre.json`; real level **gruta_lugubre** "Gruta Lúgubre" / "Gloomy Grotto"
  (`levels_boss.py`, cave theme, dark: no spikes or pits, Gloomies, then the arena, zone from column 88).
  `retheme.py` has NO --help: any unknown flag runs it over EVERY level — pass level names. Harnesses
  `megagloomy_rules` (+ `LOOK=1`: claws, ring, rage, each telegraph in the dark), `boss_sim` / `boss_intro` / `online_boss`
  with `LEVEL=` that arena.

## Terrain blocks, subtiles and physical particles

- Terrain tiles: `solid` (label **Piedra**, grey), `dirt` (**Tierra** 16, brown with
  pebbles), `grass` (**Césped** 17, green; blades drawn ABOVE the cell when its top is
  exposed), `border`. All `joinGroup='ground'`. Materials `dirt`, `grass`.
- **Block joining = ONE rule** (`TileTypes.joinsCell` / `sideExposure` / `half`): big tiles,
  subtiles and boss walls of the same `joinGroup` never draw a border between them. An edge
  is `true` / `false` / `{a, b}` (half edges, when the neighbour cell has subtiles covering
  only half the side; `drawEdges` and grass blades honour halves). Entities that draw as
  blocks expose `e:joinsCell(c, r, group)` and are registered by `BossZones.link` in
  `level.joinOverlay` (boss walls, only while 'solid'). Harness `subtiles` case `union`.
- **Subtiles** (`src/world/SubTiles.lua`): quarter-cell versions of the tiles in
  `SubTiles.KINDS` ({'solid','dirt','grass'}; a new one = one name). JSON
  `"subtiles": [{col,row,sub 1..4,kind[,solid=false]}]` (solid by default; the editor
  only writes `solid:false`). Physics: `Level:getDefAt` returns the quarter's def
  (`SubTiles.def(kind,q)` = the tile def with that quarter as hitbox) in cells without
  collision, so collisionAt/entitySolidAt/landingCross (samples both halves of such
  cells) and everything built on them (player, entities, server, prediction, solver)
  see them. With subtiles `Level:samples(a,b)` gives denser probe points (≤ 24 px; a
  quarter is 32) and the player keeps the MOST restrictive face of all hits.
  `level.subCells` (draw) / `level.subSolid` (physics, nil when none). Editor layer 7
  "Mini bloques": brush/pick/erase per subcell + "Sólido" toggle; non-solid ones show a
  dotted frame in the editor. Thumbnails: 'D' dirt, 'G' grass, 'm' mini blocks.
- **Physical particles** (`phys = true` in `Particles`): collide with the level set by
  `Particles.setLevel(level)` (Adventure/Online states): bounce off walls/ceilings,
  bounce and then REST on floors/platforms (`landingCross`), fall again without
  support, sink slowly in water; born inside a block → no collisions. Debris from a
  surface with a known normal (`opts.nx, ny`: the Mega on walls/ceilings) is born
  outside the block and looks for the material INTO the surface; on an invisible zone
  edge it uses the floor below. Impact kinds
  (block_break, spike_land, gp_land, spike_pop, mega_step/debris/dirt/slam/land) take
  the colours of the block they hit: `TileTypes.debris(def)` = tile `debris` →
  material `debris` → shades of its colour; the surface is probed around the point.
  A broken block's colours come from `Level:previousDef(c, r)` (setTileRaw/breakTile
  remember the old raw). Harness `subtiles`.

## Free Play (single player)

Aventura → SOLO opens `FreePlayState` (state `free_play`): every level in a scrolling
grid of cards (thumbnail, name, size, monsters, boss, water/floods/auto-scroll/zones,
stars/lives/checkpoints, music, online-mode chips). Nothing is saved or unlocked (a
test hub for beta testers until the story map exists). Level cards come from
`src/world/LevelCatalog.lua` — the ONE level-info builder, also used by the server's
lobby catalog (`LevelCatalog.info/load/files/buildPreview`; `RETIRED` = old test files
an installed build still has; `_*` hidden). Loading is incremental (time budget per
frame) and cached between visits; only visible cards are drawn; columns come from the
current `WINDOW_W`. Input: arrows/ENTER/ESC, mouse hover + click, wheel, finger drag
(`love.touchmoved/touchreleased` are now routed to states in logical coords). Levels are
started with `{ level, returnTo = 'free_play' }`: AdventureState game over and
PauseState "exit" go back to `returnTo` (Pause looks at the state under it). Level
thumbnails live in canvases → `love.resize` clears `ModeSelectMenu` previews.
Harness `free_play`.

## Decorations (`src/world/Decorations.lua`, JSON `foliage`)

Render-only (client + editor; the server builds them but never draws). `placement` = 'sub'
(sprite 8 art px wide = 32 px, anchored bottom-centre of the quarter) or 'cell' (16 px wide
= 64, bottom-centre of the cell; taller ones grow upward); hanging ones draw from the TOP of
their cell/quarter (`DecoFx.sheet(..., {hang=true})`). A type file may return a LIST: themed
sets `ice_set` (Hielo y nieve), `cave_set` (Cueva), `water_set` (Acuático), `tropical_set`
(Tropical) + `icicle`, `palmtree` (Tropical), `tulip`/`stretch` (Plantas); palette order
`DecorationTypes.CATEGORIES`. `src/world/decorations/DecoFx.lua` = shared helpers: sprite
strips at ×4, `wave` (row-by-row sine sway, root still), additive `glow`, per-decoration
particles in `d.fx` (`emit/update/draw`, spawned only while seen, `every` timers), `drip`
(forms, falls, splashes on `d.level:landingCross`); bubbles pop out of water. Sprites:
`assets/images/decorations/<theme>/` + `fx/` from `tools/ui/make_decorations.py` (simple
style: 1-px dark outline + 3 tones, no noise; never overwrites; `--force [names]`). Every
sprite gets a 1-px transparent margin (sides + top, or bottom if it hangs) with its outline
closed there, and `edge_check` warns if fill touches the canvas edge (it looked CUT in
game); `DecoFx.strip(path)` without a frame width = the whole image. It also
REDESIGNED the old foliage (tulip, stretch, palmtree parts) in that style from the user's
originals (kept outside the repo); the icicle now uses `decorations/ice/icicle.png` (the user's
original `icespike.png` is kept outside the repo). Showcase arena `tools/levelgen/arenas/decoraciones.json`
(`run.sh editor_open PLAY=...`).

## Sky and backgrounds (`src/fx/Sky.lua`)

Level JSON `"background"` (SURFACE biome, default meadow), `"time"` (day|dusk|night, default day),
`"clouds": false`, `"depth"` (optional DEPTH biome: cave, underwater, abyss, icecave, underground)
and `"surfaceRow"` (row whose top is the surface line; default `Sky.autoSurfaceRow` = 2 rows
above the player start, `Sky.AUTO_ABOVE`); editor: Nivel tab → "Fondo y clima" → "Superficie:
fila" (0 = auto; always visible) or Alt + click on the map with the Nivel tab open (the map shows
the line dashed cyan). Without a depth the line is only used when set manually (auto = the old
look: landscape on the level bottom). With a depth, the whole
background is ONE cross-section moving with the nearest surface layer (the user rejected a
world-locked seam: "abrupt, different speeds, unrelated"): horizontal parallax per layer, but
VERTICAL parallax close to the world (`pv(p) = 0.7 + 0.4p`, so deep down no sky shows). The
landscape rests on a background line B (the line seen at ~78 % of the screen); under B a strip
of the surface's own ground colour (`e.bottom` of its nearest opaque layer) + `sky/blend.png`
dither (scrolls sideways WITH the nearest landscape layer, never screen-fixed) into the depth gradient, the depth's `top` layer hangs from there and its ground layers
rest on the level bottom (scissor below B). Every depth biome also has a `wall` (160x160,
repeats in BOTH directions, slow parallax 0.18) so very deep levels (laberinto_submarino,
torre_viento) always have scenery, and the depth gradient spans the whole level depth. Drawn first in
Adventure/OnlineAdventure states (`Sky.render(level, camX, camY)`; `Background.png` is ONLY
for the Flappy mode now). Pixel-banded gradient per time (cave/underwater have their own,
tinted by the time), sun (day; low + orange at dusk) or moon + twinkling stars (night),
drifting clouds, then the biome's silhouette layers (`Sky.BIOMES`: meadow, coast, mountain,
snow, forest, fortress, cave, underwater) repeated horizontally with parallax; ground layers
rest on the level bottom (tall levels show more sky as you climb), `top` layers hang from the
level top (cave ceiling), `add` = additive (underwater rays); outside a layer, its edge row
colour fills the screen. Dusk/night tint layers and clouds. The EDITOR draws the same sky under the map (`drawCanvas`:
`Sky.render(lv, camX, camY)` with WINDOW_W/H = the visible world area, clipped to the level rect;
Sky clips with `Clip` so it works inside the editor's zoom transform), so surface/depth/row
changes show without playtesting (at zoom ≠ 1 the view is larger than a game screen). Art: `assets/images/sky/` from
`tools/ui/make_sky.py` (simple 2-3 tone silhouettes). New biome = PNGs + one BIOMES entry.

## Biome art: volcano + meadow (`tools/ui/make_biome_art.py`)

Made for the "retheme" stage (every story level must look like ITS island). Style = the game's: parts with a 4-tone
palette (outline = the darkest tone of the object's OWN colour, never black; light from the top-left), 1-px margin;
the user rejected a first version with black outlines and flat colours ("too simple"). `Canvas.part(mask, pal)`.
- Tiles: **Basalto** `basalt` 38 (dark volcanic rock, 2x2 drawing like stone, very few marks) and **Ceniza** `ash` 39
  (ash cap with embers over basalt when its top is in the air, like grass over dirt); materials `basalt` / `ash`
  (debris), sub-tile kinds, thumbnails 'V' / 'H', sand blends, boss-wall `material` options.
- Sky (`tools/ui/make_sky.py`): surface biome **volcano** (own red ash gradient tinted by the time: volcano with a
  glowing crater and lava streams, basalt ridges, charred trees) and depth **magma** (rock with magma veins, hanging
  basalt with glowing tips, `magma_wall`). Gradients 9 / 10.
- Decorations: `volcano_set` (category Volcán): charred_tree, basalt_rock, lava_fall (hangs, lights, embers),
  dead_bush, basalt_pebbles, ash_pile, lava_vent (smoke + embers, light), glow_rock (light), steam_stones (HOT SPRINGS:
  steam puffs; retheme puts them next to water in volcano levels — carrera01's pools are hot springs, same gameplay);
  `meadow_set` (category Pradera): oak_tree, pine_tree, round_bush, fallen_log, flower_patch, tall_grass, sunflower,
  red_mushroom, mossy_rock. Particle sprite `fx/smoke-Sheet.png`. Preview: `FlappyMonster_pruebas/biomas/vista_previa.png`.

## Level themes (`tools/levelgen/retheme.py`)

**Story retheme (by island)**: THEMES now follows `src/story/Worlds.lua` — meadow (temperate: no palms/ferns/hibiscus),
`beach` (sand, playa_rebotes), fortress (tren_fugaz), snow (fabrica_criogenica), cave (nivel01, laberinto_submarino:
background cave, music dark_cave), volcano (carrera01, caldera_roja, lluvia_pinchos — moved to the Volcano world —,
ruta_del_espejo: terrain → ash/basalt, sky volcano, depth magma, boss walls basalt). `--decor --fix --theme` also swaps
decorations of ANOTHER biome (palms in the meadow, corals/shells in snow or fortress water: `NO_SEA`, `SEA_LIFE`,
`EXTRA_OK`) for one of the level's theme.


The levels were built when stone was the only block. `retheme.py` re-dresses them by
THEME (table `THEMES`: meadow, tropical, snow, cave, mine, underwater, fortress) with
ZERO gameplay change (stone/dirt/grass/snow are identical for physics): solid blocks and
the frame's bottom row → surface of the theme where the top is in the air (grass / snow /
dirt / stone), dirt 2-3 rows below, stone deeper; SAND 2 deep under water (sea floor) and on
meadow/tropical shores (water ≤ 3 columns away; shells/starfish/palms on it); snow: small one-row islands → ice (+
`"snow": true`). Then decorations by theme on floors (planks: small ones only), ceilings
and underwater floors, always `layer = 'back'`, never on spikes/entities/start/finish/
vents/boss walls/boss arenas. `--force` re-rolls only its own decorations (the ones with
`layer='back'` of its types; hand-placed ones stay); `--terrain` also re-decides dirt/grass/
snow/sand blocks (overrides hand-placed ones); `--tiles` = terrain only (decorations untouched);
`--deep` = ONLY ground ≥ 4 rows under a water surface → deep stone (any theme but snow; the
'underwater' theme also below 45 % of the height); `--sky` = writes the SKY table's background/
time only into levels that don't set them. The user edits levels by hand afterwards: prefer the
narrow modes (`--deep`, `--sky`, `--tiles`) over `--force`/`--terrain` on levels they touched. Seeded per level (stable). Writes the
editor's JSON format. Run it again after `build.py --only x`. New levels: add a THEMES row.

**Decorations go on THEIR material** (user's rule: no plants, palms or flowers growing out of rock, snow, sand or a
girder). `retheme.py` table `REQ` = the tile that must support each decoration type (the one below; hanging ones, the one
above): plants → grass/dirt (tropical ones also sand), snow things → snow (piles also on planks), rock formations →
stone/deep stone/border (+ dirt), mushrooms also on wood, shells/starfish → sand, aquatic ones only in water; nothing
hangs from the top FRAME under an open sky (only in closed themes `CLOSED` / levels in `ROOFED`). The placer filters by
it, and `retheme.py --decor [--fix] [levels]` audits EVERY decoration of every level (auto or hand-placed): `--fix`
swaps a misplaced one for something of the theme that fits there, or removes it (251 + 113 fixed in the old levels:
palm trees on stone in fortaleza_malvada, tulips on girders, icicles hanging from the sky...). Themes added: `forest`,
`volcano`.

**Batch 2** (`tools/levelgen/levels_batch2.py`, 15 levels, 3.35.0): 10 race + hunt (pradera_explosiva, bosque_interruptores,
playa_rebotes, arrecife_globo, cantera_dinamita, cumbres_escarcha, fabrica_criogenica, templo_del_eco (dark),
jungla_colgante, caldera_roja; ~140-170 x 28) and 5 KOTH arenas 92 x 28 (cantera_real, lago_de_cristal,
ciudadela_alterna, cala_de_los_muelles, cripta_del_silencio (dark)); `modes` also list `hide` (the planned Hide and Seek
mode: unknown ids are ignored today). Built from PIECES laid with a cursor (`c = L.piece(c)`: can't overlap; `put()`
asserts on collisions; `check()` warns about pits inside cellars and patrols without floor): bomb_vault / bomb_wall
(breakable walls a bomb opens; bombs respawn), switch_bridge / switch_door (ON/OFF, with explicit `blockLinks`), lake
(thin ice) / dive_pool (puffers; STEPS on both sides: under water you can't swim up, one jump = 1 tile), freezer_hall,
ice_run, lava_hops, tramp_cliff / tramp_gap, crouch_tunnel, spikefall_hall, mortar_nest, cellar (basement with stair /
breakable-floor entrances), stairs + `upper()`. Built things use `STRUCT` = border rock (retheme doesn't turn it into
grass). RULES learnt: (1) the mandatory route never depends on something that can be lost — only Activators, head
bumps and ground pounds; bombs guard shortcuts and loot. (2) NO continuous upper walkway (v1 had one: the user saw you
could clear the level in a straight line on top) — `upper()` makes SHORT separate sections, one per stairway, with
≥ 9-tile voids between them. (3) Solver flow: `OPEN=1 python3 tools/levelgen/build.py --only x --out assets/levels/_open`
writes the SOLVED variant (breakables removed, ON/OFF as after hitting the Activator) for `level_solve` (which can't
break blocks or use Activators); then build + `retheme.py x` + `level_check`. `level_solve EXPLORE=1` = every enemy and
pickup reachable. Harness `level_shots` renders a whole level to a PNG to review its look.

## Level JSON

`{name,width,height,playerStart:[c,r],tiles:[[raw...]],entities:[...],
foliage:[...],vents:[...]}` (+ `bossZones:[...]`, see below). Editor writes
one tile row per line and only non-default props.

## Editor

Layers (1-7): tiles, water, spikes, entities, deco, special, mini (subtiles) (`LAYERS`/`TOOLS`
at the top of Editor.lua carry their help texts). Left panel: layer, tool
(+ hint card), palette (search + collapsible categories). Right panel has tabs
Selección / Nivel / Avisos. EVERYTHING editable is drawn by
`drawPropFields(schema, obj, …)` from a prop schema: entities, decorations,
boss zones (`zoneSchema`), vents (`VENT_SCHEMA`), auto-scroll
(`AUTOSCROLL_SCHEMA`); each `group` is a collapsible section (`ui.section`),
min/max may be functions(owner), optional `onChange`. New level objects =
a schema + an inspector function in `drawSelectionTab`, not bespoke widgets.
Catalog metadata that drives the editor (no editor code needed):
- entities: `category` (ordered by `EntityTypes.CATEGORIES`: Enemigos, Jefes,
  Trampas, Mecanismos, Objetos, Directores), `description` (palette tooltip +
  inspector), `hide = 'all'` (no common props), `variant = {group, label,
  groupLabel, prop}` (several defs shown as ONE palette card + selector; X
  cycles; inspector enum changes `e.type`) — used by the 4 trampolines.
  Prop groups: the type's own groups first, then `EntityTypes.COMMON_GROUPS`.
- tiles: `TileTypes.CATEGORIES` order. UI text is Spanish WITH accents.
`ui.lua` widgets: button (opts.hint = key), toggle, number, enum (segmented
when it fits), textField (placeholder), section, tabs, hint, caption, label
(fits/ellipsizes). F1 = shortcuts overlay. `E.instances` renders entities as
in-game. `Model:validate()` → warnings (Avisos tab, clickable). F5 playtests
via `AdventureState` with `editor_playtest.json` (SP keeps reserve entities in
`self.enemies`: it only drops non-alive ones without `summonOf`).
Ctrl+O "Abrir nivel" = scrollable list (wheel / arrows + Enter) with file + level
name; hides `_*` files and `editor_playtest.json`. Test arenas live in
`tools/levelgen/arenas/` (not listed).

## Boss system (generic)

Files: `src/world/BossZones.lua` (zones + fight controller),
`src/world/entities/Boss.lua` (base class), `src/world/entities/types/mirror.lua`
(MirrorEnemy), `src/ui/BossHud.lua` (segmented HP bars, banners).

- **Zone** (`level.bossZones`, JSON `bossZones:[{id,col,row,w,h,music}]`):
  states `idle → waiting → fight → cleared`. While not cleared, any player whose
  center is inside is walled in (`Level:arenaAt` → clamp in
  `PlayerAdventure:moveAndCollide`; also clamps the boss body). The fight starts
  when ALL `level.players` are inside; bosses get `startFight(nPlayers)`;
  respawn points move into the zone. Camera: `BossZones.cameraTarget` via
  `cameraZone` — during a fight it also stays fixed for players BELOW the zone
  (fell through a broken floor: walls no longer hold them, camera must not follow).
  **Boss intro**: if a boss has `hasIntro()`, the zone goes `waiting → intro → fight`
  (state code 5, appended: codes are network ids). During 'intro' players inside are
  FROZEN (`Level:frozenAt` → `PlayerAdventure:update` feeds an all-false Input and
  zeroes vx; gravity still acts; identical SP/server/prediction since the zone state
  is in snapshots) and `BossZones.music` returns `BossZones.SILENCE` (states call
  `Sound.stopMusic()`). The boss runs `startIntro(level, players, z)` and the fight
  starts when every boss says `introDone()`. Event `boss_intro`. Harness `boss_intro`
  (any boss: `LEVEL=`). GENERIC intro in `Boss.lua`: a boss with `introLength` (s or
  function) gets states 'intro' → 'ready' (not active, not solid) and hooks
  `onIntroStart(level, players)`, `updateIntro(dt, level, t)`, optional `introFocus()`;
  everything drawn must derive from state + deadTimer + x,y (net). During 'intro' the
  camera centres on the boss (`cameraTarget` → `introFocus()` or its editor spot) and
  `BossHud.drawCinema(level)` draws letterbox bars (under the HUD) with the boss name
  typed in; the WHOLE HUD (score/time, lives, HP bars, pause, ping, mode panel, touch
  controls) fades out and back with the bars (`BossHud.fadeHud(fn)` renders a HUD piece via a
  canvas at `BossHud.hudAlpha()`; `TouchControls.draw(nil, nil, fade)`). MiniBoss1: descends from above the view braking + spike threat (3.4 s;
  without a zone the old 'intro_fight' descent). Mirror: jumps up from below the screen
  through the floor (`introPlan()` = pure function of zone + home, used by client for the
  laugh timing), lands, laughs (`laughTime()`). The Mega keeps its own states.
  Music: zone field `music` = any catalog track with `"boss": true` (options built
  from `Music.bossList` + 'level'; default 'boss'; editor: zone inspector). Prefer
  OGG for music (the updater ships it to every player).
  `BossZones.music(level)` → `Sound.setLevelMusic(track)` (so every
  `Sound.playMusic('level')` call plays the boss track during the fight).
- **Controller** (`BossZones.newController(level, entities)`) runs in
  AdventureState and on the server; returns events `boss_start`/`boss_clear`.
  Calls `boss:onPlayerDeath(pa)` when a participant dies inside.
- **Net**: snapshot `bz = {{stateCode, arrived, needed}, ...}` →
  `BossZones.netApply` on the client (drives arena prediction, camera, HUD).
  Boss entity extras: `netPack` = {hp, hpMax, inv*100, ...netPackExtra}.
  Sound events now carry `pitch`. Remote players' hurt flash = `PF_HURT` flag.
  Damage a boss does to a player is attributed with `Boss.withPlayer(pa, fn)`
  (server sets `Boss.asPlayer`), and the victim's client plays 'dies' via
  `Predictor.reconcile(...).hpDrop`.
- **Stun rule** (anti ground-pound spam): a ground pound on top of a stunnable
  boss (mirror) deals 2, leaves it KO ('ko') AND makes it invulnerable at once
  for `STUN_INV` (3 s > the 1.4 s KO): no follow-up hit while KO. If it's stunned
  by something else (knockback from a nearby GP), `isStunned()` takes ONE hit,
  then `endStun()` + `STUN_INV`. That "ghost" invulnerability blinks
  (`ghostAlpha`), keeps attacking, can't be stunned, and bosses/players pass
  through each other. Invulnerable players also pass through bosses (but not
  `solidFull` objects) and bosses can't hit them.
- **Boss base**: HP = props.hp + props.hpPerPlayer*(n-1); stomp = 1 dmg,
  ground pound on top = 2 dmg (`'pound'` result → `e:pound(pa)`); i-frames
  `INV_TIME` (red flash, stomps only `'bounce'`); body is solid sideways. Death: `dying_hold` (blasts, alternating
  'bossExplode'/'bossHurt') → `dying_fall` → `dead` (alive=false → zone cleared).
  `e:interact(pa)` must be side-effect free (client uses it to predict bounces).
- **Adding a boss**: FOLLOW `docs/jefes/COMO_CREAR_UN_JEFE.md` (step-by-step guide + checklist: design,
  art, sounds, particles, entity skeleton, minions, net, lang, arena, real level, harnesses, docs, release;
  with the pitfalls already paid for). Short version: `types/<name>.lua` with `Entity.extend(Boss, …)`, def fields
  `category='Jefes'`, `boss={title=…}`, `hide=Boss.HIDE`,
  `props=Boss.props({hp=…, hpPerPlayer=…}, {extra props})`; implement
  `initBoss/updateBoss/render` (+ hooks listed at top of Boss.lua); add the name
  to `TYPES` in `src/world/Entities.lua`. Place it inside a zone in the editor.
- **Immune bounce**: landing on a boss that can't be hurt returns
  `'bounce', vy, dirX` → `pa:bounce(vy, dirX)` pushes the player sideways
  (no riding bosses); predicted on the client via `recordBounce(vy, dir)`.
- **MiniBoss1** (`types/miniboss1.lua`, "Nave Malvada"): ship + Evil Monster as
  two independent visuals (ship flips every 1 s; monster cycles Idle/Idle1/
  Idle2, hurt face on hit). States dormant (hidden, not solid) → intro (drops
  in from above the zone view, `miniAppear`) → patrol (waypoints: `points`
  prop, flown in straight 2D lines — they set the height too, minus `lift`)
  → prep (spikes out) → slam (falls until any tile, never below the
  zone floor line `zone.y1`) → stuck (only vulnerable here + first 0.6 s of
  rise) → rise (back to the height it dived from). Breaks `breakTiles` blocks per slam (default 1). Death:
  dying_hold → dying_eject (monster thrown out in an arc, dead anim + X eyes)
  → dying_boom (ship big explosion + screen shake) → dead. Pixel scale 5;
  flies `lift` px (default 32) above its placement cell; 1 full-size spike per
  broken block + 1. The hurt face has no eyes: X eyes are drawn on it (hit +
  death hold) and on the thrown dead sprites, at positions measured per sprite.
- **MegaCrabby** (`types/megacrabby.lua`, sprites `assets/images/bosses/megacrabby/`, sounds
  `bosses/megacrabby/` from `tools/sounds/megacrabby.py`): Crabby ×2.5 (MS=10), always spiked,
  two claws (`claw_left-Sheet.png` 2×7x6 at 0.7 of the body scale, right = flipped,
  drawn IN FRONT of the body beside the legs; `CLAW_*` constants) that snap at random.
  Secondary animation is render-only and derived from state + deadTimer (same in SP and
  online): squash & stretch per step/landing/windup/charge/drop, breathing, claw sway
  per animation (`Mega:pose2d`), struggle shake when stuck, continuous particles
  (`renderFx`: mega_step / mega_trail / mega_debris / mega_dirt); one-shot fx from the
  sim: mega_slam, mega_land, mega_poof. States intro → chase (floor, nearest player, contact/spike = 1 HP + knockback via
  `hitPlayers`; claw boxes too; after a hit it backs off: recover) → windup → charge →
  recover (contact near a wall: `pushAway` bounces the player OVER the crab to the
  other side; `graceT` after every contact hit: no chained stuns); `pounceEvery`:
  wallclimb (the wall AWAY from the target) → wallaim (marker starts at the target and
  chases it at `MARKER_SPEED`, fixed the last `AIM_LOCK_WALL` s) → pounce (ballistic leap,
  not head-first, only the crush counts: `pounceDamage` 2 HP) → recover; `summonEvery`:
  summon (only if it can: free reserve and below `summonMax`; `SUMMON_WARN` s of yellow
  floor markers at `summonSpot(i)`, count in netPack); every `ceilingEvery` s: climb (Crawler; the
  zone edges count as walls/ceiling via `crawlSolidAt`) → ceiling (above target) → aim
  (FOLLOWS the target along the ceiling with the marker below for `aimTime`, then
  `AIM_LOCK_CEIL` s still and shaking) → drop (spike hazard = KILL) → stuck (ONLY vulnerable state,
  one hit per drop: `hitDrop`; stomp 1 / GP 2) → getup (during its inv time; landing =
  `landShock`: knockback+stun around, 1 HP only to whoever is really UNDER it; then
  `recover` 1 s + `graceT` 1.4 s without contact damage). `rest`: every `restEvery` s
  of chase (5) it stops for ~`restTime` (1.8, ×0.8-1.3) breathing slowly with drooping
  claws (attack timers don't run meanwhile); still spiky on contact. Claws `CLAW_K` 0.85
  (anchored at the joint `CLAW_X/CLAW_Y`: bigger claws grow outward/up from the same
  point). Steps: deeper `step.wav` + GAIN 0.56 (≈ -11.5 dBFS). Spike boxes (head spike,
  drop kill) = tile-spike proportions: base rectangle 60% w × 40% h. Rage below
  `rageAt` (default 0.6): render-only anger symbols pop around its head (`renderAnger`:
  `anger_vein/steam/scribble.png` strips, scale 3) plus, in render (`self._angry`), ONLY a
  reddish pulse and a SLIGHT 1-px tremble — claws, snaps and bounce stay normal (the user
  found more too much; idle = idle frame, never walking feet when still). Roar = giant-crab
  MONSTER (`tools/sounds/megacrabby.py roar`): distorted 34-52 Hz throat growl with jaw
  chatter (AM ~23 Hz) through mouth formants (310/680 Hz) + sub, crescendo, plus the crab
  layer (low chitin stridulation, froth, hiss) and claw clacks; fx `mega_roar` (warped
  semi-transparent shock rings + IRREGULAR sharp zigzag shockwave lines: 3-5 long segments,
  uneven kinks, tapering width, optional side crack; bone/sand colours with a dark brown
  edge — the user rejected "electric" yellow/blue) + `shake_roar` (soft, long). Windup = legs scuttling +
  accelerating claw snaps; claw closes on the sound's snaps (`WINDUP_SNAPS`, same in the
  .py). Summon spots: `pickSummonSpots` (never overlapping, outside its body; netPack 9). Death (own states): dying_kick → dying_shrink (deflates to normal size) →
  dying_flee (small crab without claws runs straight to the nearest side through
  everything, silent steps, fades) → dead. `releasesZone()` (Boss hook, used by
  BossZones) lets the zone clear when the flee starts, so boss walls open first.
  Intro: hidden + not solid while `dormant`; `fall_in` (0.7 s silence, 'megaFall',
  falls from above the zone through anything outside it, lands on the zone floor at
  `introSpot` = its editor x if ≥ `INTRO_SAFE` tiles from every player, else the floor
  point farthest from them; shadow grows on the floor) → `land_in` (slam fx, no
  damage) → `roar_in` ('megaRoar' + fx `mega_roar` rings + shakes, claws up) → `ready`
  → fight starts straight in 'chase'. Rests are EMOTES: `restKind` (netPack field 8)
  cycles `REST_KINDS` {1 roar, 2 claw punches + clacks, 1, 3 spike flex}; drawn in
  `pose2d` (5th return = spike scale for `drawLocal`).
  Minions: the type def's `summons(placement)` makes Level.fromData append RESERVE
  placements (crabby / crabbytramp, wallWalk + dropOnSight) after the JSON ones, so
  server and clients share indices; `Entities.create` → `e:makeReserve(key)` (not alive,
  state 'reserve', not sent: netAtRest). The boss activates them (`resetToHome` +
  'spawning', `leashZone` = its zone via `Crabby:crawlSolidAt`); they die with it. Minions have
  NO patrol route (`makeReserve` sets infinite bounds): they used to inherit the default
  Crabby route around the boss's cell and a GP knockback snapped them to its edge (a
  "teleport", sometimes onto the player). Route limits in `Entity:moveAndCollide` never pull
  an entity that is already outside back in one step (they only stop it moving further out).
  Harness `boss_intro` case `gp_subditos`. `Boss.hurtSound` per boss.
  Minions behave exactly like normal wall-walking ceiling Crabbies (harness
  `crawler_drop SUMMON=1`). Test arena: `tools/levelgen/arenas/jefe_cangrejo.json`.
- **Snowball Boss** (`types/snowboss.lua`, "Gran Bola de Nieve", `boss.snowboss`; REBUILT from zero in 3.22.0
  — the old gate/bombs/burial/avalanche version was "overcomplicated"; sprites `assets/images/bosses/snowboss/`
  from `tools/ui/make_snowboss_sprites.py` (the user's ball drawing restyled; that original lives ONLY outside the repo, `<originals>/assets/images/snowball/ball-orig.png`);
  sounds `bosses/snowboss/` from `tools/sounds/snowboss.py`; music `winter_nes`). renderFront. NEVER hurt
  directly: only VULNERABLE states take stomp 1 / GP 2 (one hit per opening, then 'recover'):
  'dizzy' (rolling into a wall/step at ≥ `CRASH_SPD` after ≥ `CRASH_RUN` tiles since the last crash, on its
  LAST crash: bounces per phase `BOUNCES` {0,1,2}; or a falling CEILING ICICLE hits it = `bonk`), 'soaked'
  (falls into water through broken thin ice: it is HEAVY — `LAND_CRACK` 4, any landing on thin ice breaks it,
  rolling wears it `ROLL_WEAR`, and when one cell under it breaks its whole footprint goes, so it reliably falls
  in; entering the water opens the hole to its width; `soakTime` s drenched + dripping, then a big heavy jump
  out (`ESCAPE_WIND`, `ESCAPE_UP`) to the nearest DRY spot — dry = no thin ice/water below AND no water above:
  the pool bottom used to count as dry and it "escaped" back into the pool forever; the thin ice does NOT
  regrow while it is in the water / escaping; once IT fell in (`fellIn`), the moment it is OUT of the water every broken
  cell comes back AT ONCE (the user: re-dropping it into the same hole was an exploit), except cells under it while it
  jumps out (they return as soon as it clears them or lands — never closes its exit, never lands on fresh ice); other
  breaks keep the `lakeRegrow` timer; only on ENTERING water: `wasWet`) and 'frozen' (IN THE WATER — soaked, or winding
  up / jumping out while still in it — + a Freezer stream: `FROZEN_T` 4.5 s, GP 3, then thaw; a Freezer on a DRY
  boss = short daze `DAZE_T`; the user found "stunned + water + beam" too hard). After any Freezer it is FROST-PROOF
  `frostProof` s (blue tint; `frostT` in netPack). Water itself never freezes it (user's rule).
  THREE PHASES THAT SHRINK IT (`SC` = {10, 8, 6}; 'phase_up' roars, sheds snow `snow_shed` and shrinks;
  `bossPhase()` → zone phase, see Phase system): cycles `CYCLE` — 1: shoot, roll, hop (low: never reaches the
  platforms), roll · 2: LEAP (ballistic jump to the `spots` surface nearest the target — platforms included;
  during the jump `passY` = the mark: it passes through every platform/block on the way and only lands on a
  top at the mark's height or lower, so it always reaches the marked spot; marker `landX/landY` during 'leap_wind'),
  shoot, leap, roll · 3: SLAM (rises `SLAM_H`, reaches the target's vertical at the apex, falls; cracks thin
  ice 4 = breaks a pocket → soaked; snow waves only on the arena floor), roll (2 bounces), leap, slam, shoot(5),
  leap. PACE per phase (normal / middle / aggressive; user: much more agile, the old phase-3 pace is now the
  middle one): `IDLE_T` {0.5, 0.4, 0.22}, `REST_T`, `STREAK` {2, 2, 3} attacks per streak, `SHOTS` {4, 6, 8}
  balls per volley, `WINDUP_T`, `SHOOT_WIND/GAP`, `LEAP_WIND/LAND`, `LAND_T`, `RECOVER_T`, `SLAM_HOLD/LAND`,
  `ROLL_SPD` all per phase (render uses the phase from netPack). Snowballs PASS THROUGH platforms (one-way
  tiles): only solid tiles (floor, ledges, walls) or leaving the zone stop them. It does NOT laugh at player
  deaths (only in its intro; laughing at deaths is the Mirror's thing). Every landing (`landed`) cracks thin ice, crushes players
  under it and SHAKES the ceiling icicles within `ICE_R` 2.5 tiles: prop `icicles` (points; they hang from the
  TOP of their cell; appear growing in phase 2 and ONLY exist in phase 2: reaching phase 3 shatters them
  (`meltIcicles`; a falling one finishes its fall) and they never regrow; ready → shake 0.6 s → fall → `icicleRegrow` s → grow). Icicles
  over a platform land on it (platforms are shelter). LAKE: thin ice cells of the zone regrow `lakeRegrow` s
  after breaking (`regrowLake`, never into an occupied cell); all at death. Hits on players by the boss itself
  (`hitWithShots`, `strike(pa, hit, dir)` = {HP, vx, vy, ctrlLock, stun}): ball 1 HP + strong push, icicle
  2 HP, snow wave 1 HP + push, `slamWave` 1 HP + VERY strong push + stun within `SLAM_R`; rolling/landing
  contact 1 HP + knockback/squash. Rolling into an ON/OFF Activator toggles it. Roll end is deterministic
  (time budget `ROLL_MAX_T` per phase, then 'slide'; `MAX_CRASHES`). Intro (generic `introLength` 4.4: a small
  ball bounces in, grows, lands, laughs, spits at the camera → screen splat). Death: dying_crack → dying_burst
  → dying_flee (releasesZone). netPackExtra: phase, scale, shock wave, dir, frozenFor, frostT, dizzyFor,
  landX/Y, balls {id,x,y}, icicles {state,y,t} by INDEX (same list on both sides: `icicleList`). Protocol v38.
  ARENA "Pista de hielo" (jefe_nieve.json from `tools/levelgen/arenas/make_jefe_nieve.py`; `--lago` writes it
  into lago_helado from column 72, widening the level to 113): zone 24×10, ice floor, two thin-ice POCKETS over
  water out in the open, steps at both walls, one-way platforms (sides row 10, middle row 8, top row 6), five
  icicles over the platforms, and in PHASE 3 ONLY: two floor Activadores (phase blocks hidden as ice) and two
  Freezers (`phase` 3) that drop from the ceiling above the pockets, each pocket's Activador fires its
  Freezer (ids 11/12). Harnesses: `snowboss_rules` (every rule, real arena cases), `boss_sim LEVEL=
  tools/levelgen/arenas/jefe_nieve.json` (plays it as intended: bait under icicles, slam onto a pocket,
  freeze it soaked), `online_boss LEVEL=tools/tests/online_boss/nieve_fases.json` (3 HP: the client sees
  scales 10/8/6, zone phase 3, icicles, Activadores and Freezers only in phase 3), `snowboss_look`
  (`snow_arena.png` per phase), `boss_intro`.
- **Rey Gummy** (`types/megagummy.lua`, "Rey Gummy", `boss.megagummy` = REY GUMMY / GUMMY KING): the Gummy's
  16x16 sprite at scale 10 (`MS`) with brows + a gold crown (crown = separate `crown.png` on the same grid, drawn
  over the body so it can fly off). Art `assets/images/bosses/megagummy/` from `tools/ui/make_gummy_variants.py
  --apply-mega` (body-Sheet 8 frames: idle, walk1/2, jump (legs tucked), dazed, hurt, laugh, shout; wave, stars,
  target marker, shadow); sounds `bosses/megagummy/` from `tools/sounds/megagummy.py` (ids `king*`); particles
  king_splat / king_wave / king_sparkle / king_confetti(_big). Physics REUSED from the Snowball Boss
  (`Snow.move/physics/friction/jumpTo/target/zoneBounds/groundBelow/strike`). Chases in small hops (contact 1 HP +
  push, `GRACE`); solid sideways; on top = immune bounce. (1) BELLY-FLOP: 'flop_wind' (marker `landX/landY` follows
  the target, locked the last `FLOP_LOCK` s) → 'flop_air' (`jumpTo` + `passY`: lands on the marked surface, platforms
  included; drawn rotated 90° = belly down while falling) → crush 2 HP + squash, two jelly WAVES along the surface
  (34 px tall: jump them; 1 HP + push; die at walls / zone edge / no floor) → 'dazed' (stars; the ONLY vulnerable
  body state: stomp 1 / GP 2, one hit) → 'recover'. Phase 2 chains `FLOP_CHAIN` 2 ('flop_land' between). (2) ROYAL
  GUARD: phase 2 (`phase2` = fraction of the BODY hp) starts with 'phase_up' (fanfare) and then 'summon' every
  `guardEvery` s: reserve Gummies (`def.summons`: normal / helmet / flyer cycling, pool `guardPool`, max `guardMax`)
  enter from ANY valid place (the user found "always from the sides" too predictable), by kind (`guardSpot`):
  1 FLOOR (pops out of any standable cell, platforms too), 2 SIDE (next to a zone wall, floor or platform), 3 SKY
  (PARACHUTE from under the ceiling: Gummy state 'para', `Gummy:startParachute`, falls at `PARA_SPEED` onto the first
  surface under its WHOLE box, still a normal Gummy on contact/stomp; `gummy/parachute.png`), 4 AIR (flyers, upper
  half; then FREE FLIGHT over the zone, `e.flyArea`). Walkers rotate floor → sky → side. Every entry is chosen when the
  call STARTS and MARKED until the guard is out (the parachutist's until it lands): `self.marks` {x,y,kind} in
  netPackExtra, drawn with the target sprite; a spot is valid only ≥ `GUARD_FAR` 2.5 tiles from every player, clear of
  the boss, other marks and live guards (`spotFree`); fallback = a side. Bounded to the zone; they vanish when it dies.
  It does NOT laugh when a player dies (only in its intro; that is the Mirror's thing). (3) SPLIT: hp = body + `splitCount` ×
  `partHp`; the hit that reaches that budget is CLAMPED (`MG:damage`) and starts 'split' (crown flies to `crownX/Y`)
  → 'parts': medium Gummies (scale 6, `Part` objects with the Snow physics) that hop at players; contact 1 HP; stomp 1 /
  GP 2 per part (`interact` notes `_hitPart`, side-effect-free otherwise); hp bar = sum of parts. Last part →
  'dying_pop' (big confetti, the crown hops and fades; `releasesZone`) → dead. netPackExtra: phase, landX/Y, splitX/Y,
  crownX/Y, waves {id,x,y,dir,t}, parts {x,y,hp,inv,st,facing}, marks {x,y,kind}. Arena `tools/levelgen/arenas/jefe_gummy.json` (from
  `make_jefe_gummy.py`: flat throne hall, side platforms row 10 + middle row 7, music `boss_nes`); real level
  **reino_gummy** "Reino Gummy" / "Gummy Kingdom" (`levels_boss.py`, meadow theme; every Gummy kind on the way).
  Harnesses: `megagummy_rules` (every rule), `boss_sim` / `boss_intro` / `online_boss` / `boss_frames` with
  `LEVEL=tools/levelgen/arenas/jefe_gummy.json`. Protocol v41 (v42: guard entries + marks).
- **Phase system** (generic, any boss): `Boss:bossPhase()` (default 1) → the controller keeps
  `z.phase` = the highest of its bosses (4th field of the `bz` snapshot) and calls `PhaseBlocks.update`.
  **Phase blocks** (`src/world/PhaseBlocks.lua`, entity `phaseblock` "Bloques de fase", Mecanismos: rect
  `corner`, props `phase`, `zone`, `hiddenAs` = empty/ice/snow/stone/...): at load (SP, server AND client, not
  in the editor: `lvl._editor` from `EditorModel:buildLevel`) the cells are swapped for `hiddenAs`; when the zone
  reaches the phase, SP/server restore them ('set' tile events, hop + 'spawn' fx; an Activador also shows its
  spark trail; occupied cells wait). Any entity can do the same with a `phase` prop: the **Freezer** (`phase`,
  `zone`) is hidden, not solid and doesn't fire until then, then drops from the ceiling on its chains
  (`DESCEND_T` 1.1 s, sound `cryoDrop`, render clipped below the ceiling). Editor: everything shows as placed.
- **Boss walls** (`types/bosswall.lua`, entity "Bloque de jefe", Mecanismos): rect of
  normal-looking blocks (cell = top-left, `corner` = bottom-right, `zone` id, 0 =
  nearest), hidden+passable → appearing (when its zone is in 'fight'; waits until no
  player is inside) → solid (`solidFull` body: blocks players/entities, climbable) →
  vanishing (zone no longer fighting) → hidden. State sent in snapshots (hidden =
  netAtRest). `BossZones.link` gives entities with `wantsLevel` the level (edges drawn
  like real blocks). Prop `material` (Piedra/Tierra/Césped/Arena/Nieve, default stone): drawn
  with that tile's real draw (grass cap, sand transitions), so walls can match the arena. Protocol v19.
- Boss-zone respawns: dying in a zone in 'fight' respawns at `BossZones.safeSpawn(level,
  z)` (via `respawnPoint`, SP + server): the best-scored standable cell of the zone
  (`Level:isStandable`) — far from the boss (its `markerX` while aiming; capped at 7
  tiles), no other enemy within 2.5 tiles, head out of water, below a flood's max
  level penalised, never inside a solid body (boss walls). Fallback: old spawn if it
  still has ground, else `Level:findGround`. Frozen players (boss intro) are
  invulnerable (`isInvulnerable` = invT or `pa.frozen`, no blink).
- **MirrorEnemy**: owns a real `PlayerAdventure` body (`self.body`) and feeds it
  the delayed inputs of its target through a stub `Input` (and a `Sound` proxy
  that lowers pitch). Players record their raw inputs every step
  (`pa.inMoveX, inCrouch, inJumpN, inCrouchN` in `PlayerAdventure:update`).
  It records ALL players, so switching target (nearest, with hysteresis) is
  seamless. `speedMult/jumpMult` on the body make it a bit faster/higher.
  Rendered with an invert-colors shader; laugh = Body_Arms* + Head_* + JoyEyes. It laughs at
  EVERY player death (`onPlayerDeath`: now if copying/landed/perched, else `laughPending`
  → as soon as it's on the ground). Its own attacks never daze it: 'recover' is a short
  landing pause without stars; only a PLAYER's ground pound stuns it ('ko').
  ARENA ATTACKS (rework, in progress with the user): every `attackEvery` s of copying
  (phase-scaled) it shatters ('warp_out', fx `mirror_shards`, sound mirrorWarp) and either
  appears in a floating mirror portal above the target ('portal': follows, locks the last
  `PORTAL_LOCK` s, floor marker `markX/markY` in netPack) and ground-pounds down ('dive';
  platforms stop it = shelter), or appears standing on an arena platform ('perch';
  `arenaPlatforms` = runs ≥2 cells with 2 free above, ≥2 above the zone floor) and leaps
  ballistically (height capped under the zone ceiling) to GP at the apex over the target
  ('leap' → 'dive'). Then 'recover' (dazed, stompable; a hit ends the chain). Its GP
  landing on a player = 2 HP (`GP_DAMAGE`, also the copied GP). Phases (`PHASES`: HP ≤
  66 % / 33 %): attacks more often, chains 2 / 3, copy delay ×0.85 / ×0.7. Crouch in
  perch/recover is VISUAL only (a real crouch drops through platform_drop). Sounds
  `tools/sounds/mirror.py` (warp, appear, portal). Harness: `boss_sim LEVEL=ruta_del_espejo`
  (attacks, GP = 2, leap lands on its mark, chains), `online_boss LEVEL=
  tools/tests/online_boss/espejo.json` (start next to the arena).
  **Broken glass event** (`types/bossglass.lua`, entity "Cristal roto de jefe", Mecanismos;
  rect like bosswall over the AIR row above the arena floor, shards stand on its bottom
  edge): idle → warn (cracks + red pulse, glassWarn) → active (shards, glassRise) → retract;
  only while its zone fights; fires every `every` s (first at `first`) and once per boss HP
  threshold `phase1/phase2` (0.66/0.33). Touching active glass = `interact` → `'launch', 0,
  -launchSpeed, 2` (all jumps recharged; `pa:launch(vx, vy, jumps)`, predicted via
  `Predictor:recordLaunch(vx, vy, jumps)`, client sound `er.launchSound`) + `onLaunch` =
  1 HP unless invulnerable. `unsafeAt(x, y)` → `BossZones.safeSpawn` never respawns there
  while dangerous. Mirror: while `glassDanger` it stops copying (`toPlatforms`: perch in
  place or warp to a platform) and chains platform→platform leaps (`platformTargetX`);
  touching the glass → `glassEscape` (1 HP + leap to the nearest reachable platform, GP
  onto it); back to copying when the event ends. Placed in ruta_del_espejo. Harness:
  `boss_sim LEVEL=ruta_del_espejo` (cristal / arriba / escapa / vuelve).
- Levels with bosses are Race-only (`hunt.requires` rejects `info.bosses > 0`).

Player HP: 3 (`pa.hp/hpMax`), `pa:hurt(n)` = n dmg + invulnerability + red flash; 0 → die.
Respawn grants `SPAWN_INV` (2.5 s) of the same invulnerability (`invT`, see Player).
`die()` returns false when it was blocked. `invT` is own-state index 27 and others see
it via `PF_INVULN` (protocol v21: one system for respawn and hits).
Solid bodies: `level.solidBodies` (set each step from `Entities.solidBodies`,
i.e. entities with `isSolidBody()`, e.g. active bosses) block players sideways
in `moveAndCollide` (contact by movement direction, gentle separation if they
already overlap). A body can use `solidAgainst(level)` instead (the mirror's
body collides with `level.players`). The arena wall is looked up from the
position BEFORE moving, so no push can carry anything out of a boss zone.
Online camera freezes while the local player is dying (same as single player).

## Sound attenuation (world sounds)

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

## Auto-scroll levels (`src/world/AutoScroll.lua`)

Level JSON `autoScroll = {startCol, endCol(0=end), speed, width(tiles), margin,
countdown}`; editor: right panel → Nivel → "Camara automatica". States
`wait → countdown → run → stop` (all players inside the start window to begin;
first finish or endCol stops it). Walls through `Level:arenaAt` (combined with
boss zones): wait = both sides, run = right side only; behind `x - margin`
→ forced death (`die(nil,true)`, attributed via `PlayerAdventure.asOwner`).
Respawn: `AutoScroll.respawnPoint(level)` (lowest safe ground near the window
centre) — set `pa.spawnX/Y` right before `pa:respawn()` (SP + server).
Camera X = window centre ONLY (never the player: on screens narrower than the
window it is cropped equally both sides; no lerp), keeps moving while you die. Net: snapshot `sc`,
client extrapolates with `AutoScroll.clientUpdate`. Race-only (hunt rejects
`info.autoScroll`). Keep such levels ≤ 11 rows so the whole height is visible.

## Floods (`src/world/Floods.lua`, entity `flood`)

Editor: entity "Inundacion" (Trampas); its cell = top-left, prop `corner`
(`point` handle, moves with the entity) = bottom-right. Props: startLevel/maxLevel
(tiles above the rect bottom), startDelay, riseSpeed/riseStep/risePause,
holdTime, fallSpeed/fallStep/fallPause, lowTime. `Level.fromData` builds
`level.floods` from those placements; the entity itself does nothing in game
(never sent: `netAtRest`). The water level is a PURE function of
`level.floodTime` (`Floods.levelAt`): SP `Floods.advance(level, dt)`, server
`Floods.setTime(level, tick*TICK_DT)`, client = snapshot clock + ping (the tick
at which its predicted inputs get processed; 0 corrections in tests). Physics:
`Level:liquidAt` returns water below `f.surf`, so swimming/drowning/splash/
fireballs work unchanged. Render in `renderWaterEffect` (distortion + tint per
cell, over EVERYTHING it covers incl. solid blocks — only tile water is skipped, no double tint). Surfaces (floods AND tile water
with air above: `Level:isWaterSurfaceCell`) use `src/fx/WaterSurface.lua`: tint
drawn in 4-px columns whose top follows the wave (no flat edge behind it);
distortion starts `WaterSurface.MARGIN` px below the surface. `Floods.updateFx`
(clients only): 'floodRise'/'floodFall' sounds when the water starts moving
(each step too), bubbles via `Level:spawnBubble`, born at the lowest OPEN water point of a random column
(the flood rect may start inside blocks: water rising from under the ground). Level `marea_alta.json`.
**Connected floods** (flood prop `control`): 'cycle' (default, the pure time cycle),
'boss' (zone prop `zone`, 0 = the overlapping/nearest one: runs its cycle from the fight
start while the zone is in 'fight' and a boss is alive and not dying; then falls to its
minimum and stays — fortaleza_malvada) and 'switch' (ON/OFF blocks linked to it: any
linked block ON → rises to max and stays; all OFF → falls to min; steps/pauses honoured).
**Links are generic**: level JSON `"links": [{col,row,to=id}]` (old key `flood` still
read) from an ON/OFF block to any ACTIVATABLE entity (type def `activatable = true` →
prop `id`, auto-added if the type doesn't declare it; optional `onLink(props)` run by
the editor when a block is linked, e.g. flood → control 'switch'). Game side:
`Level:linkedCells(id)`, `Level:signal(id)` (any linked block ON; authoritative in SP and
server — send the resulting state to clients, like floods do). Editor: a link disappears
with its block (`Model:set` drops it when the cell stops being ON/OFF; `pruneLinks` on
load), "Quitar conexión" in the inspector, ids unique across all activatables. A controlled flood stores
only `{active, t0, L0}`; its level is still a pure function of t
(`Floods.controlledLevelAt`). `Floods.control(level, t)` (SP inside `Floods.advance`,
server before `setTime`) decides the changes; the snapshot carries `fc =
Floods.netPack` → client `Floods.netApply` and computes the water at its predicted time.
Editor: Bloques layer → tool **Conectar** (K): click an ON/OFF block → pick its flood in
the Selección tab (+ "Empieza encendido"); links drawn as yellow dotted lines; flood ids
kept unique (`Model:fixFloodIds`); warnings for dangling links. Harness `flood_control`
(+ `online_boss` with `tools/tests/online_boss/fortaleza_flood.json`). Protocol v25.

## Spike rain (orchestrated spikes)

`rainspike` = `spikefall` with `autoDetect = false` (only falls when
`e:trigger(warn)` is called); painted in the editor by dragging (`def.paint`).
`spikerain` = invisible director entity (EvilCaibles port): wave cycle
(min → up → max → down, each wave peaks higher), picks spikes of its `group`
near players with a clear drop, aims ahead of the player with some probability,
round-robin per player, min spacing, per-spike cooldown. All tunables are
props. `EDITOR_VIEW` global is true while the editor draws the map (use it for
editor-only visuals). `drawEditorOverlay(props, cx, cy, zoom, ctx)` gets
`ctx = {entities, t, camX, camY}`; `editor.draw(x, y, s)` = code-drawn icon.

Network scaling: entities whose `netAtRest()` is true (e.g. hanging spikes)
are NOT sent in snapshots; the client calls `netRest()` for missing entries
(the level with 293 entities sends ~540-byte snapshots).

## Original Unity project (reference only)

`/home/mtvemo/Escritorio/Proyecto_Unity_Exportado/ExportedProject/Assets` —
scripts in `Scripts/Assembly-CSharp/`, real inspector values in
`Scenes/Level1.unity`. Port *behaviour and timings*; the physics differ, so
don't copy speeds/forces literally (the user tunes feel by hand).

## Story Mode (`src/story/`, in progress by STAGES)

Plan (approved by the user; file `~/.claude/plans/rippling-swinging-seal.md`): 1 foundation ✔ · 2 generic difficulty
framework ✔ · 3 lives + Game Over ✔ · 4 results + grades ✔ · 5 world map ✔ · 6
difficulty unlocks + double bosses ✔ · 7 level order ✔ (28 levels: every race level; each world = its island's
theme, easiest first by enemy/spike density, new mechanics first, auto-scroll / mazes / dark / very tall last — see the
comments in `Worlds.LIST`; the Snowball Boss `lago_helado` is a mid-world boss node in the Summits) · 8 KOTH
arenas as bonus nodes vs an expert BOT ✔. User's decisions: world map with a path, 3 save slots, KOTH = bonus vs a bot.
- **Stage 2 ✔ — DIFFICULTY = generic modifier framework** (`src/Difficulty.lua`): each difficulty id (`easy, normal,
  hard, extreme, xtra`) is a table of NAMED modifiers; base code asks `Difficulty.k('airTime')` / `flag(...)`, never
  the difficulty's name. It is a property of the level being simulated: `level.difficulty` (nil = NEUTRAL: everything
  1 = the game as it was — Free Play, editor, harnesses, online rooms without one), bound with
  `Difficulty.bind(level)` (AdventureState enter/exit, server `initRoomSim` + every `stepRoom`, client on `game_init`).
  PACE = time scale per entity category: `Difficulty.dt(e, dt)` in the entity update loops (SP + server) scales the
  whole entity (walk, fall, telegraphs, cooldowns, projectiles) — `enemyPace` (Enemigos), `trapPace` (Trampas),
  `bossPace` (Jefes); a type opts out with `pace = false` or picks one with `pace = '...'`. No boss was retuned by
  hand. Others: `bossHp` (`Boss:startFight`), `playerHp` (`pa:applyDifficulty()`, called by whoever creates the player
  after binding), `invuln` (hit / respawn), `airTime` (drowning), `hazardHurt` (spikes and lava: `pa:hazardHit()` =
  1 HP + a hop instead of death), `bossExtra` (stage 6). Values: easy .8/.8/.7 pace, boss hp .75, 4 HP, invuln 1.3,
  air 1.4, hazardHurt; normal = boss pace .85, hp .9 (levels as today); hard = enemies/traps 1.1, air .9 (bosses as
  today); extreme 1.25/1.3/1.2, boss hp 1.15, invuln .75, air .8. Online: `set_mode { difficulty = id | 'none' }` →
  `room.difficulty` → `game_init.difficulty` (no room UI yet; additive, no protocol bump). Story: a NEW save asks the
  difficulty (`StorySlotState` picker; Extreme / Xtra locked until `Save.global().unlocked`); `AdventureState` takes
  `args.difficulty`. Harness `difficulty_rules`; `online_smoke DIFF=easy`.
- **Stage 3 ✔ — lives and Game Over.** Lives belong to the ADVENTURE (save field `lives`), not to the level: start =
  `livesStart` (3 on Easy/Normal/Hard, 4 on Extreme, 6 on Xtra Extreme — the user's numbers; `Difficulty.of(id, name,
  default)` reads a modifier without a level). `AdventureState` args `lives`, `onLeave(lives)` (called from `exit()`
  however the level is left — finished, pause → exit — so lost lives always count; never on 0 lives), `onGameOver()`
  + `gameOverNote`: with them the Game Over overlay has no "retry", only CONTINUE. `Run.gameOver(world)`: lives back to
  the start value and the WORLD restarts (its nodes are no longer done; `best` records stay); with the modifier
  `restartGame` (Xtra Extreme) the whole game restarts. The map shows the lives and a notice after a Game Over.
- **Stage 4 ✔ — results, grades, rewards.** `AdventureState` keeps level stats (`self.stats`: kills of non-boss
  enemies, killable total from `Modes.entityInfo`, stars / total, deaths, hits = HP lost) and passes them in the
  `onFinish` result. `src/story/Score.lua` = the scoring as DATA: weights (time 30 vs a par of 0.75 s per tile of level
  width, min 40 s, zero at 3×par; lives 25; hits 10; kills 15; stars 20) → rating 0-100 → grade S ≥95, A ≥85, B ≥70,
  C ≥50, D; world grade = average of the best rating of each node. `Run.complete` stores best rating / grade / points
  (× difficulty `scoreMult`: easy .8, hard 1.2, extreme 1.5, xtra 2), total points, and gives REWARDS: the first time a
  level reaches S → +1 life, A → +500 points (`Score.LEVEL_REWARD`); clearing a world's boss the first time, by the
  world grade S +2 lives, A +1, B +1000 points (`WORLD_REWARD`, once per world: `worldReward`). `StoryResultsState`
  is based on `OnlineResultsState` (the user asked for its life: bouncing title, light rays, youWin music ducked while
  counting, tick sounds) adapted to ONE player: a single pedestal (height + colour by grade) the monster lands on,
  rows slide in and count up, TOTAL /100 and points, then the grade is stamped on the pedestal (S/A: confetti +
  fireworks, B: confetti, D: sad trombone); then record / rewards / world grade. First ENTER skips the animation,
  the next returns to the map. The MONSTER (user's request: it was hard to see and lifeless) stands in a spotlight
  with a light outline (silhouette shader drawn at 4 offsets) and REACTS: falls onto the pedestal, NERVOUS while the
  rows count (foot taps, looks left/right, little hops, tremble); after the grade: happy jumping (S A B), standing
  sighing (C), sad crouched with its back turned (D), and below 25/100 a comic DEATH (the game's death sprite with X
  eyes, jumps and falls out, then drops back in sad) — visual only. Confetti and fireworks are a shared module, `src/ui/Celebration.lua` (also used by
  the online results). The map shows each cleared node's grade and the world grade.
- **Stage 6 ✔ — unlocks and the extremes.** Beating the game (the LAST world's boss) on a difficulty unlocks the next
  one for all 3 saves: `Difficulty.UNLOCKS` = { hard → extreme, extreme → xtra } → `Run.unlockAfter` → global
  `story.sav` {unlocked, cleared}; the results screen says "NEW DIFFICULTY: X" (`summary.unlocked`). Extreme =
  faster + `sense` 1.3 (Easy 0.8): × every enemy detection range — `Entity:seesPlayerBelow` (ceiling droppers,
  falling spikes), `Noise.heard` (hearing), Gloomy `senseRange`, mortar and pufferfish `range`. XTRA EXTREME = Extreme
  + `bossExtra`: TWO bosses per arena (`src/world/XtraBosses.lua`, applied by `Level.fromData(lvl, difficulty)` — the
  difficulty is now known WHILE building, `Level.new(path, difficulty)`; AdventureState, server `initRoomSim` and the
  client `_buildWorld(lv, data.difficulty)` all pass it, so indices match): the level's JSON `"xtraBosses": [...]` or,
  by default, each boss in a zone mirrored across the zone centre (≥ `MIN_SEP` 5 cells apart, `point`/`points`/
  `patrol` props mirrored, the def's `xtraStrip` props removed — the Snowball Boss's `icicles` belong to the arena);
  both get `props.xtraPair` → hp × `pairHp` 0.65 (`Boss:startFight`). Their reserve minions double too. The pair
  starts SYMMETRIC (original at a third of the zone, the copy mirrored; `props.xtraCopy`). ALLY RULE (Boss base,
  generic): a boss may only START an attack when its ally isn't attacking nor just did (`ALLY_GAP` 0.8 s) and the copy
  waits `ALLY_START` 2.5 s — `Boss:mayAttack(level)`, asked by each type where it decides to attack; each type lists its
  attack states in its tuning `ATTACKS = {...}` (the Mirror's perch is positioning, not attack: it waits perched). That's
  ALL on purpose: allies move at their own pace and pass through each other — pushing/separating them (charges cut) and
  slowing the waiting one (floated in slow motion) were tried and the user preferred simple turns. One SHARED health
  bar for the pair (`BossHud.drawZone`, title "NAME ×2", also in the intro cinema). Bosses ignore other bosses' slam
  noises (`Noise.emit(..., from='boss')`, `Noise.heard(..., ignore)`: a Mega Gloomy charged at its ally). Tests don't
  pause when the window loses focus (`run.sh` exports `FM_TEST=1`, `game.lua love.focus`). Also fixed:
  a world reward was skipped when the level gave none (`ipairs` stopped at the nil). Harnesses: `difficulty_rules`
  (`sentidos`, `doble`), `story_flow` (`desbloqueo`), `sp_boss DIFF=xtra` (prints the bosses + "Aliados": fails if both attack at once
  > 0.5 s), `online_smoke DIFF=xtra` (the client has both).
- **Stage 8 ✔ — BONUS: King of the Hill vs the BOT.** One optional bonus per world (`Worlds.LIST[w].bonus`,
  `Worlds.bonus(w)`; NOT in `Worlds.nodes`: it doesn't count for progress or unlocks): pradera isla_flotante, costa
  cala_de_los_muelles, fortaleza ciudadela_alterna, nieve lago_de_cristal, cuevas cripta_del_silencio (dark), final
  cantera_real (rethemed volcano). Opens when the world's boss is beaten (`Run.bonusState(w)`); FIRST win = +1 life +1000 points
  (`Run.bonusResult`, save field `bonus[id] = {won, best, played}`). Map: a blue "B" node on a short branch from the
  castle (`overworld.json worlds[i].bonus`; in `StoryMapState` it is stop n+1 of its world: `mapNodes` / `stateOf`).
  MATCH = `src/story/BonusMatch.lua` inside AdventureState (`args.bonus = { onEnd }`): `BonusMatch.TIME` 60 s (story and
  Free Play; ONLINE King of the Hill = 100 s: koth `DEFAULT_TIME` and every arena's `matchTime`), HOSTILITY BY
  DIFFICULTY (`Difficulty` `botRest` × the rest between ground pounds, `botChase` tiles, `botCount`): easy 3.5 / 3,
  normal 2 / 5, hard and no difficulty 1 / 7 (the user's reference), extreme 0.7 / 10, Xtra the same with TWO bots
  (second one from the centre; the score to beat is the BEST bot's; `bonus.bots`), both score
  from the point zones, more points wins (tie = not won), HUD "TÚ n · clock · BOT n"; your adventure lives are NOT
  used (99, never written back); your ground pound near the bot shoves it too.
  THE BOT (`src/ai/Bot.lua`; user's brief: its job is to keep you from sitting in the zone, by ground pounds; IMMORTAL
  for simplicity — `pa.immortal`: hits, knockback and enemies still affect it, but no HP loss, death or drowning; a
  kill = a hop + blink): a real `PlayerAdventure` driven by input bits each frame. If you are in a zone and its cooldown
  is over it hunts you through the nav graph and, within `ATTACK_R`, jumps at you and GROUND-POUNDS on top: `Bot:push`
  launches you far (`PUSH_VX` 1150) with a short stun; then `attackCd` (`ATTACK_CD` 0.45 s × 0.7-1.5 / the difficulty's
  `enemyPace`). VERY HOSTILE (user): it also chases you when you are within `CHASE_R` 7 tiles even outside a zone, and
  attacks whenever you are in range, whatever it was doing.
  Otherwise it goes to the best zone that has FLOOR NOW (`Bot.pickZone`: more points first, all-thin-ice zones
  penalised, ON/OFF floors re-checked every second) and holds it. NAVIGATION (`src/ai/BotNav.lua`): a graph per level
  built with the REAL physics — nodes = standable cells, edges = walk to the next cell or a recorded MACRO (≈30 input
  sequences from each cell: jumps, double jumps at several timings, drops, walk-offs; trampolines included via their
  `interact`) → `assets/nav/<level>.json` (`run.sh bot_nav BUILD=1`, ~1 s per arena; signature of the tiles: stale →
  the game rebuilds it on entering). Levels with ON/OFF blocks are built in BOTH states and merged; at run time edges
  whose target has no floor now are skipped, an edge that fails twice is banned 15 s, and with no path it brute-forces
  toward the goal jumping. The bot runs at a FIXED 1/60 step inside (`Bot:step` accumulates the real dt): the macros
  were recorded per frame at 60 Hz, and with the game's variable dt they landed elsewhere — in the user's first test
  the bot never reached a zone while the harness (exact 1/60) passed; the harness now feeds an irregular dt and
  `story_flow` checks in the real game that the bot scores. The graph is only the MAP of possible moves: what the bot does is decided every frame
  (where you are, the level's state) plus some chance (rest between attacks × 0.8-1.6, it roams to a random cell of
  its zone every few seconds). FREE PLAY: a level with point zones and no finish starts as a match vs the bot too
  (`FreePlayState:_play`; arenas without a nav file build it on entering). Harness `bot_nav` (per arena: reaches a zone and stays; with a dummy player in the zone it
  must push it ≥ 3 times in 40 s) and `story_flow bonus`.
- Menu: Aventura → HISTORIA (`story_slots`) / ONLINE / JUEGO LIBRE (PRUEBAS) (`free_play` stays as the debug hub).
- `src/story/Worlds.lua` = the story as DATA: ordered worlds `{ id, levels = {...}, boss }` (stage 7 order; every
  story level needs a FINISH — hunt-only levels have none). `Worlds.nodes(w)`, `levelName(id)`.
- `src/story/Save.lua`: 3 slots `story1..3.sav` + global `story.sav` (unlocks) in the save dir — Lua tables loaded
  without an environment; never a `.lua` name. `src/story/Run.lua`: the open slot; `state(w, k)` = done / open /
  locked (levels open in order, the next world when the boss is beaten), `complete(id, result)` saves, `frontier()`.
- `StorySlotState` (pick / create / delete with confirmation) and `StoryMapState` = the WORLD MAP (stage 5, Super Mario
  World style): ONE big scrolling map (84x48 cells of 32 px) from DATA `assets/story/overworld.json`, written by
  `tools/ui/make_overworld.py` (deterministic; also writes `assets/images/story/` node/castle/water/path/bridge/ground/
  edge/foam sprites): terrain letters per cell (`~` sea, g grass, s sand, w snow, c cave rock, f fortress stone, l volcanic
  rock, L lava = the game's lava.png animated) + `heights` per cell (0 pit, 1 plain, 2 plateau, 3 summit; RELIEF table
  of wobbly blobs per island, never within ~2 cells of a path — paths run along the VALLEYS —, min 2x2, cave pits,
  the volcano's lava crater): the game tints tops by height (`LIT`) and draws a CLIFF under every cell higher than the
  one below (lip = its block texture, body = `CLIFF_BODY`, 0.75 cell per level) + rim edges where a neighbour is
  lower. Landmarks = `assets/images/story/features/*.png` (hill, dune, peak, spire*, rock_*, cave_mouth; drawn ×3; a
  deco name not in `DECO` is looked up there; `oy` = feet offset in cells, used by cave mouths on cliff faces). Paths
  and bridges are Catmull-Rom curves through control points (generator `catmull`, stored smoothed). One PATH per world (its `Worlds` levels are spread evenly along it
  by arc length, however many there are, boss last = a CASTLE with the boss sprite small beside it, gold flag once beaten),
  bridges between worlds (`connect`; planks over water), decorations and wandering critters (the game's own sprites at ×2),
  per-world boss art (`worlds[i].boss` {img, fw, over, glow, fly, invert}). Island tops = ground tiles coloured from the
  game's blocks; CLIFF faces under land facing the sea = the real block textures seen from the side (grass/sand/snow/
  stone/border/deep_stone). The hero (monstrito walk frames) WALKS along the path: ←→ = previous / next level (crosses
  worlds over the bridge; a locked stop stops it with a bump), ↑↓ = walk to the next world's first level / previous
  world's boss; long trips speed up (~1 s). `self.world/self.node` change at once (the walk is visual; ENTER while walking
  snaps and plays). Tap a node = walk there (tap your own = play); bottom arrows = previous / next. Camera follows the
  hero between the top band (TOP_H) and the level card (BOT_H), clamped to the map. The boss stands on the side of
  its castle that has LAND (`bossDx/bossDy`, right → left → below). Bridges are always opaque (locked = darker) and run
  2 planks onto each shore. FULL MAP for review: `StoryMapState:renderFull()` → `story_flow` writes
  `story_map_full.png` (2688x1536, every world open); copy it to `FlappyMonster_pruebas/mapa/mapa_completo.png`. Bonus nodes (KOTH vs bot) = stage 8.
  `PixelFont.draw` draws ONLY the letters (it used to fill a tight black box behind them: fine on the black menus,
  odd everywhere else — the user had it removed); over coloured backgrounds use `PixelFont.shadow` (1-font-pixel black
  drop shadow).
- **Level complete now exists in single player** (it didn't: reaching the finish did nothing): `AdventureState`
  detects the `finish` trigger → `win()` (fanfare, banner `hud.level_clear`, invulnerable) → after `WIN_TIME` calls
  `args.onFinish(result {score, time, lives})` or goes to `returnTo`. The story passes `onFinish`; Free Play and the
  editor just return.
- Harness `story_flow` (real game: slots, locked nodes, clearing levels, save reloaded from disk, world 2 unlock,
  delete; screenshots at 1280 / 960 / 1600, plus a tour with every world open: `story_world_<n>.png`).

## OST presentation videos (`tools/video/`)

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

## Testing without a human

**ALWAYS start here — don't rebuild test setups by hand.** Every harness lives
in `tools/tests/` and runs through ONE command from the repo root:
`tools/tests/run.sh all` (quick battery, ~2 min, exit 0/1) or
`tools/tests/run.sh <harness> [VAR=val ...] [-- args]`. `run.sh` starts/stops a
FRESH local server for `online_*` (a reused one keeps stale peers → bots never
join), copies `tools/levelgen/arenas/*.json` to a temp `assets/levels/zz_tmp_*`
(the server ignores `_*` names), cleans `server/published`, applies a timeout
(a LÖVE error screen never exits) and flags Lua errors in harness or server.
`tools/tests/README.md` = table of every harness (what it checks, how to run
it, its env vars) + rules for new ones. When a test needs something new, fix
or extend the HARNESS (and its README row) instead of working around it in a
scratch copy: the time spent fighting test setups was the user's complaint.
Harnesses: flyers, crawler_drop, mechanics, sounds, boss_sim, sp_boss, boss_frames, megagummy_rules, gloomy_rules, megagloomy_rules,
editor_open, free_play, update_boot, online_smoke, online_boss, online_helmet,
level_check, level_solve, level_shots, story_flow, difficulty_rules, bot_nav. `tools/` is not shipped (.love / updates).

Low-level notes (for writing NEW harnesses):
- Headless sim (no window): a scratch LÖVE app with `t.window=false`,
  `package.path` pointing at the repo, `love.filesystem.read` patched to read
  from the repo and a stub `love.graphics.newImage` (like server headless).
- Screenshots: scratch LÖVE app with symlinks to `assets src libs settings.lua
  input.lua`, `love.filesystem.setSymlinksEnabled(true)`, drive the real state
  with a `Protocol.newInputStub()` as `Input`, `love.graphics.captureScreenshot`
  (files land in `~/.local/share/love/<identity>/` — delete afterwards).
- Online: `love server --headless` + bot clients using `libs/sock` + bitser
  (hello → create_room → set_mode{mode,level} → join_room → set_ready →
  start_game → send `in` {s, b}). Kill the server afterwards (`ss -lunp | grep 22122`).
- Test levels: boss test arenas are NOT game levels any more (not in the editor
  or the server): `tools/levelgen/arenas/jefe_espejo.json` (mirror boss, mortars),
  `MiniBossArena.json` (Nave Malvada; the user's layout), `jefe_cangrejo.json`
  (Mega Crabby) — small, the boss is in view at once; pass them to `run.sh` as
  `LEVEL=tools/levelgen/arenas/x.json`. Real boss levels: ruta_del_espejo,
  fortaleza_malvada, guarida_cangrejo_rey (default of the boss harnesses; sp_boss
  teleports the player into the arena).
  `assets/levels/lluvia_pinchos.json` (race, auto-scroll + spike rain),
  `assets/levels/rebote_real.json` (King of the Hill: all 4 trampolines +
  both Trampoline Crabbies), `assets/levels/cumbre_cangrejo.json` (KOTH:
  wall-walking Crabbies), `assets/levels/marea_alta.json` (KOTH: floods).
  For online tests of a KOTH level add a `pointarea` to a temp copy.
- **Level generator + solver**: `tools/levelgen/` writes levels from Python
  (`lib.py` = grid helpers, `levels_run|hunt|koth|boss.py`, `python3
  tools/levelgen/build.py [--show name]` → `assets/levels/*.json`; boss levels graft
  the proven arenas of `tools/levelgen/arenas/`). Check them with
  `tools/tests/level_solve` (BFS with the REAL player physics: double jump, crouch,
  water, spikes, trampolines emulated; `EXPLORE=1` = every enemy reachable, for hunt)
  and `tools/tests/level_check` (editor validate + which modes list it + 20 s entity
  sim). Design numbers (double jump): one jump ≈ 1.6 tiles, two ≈ 3; gaps ≤ 4 easy;
  a 1-tile tunnel needs a crouch jump; up trampoline ≈ 5 tiles + air control;
  water: exit a 3-deep pool needs a ledge at the surface (drag eats the jumps).
  `build.py` WITHOUT `--only` rewrites every generated level and loses the user's editor
  touch-ups: always `python3 tools/levelgen/build.py --only name`.
  Underwater design numbers: one jump ≈ 1.1 tiles, double ≈ 2.1 (jumps only come back on
  ground) → vertical climbs need footholds: ladders of waterlogged drop-through
  platforms (`DROP + 16`, one per row). Surfacing (head in air) refills air at once;
  vents only give a bubble every 8-26 s, so long water sections need air pockets with a
  ledge to stand and breathe. `laberinto_submarino` (`levels_water.py`): 20x9-chamber
  maze, 1-2 routes to the finish (loops only inside dead branches; asserted), exit = the
  right-column chamber farthest from the start, air ≤ every 2 chambers on the route,
  ~77 pufferfish (gentler on the route), spikes, checkpoints/vents/stars/lives; the
  generator tries seeds until the rules hold. Solver: `NODROWN=1` = terrain only; the
  heuristic is the tunnel distance to the goal (`HDIST=0` = straight line).
  Batch of 15 (race: valle_soleado, cavernas_cristal, torre_viento, fabrica_morteros,
  tren_fugaz (auto-scroll), canon_trampolines; hunt: ciudadela_cangrejos,
  jardin_gummies, mina_inundada; koth: isla_flotante, coliseo_pinchos, cascada_dorada;
  race+boss: ruta_del_espejo, fortaleza_malvada, guarida_cangrejo_rey, lago_helado, glaciar_cangrejo, reino_gummy, gruta_lugubre). Each level
  whitelists its mode with `"modes"`. Ship = bump `version.txt`.
- Bots: send `in` only when there are new inputs, or the server kicks them
  for flooding.

## Music catalog layout (REORGANIZED in 3.48.0 — older notes in this file still use the OLD names)

`assets/music/`: `menus/`, `map/` (map_<world>), `worlds/<pradera|costa|fortaleza|nieve|cuevas|volcan>/` (LEVEL music:
2-3 themed tracks per world, ids `<world>_<n>`), `bosses/` (+ `extras/`), `jingles/`. `index.json` documents it.
- Renames (old → id/file now): classic / level_nes → `pradera_1`; dark_cave → `cuevas_oscuras`; boss / boss_nes →
  `boss_generic` (intro + loop); tentacle_nes → `crab_tantrum_normal`; tentacle_winter → `crab_tantrum_icy`;
  tentacle_gloomy → `crab_tantrum_gloomy`; winter_nes → `snowball_boss`; tentacle_chip(_instrumental) →
  `crab_tantrum_chip(_instrumental)` (extras); youWin → `victory`. Old ids still work: `"aliases"` in index.json →
  `Music.id(id)` (levels, zones, old rooms).
- PENDING SLOTS (`"pending": true`, file path already set, `fallback` id plays meanwhile via `Music.playable` in
  `Sound.resolve`; a listed file that doesn't exist also counts as pending): pradera_2, costa_1/2, fortaleza_1/2,
  nieve_1/2, cuevas_1, volcan_1/2 (fallback pradera_1; cuevas_1 → cuevas_oscuras) and `victory` (no fallback: silent).
  To fill a slot: drop the file at that path and remove `pending`/`fallback`.
- The BORROWED placeholder tracks the user removed (flying_machine, hidro_city, labyrinth intro/loop, boss_battle
  intro/loop, TentacleTantrum.ogg, winter.ogg, victory.ogg, and the old level.ogg) are archived OUTSIDE the repo:
  `FlappyMonster_originals/music/placeholders/` (generators read their references from there: `famicom.ref(name)`).
- STUDY + STYLE GUIDE for all new music: `docs/musica/GUIA_MUSICAL.md` (what exists, the house style measured, the game leitmotif "la llamada", per-island palette, composition rules); `tools/music/study.py` measures any .mid.
- User renames after the reorg: the level tune is `fortaleza_1` (never meant for the meadow; `pradera_1` is a pending slot, default fallback = fortaleza_1) and the chip tracks are `mirror_boss` / `mirror_boss_inst` (the Mirror fight).
- ISLAND LEVEL MUSIC = `tools/music/worlds_nes.py` (follows the guide: intro 4 · A · A' · B · A'', 3+3+2 kick, the
  game motif "la llamada" closing phrase B). MEADOW done (3.49.0, verified by numbers only): `pradera_1` (G major,
  136 BPM, pulse lead + echo, hopping bass, offbeat chords, bird trill; 3 variants for the user to pick: `previas` →
  `FlappyMonster_pruebas/musica/pradera_1_{A,B,C}.ogg`, A installed), `pradera_2` (v3 "Galope": C MAJOR, 144, galop rhythm
  dotted-8th + 16th in melody, bass and kick, flute lead — v1 was pradera_1 transposed to E minor (too similar,
  harmonic rubs), v2 its own E-minor tune (the user: melody and instrumentation didn't fit each other): a minor tune
  over the meadow's happy hopping arrangement doesn't work; the 'second face' changes KEY, RHYTHM and TIMBRE, not mode), `pradera_bonus` (152, four-on-the-floor + an 8-bar
  PERCUSSION SOLO before the last pass: snare/tom call and response, running toms, growing roll; isla_flotante). The
  user approved pradera_1 (variant A) and pradera_bonus. Other islands: add their melody + arrangement there.
  User's decisions: the island table of the guide is approved; arrangements of borrowed tunes stay FOR NOW but get
  replacements with a similar vibe that keep a motif or a recognizable element as a "sample", never a copy.
- INTRO + LOOP (user's rule, 3.50.1): a track with an intro is TWO files — `<track>_intro.ogg` (plays once on entering)
  and `<track>_loop.ogg` (repeats forever, never back to the intro); index entry `"intro"` + `"loop"`. Generators:
  `GN.fold(y, n, at)` folds the song's tail onto the LOOP start (`at` = intro length), and `GN.export(name, y, intro)`
  splits (the intro's last 6 ms fade). Done for pradera_1/2/bonus, costa_1/2/bonus, crab_tantrum_gloomy (boss_generic
  already was). `Sound.update` starts the loop when the intro has < 9 ms left (it used to wait until the intro had
  STOPPED = a frame of silence, late on the beat). Harness `sounds` checks every intro track. Every new track with an
  intro must be exported this way.
- FORTRESS (3.51.0, all new; verified by numbers only): the old `fortaleza_1` (level_nes, an arrangement of a
  BORROWED tune) was removed from the game → `FlappyMonster_originals/music/placeholders/fortaleza_1_level_nes.ogg`
  (`melody_nes.py`'s level output now goes there too). New set in `worlds_nes.py`: `fortaleza_1` "Marcha de hierro"
  (C minor, 140: VRC6 saw an octave down + pulse, march rhythm tan · ta-ta in melody, fifth stabs and snare, octave
  bass, metal noise offbeats, triplet FANFARE motif), `fortaleza_2` "Engranajes" (G minor, 126: thin staccato pulse,
  fifth/root tick-tock, locomotive bass, metallic 16th noise, anvil motif — factories, quarry, the train),
  `fortaleza_bonus` (the march at 156 + percussion solo; ciudadela_alterna). `boss_generic` still uses the borrowed
  tune (pending replacement, like the Crab Tantrums and snowball_boss).
- ISLAND BOSS THEMES (3.52.0, `worlds_nes.py`, `boss=True` = crash every 2 bars + snare fill every 4; intro + loop;
  verified by numbers only): `gummy_king_boss` "Su Majestad Gummy" (G major like the meadow, 152: dotted pompous
  fanfare, pulse + its octave, jelly bass hopping to the octave, timpani + the meadow trill; B in E minor;
  reino_gummy + jefe_gummy arena) and `evil_ship_boss` "Persecución" (C minor like the fortress, 160: the march as a
  chase — driving 8ths, saw, non-stop bass, 3+3+2 fifth stabs, metallic 16ths, ALARM motif; fortaleza_malvada).
  `boss_generic` (the borrowed tune) is OUT of the repo (`FlappyMonster_originals/music/placeholders/`); ids boss /
  boss_nes / boss_generic are aliases of `evil_ship_boss`, which is also `BossZones.DEFAULT_MUSIC`.
- **CRAB TANTRUM REMADE (3.53.0, `tools/music/crab_tantrum.py`; verified by numbers only; WAITING for the user's
  approval — then the Gloomy and Icy variants are built FROM it)**: `crab_tantrum_normal` is now an original
  composition, the FOUNDATION of the three Mega Crabby themes; the old note-for-note arrangement is outside the repo
  (`placeholders/crab_tantrum_normal_tentacle_nes.ogg`; `tentacle_nes.py` now writes there; icy/gloomy still import it
  until they are remade). From Tentacle Tantrum only SAMPLES: (1) the riff CELL (long tonic, tonic, up a 4th, down to
  the 3rd; rhythm 6-2-2-4) opening bars 1/3 of phrase A (and, varied, 5) and played by the BASS in the bridge, (2) the
  3+3+2 tresillo in bass and kick, (3) the chorus gesture (long note + lower neighbour) once per B phrase, (4) the
  finale's syncopated repeated notes (6-4-4-4) over rising chords in the coda. Everything else is new. HARMONY = D
  NATURAL minor only (v2, 3.53.1): v1 cadenced on A major (C#) next to C-natural chords and its chorus was F–C–Dm–B♭
  (happy) — the user liked the theme and the samples but in the non-sample parts "the melody didn't quite fit the other
  instruments, harmony a bit odd" (the pradera_2 lesson again: no bright major section inside an aggressive minor
  arrangement, no leading tone mixed with ♭VII). v2 (all natural minor, new chorus progression i–♭VI–♭VII–i · iv–♭VI–♭VII
  with a new melody) was "weirder than before". v3 (3.53.2): no cadences and no new progression at all — the non-sample
  parts use the riff's OWN language: tonic + the ♭VI–♭VII turn, melody in D minor PENTATONIC (the cell's notes, 89 %);
  A = Dm | Dm B♭ | Dm | Dm C | B♭ | B♭ C | Dm | B♭ C; chorus = the chorus gesture in a descending sequence, two bars
  per chord (Dm · C · B♭ · C). Only bars 7-8 of A and the chorus have ever been changed; the rest was approved.
  v3 verdict: "better, but it doesn't fully fit the character, and going from the good parts into these is odd". v4
  (3.53.3): (a) A closes with the riff itself — bar 7 = the cell, bar 8 = the riff's TAIL (tonic, tonic, ♭VI, ♭VII; one
  more sample; a third chord in a bar = its last quarter, `Q4`); (b) the chorus is no longer sung in long notes: a WAR
  CHANT (short repeated notes on the 3+3+2, then a fall in the cell's rhythm; Dm Dm B♭ C ×2) and it KEEPS A's half-time
  tresillo groove with more toms (it used to switch to four-on-the-floor + 8th bass: the odd transition). Lesson: for
  this character, sections differ by intensity and register, not by groove or by turning lyrical.
  COAST link: D minor = relative of costa_1's F major, the coast's marimba plays the tresillo, 16th shaker,
  ends with "la llamada". Character (user): powerful, TRIBAL, aggressive — tom ostinato, deep kick, clearly drawn bass
  (triangle + a pulse an octave up), VRC6 saw + pulse lead. 180 BPM (felt at 90); intro 4 (drums; own file) · A · A' ·
  B · B' · tribal BRIDGE · A'' · CODA = 56-bar loop (74.7 s); drums 46 % of the energy, bass 23 %, lead 20 %.
  PLAN for the variants (user): Gloomy = slower, cave-like, with the spider "legs" (constant 16ths in groups of 8,
  12.5 % pulse, pauses at phrase ends — `how_to_spider.txt` in the repo root); Icy = keeps and develops the
  Christmas/music-box motif of Winter Fallympics on this foundation. Reinterpretations, never copies; the three must
  clearly be the same Mega Crabby identity. NOTE: `GN.export(name, y, intro)` DELETES the old single `<name>.ogg`.
- **CRAB TANTRUM: the user APPROVED the main theme (3.53.3 = definitive) and the two variants were built from it
  (3.54.0, `crab_tantrum.py [normal gloomy icy]`, `build(style)`; the normal render is bit-identical to the approved
  one; verified by numbers only).** Same song for the three (cell, tail, war chant, bridge, coda, D minor), other
  atmosphere. GLOOMY (`crab_tantrum_gloomy`, 144 BPM, −11 LUFS): hollow N163 voice with cave echo, triangle bass only,
  no stabs/marimba/doubling, dry drums (deep tresillo kick, short-noise claw clack on 3, far toms) and the spider LEGS
  (`how_to_spider.txt`; `GN.LEG8/LEG6/I_LEG`): non-stop 16ths in groups of 8, 12.5 % pulse, chord's minor pentatonic +
  blue note, foreground when the melody rests / background (×0.4) under it, 6-against-8 second pattern from the
  chorus on, octave jump every 4th bar, and the PAUSE at each phrase end (chromatic run down, then the last beat silent
  except the melody = the riff's tail; crash on re-entry). ICY (`crab_tantrum_icy`, 180): the Winter Fallympics
  CHRISTMAS / music-box MOTIF (`MOTIF`, 4 bars over B♭ B♭ C C) as the second idea, only where ITS harmony is — which
  here is the riff's own ♭VI–♭VII turn resolving to D minor: the intro (music box alone + sleigh bells), the first
  half of both choruses (1st: box alone over the band, answered by a NEW phrase built on its octave leap `DEV`; 2nd:
  the voice sings it too and the war chant finishes) and the first half of the bridge (drums empty out). Ice palette:
  smooth N163 voice doubled by the music box an octave up, ice chimes on the tresillo (where the marimba was), sleigh
  bells, 16th shimmer. The old arrangements (tentacle_winter / tentacle_gloomy) are outside the repo
  (`placeholders/crab_tantrum_icy_tentacle_winter.ogg`, `..._gloomy_tentacle_gloomy_{intro,loop}.ogg`); their
  generators write there. Older notes in this file about tentacle_nes / tentacle_winter / gloomy_nes `jefe` describe
  those RETIRED arrangements.
- Crab Tantrum TEMPO (3.54.1): the user approved `crab_tantrum_gloomy` as is (144, half-time) but found normal and icy
  "too slow" in game: at 180 with the snare on beat 3 they FELT at 90. Now both are 200 BPM in FULL time (`fast`): snare
  on 2 and 4 with ghost 16ths, tresillo kick + extra kicks, 16th hats, crash every 4 bars in A, backbeat in the second
  half of the bridge; notes, bass and mix unchanged (loop 67.2 s). The gloomy render is bit-identical. Lesson: for a
  boss, judge tempo by where the SNARE falls, not by the BPM number. 200 was "a bit too much" → 3.54.2: the same full-time
  groove at 172 BPM (loop 78.1 s), the middle point the user asked for. 172 was "very slow" → 3.54.3: 186 BPM (loop 72.3 s). Tried so far, full
  time: 200 too fast, 172 too slow.
- SUMMITS (3.55.0, `worlds_nes.py`, all new, intro + loop; verified by numbers only): `nieve_1` "Cumbres de cristal"
  (F major, 148: the melody on the MUSIC BOX an octave up over a soft pulse, half-note bass, 8th "snowflake" chord
  notes, sleigh bells, brushed snare; island motif = falling bells), `nieve_2` "Ventisca" (D natural minor, 156: pulse
  lead with bell sparkles on long notes, 16th wind arpeggio, 8th bass, backbeat — fabrica_criogenica, torre_viento),
  `nieve_bonus` (nieve_1 at 166 + percussion solo; lago_de_cristal), and the new `snowball_boss` "La Gran Bola" (F
  minor, 168, `boss=True`: hopping mocking tune, bass ROLLING in 16ths, rolling toms, sleigh bells, bell doubling). The
  Winter Fallympics CHRISTMAS MOTIF is a sample used SPARINGLY (user: "without abusing"): once per loop, the first 4
  bars of phrase B over its own harmony — nieve_1/bonus in F (IV IV V V) and the boss a minor third up (♭VI ♭VI ♭VII
  ♭VII of F minor); nieve_2 has none (`wmotif(up)`, `MOTIF_THEMES`). The old `snowball_boss` (the Winter Fallympics
  arrangement, winter_nes.py) is outside the repo (`placeholders/snowball_boss_winter_nes.ogg`). Only the two
  `mirror_boss` tracks still carry a borrowed tune.
- SUMMITS v2 (3.56.0): the user found nieve_1/2 (hence the bonus and the boss) "very much like pradera_1/2" — v1 reused
  the meadow's rhythmic mould (dotted 3+3+2 hits, the same B phrase shape) — and asked for a SECOND Winter Fallympics
  sample: the phrase of 1:48-2:08 (Smooth Synth, bars 85-92; `W148` + `W148_END`), the "calm part that loses no energy"
  and BRIDGE to the final chorus. Melodies rewritten with the samples' own vocabulary (three rising 8ths + an offbeat
  quarter, 2-2-2-4 · 2-2-4→; quarter-note leaps like the motif) so own tune and samples are one family; phrases as
  text (`P` / `PH`: "0:Bb4/2 2:C5/2"). Form of nieve_1 and the boss: intro · A · A' · B (bridge = the 1:48 sample:
  its bars 1-4 and its repeated-note build 7-8, two own bars between) · C (chorus = the Christmas motif + answer + la
  llamada; `song()` optional `pc, cc`, tag 'C') · A''. nieve_2: no chorus; its bridge quotes only the first two bars of
  1:48 over the relative minor. Boss: both samples a minor third up (A♭ = relative of F minor). Each sample once per
  loop. `SAMPLE_BARS` = bars excluded from the chord-tone check. Lesson: a new island must not reuse another island's
  rhythmic template — measure attack-position overlap of phrase A against the other themes (now 33-35 % vs pradera).
- 3.57.0 (verified by numbers only): (1) `snowball_boss` phrase A remade — v2 had nieve_1's rhythm bar by bar in minor
  ("not convinced; more distinct from nieve_1, built from the established samples"): its riff is now the 1:48 phrase's
  closing cell (three repeated notes + a leap, `W148_END`), answered by a stepwise descent like the motif's 2nd bar, and
  the motif's octave leap ends the phrase; bridge and chorus unchanged. (2) `gummy_king_boss` REMADE to be regal and
  not meadow-like (v1: G major, hopping bass, offbeat plucks, bird trill): B♭ major, 148, trumpet fanfare ON the beat
  with a "ta-ta taa" call, horns an octave below, held chords, march bass (root/fifth in quarters), military snare
  with drags, timpani, bugle call as its motif; B = a court dance in G minor, baroque stepwise sequence over a 16th
  harpsichord (Alberti). (3) STEMS: `python tools/music/worlds_nes.py <track> --capas` writes every layer as WAV to
  `FlappyMonster_pruebas/musica/<track>_capas/` (each layer gets the master's per-sample gain, so they sum EXACTLY to
  the track; `STEM_NAMES`). Made for pradera_1 because the user hears "little bell-like sounds every 2 beats" in the
  meadow, coast, fortress and summits tracks and wants to point at the layer before anything is changed — WAITING for
  them to say which (candidates: the offbeat chord plucks, the island motif on long tails, the melody echo).
- ACCENTS PER PLACE (3.58.0): with the stems the user identified the `trino_adorno` layer: nearly every level and boss
  theme had "a few high pulse notes in 16ths in the same slot" (the meadow trill adapted), and since the meadow is heard
  first, everything sounded like a meadow remix. The decorative accent stays (same slot: where the melody rests, and in
  the intro) but each is now its own thing — other timbre, rhythm, register, often UNPITCHED (noise channel `fx`,
  helper `swell`): pradera_1/bonus the bird trill (ONLY there); pradera_2 horse hooves (clip-clop); costa_1/bonus a
  WAVE breaking (noise swell); costa_2 bubbles; fortaleza_1/bonus a LOW horn answer (fifth → root) + snare roll;
  fortaleza_2 steam + two unpitched anvil hits; nieve_1/bonus a sleigh shake + ONE ringing bell; nieve_2 a wind gust;
  snowball_boss rolling toms + a low two-note "laugh"; gummy_king_boss a growing timpani roll + cymbal swell;
  evil_ship_boss a low wailing SIREN (one note, ±2 semitones). Stem name: `acento_del_sitio`. Rule for new themes:
  never reuse another place's accent; give each its own sound.
- CAVES (3.59.0, `worlds_nes.py`, intro + loop; verified by numbers only): `cuevas_1` "Ecos de cristal" (D DORIAN —
  B natural, the G major chord —, 104 BPM half time: melody on the music box with a sample-domain cave ECHO, long notes
  with gaps for the echo, pad, whole-note bass, deep kick + one clack, no hats; accent = two falling DRIPS, every other
  bar; cavernas_cristal, nivel01), `cuevas_2` "Laberinto sumergido" (A minor, 92: hollow flute voice with echo moving
  by step, harp 8ths, almost no drums; accent = a SONAR ping and its fainter repeat; laberinto_submarino),
  `cuevas_bonus` (cuevas_1 at 132 + percussion solo; cripta_del_silencio). `cuevas_oscuras` (dark levels) stays.
  Also: the accents of the MEADOW and COAST tracks were "very loud" → 5 dB quieter (fortress and snow were fine).
- Levels: every level's `"music"` = a slot of ITS world (story order: odd → `_1`, even → `_2`; dark levels →
  cuevas_oscuras; other cave levels → cuevas_1; non-story levels by their retheme theme).
- Generators keep their internal names; `famicom.PATHS` / `famicom.out(name, ext)` map them to the new folders;
  `.mid` files are no longer shipped: `tools/music/mid/`.

## Music generation: lessons learned (tools/music/)

- Engine: `famicom.py` (shared). Generators: tentacle_nes.py, melody_nes.py (level +
  boss), tentacle_chip.py, menus_chip.py (rejected). Refs (MIDI/PDF, copyrighted or
  unknown licence) live in `tools/music/ref/` (gitignored) — never in `assets/`
  (everything there ships to players).
- Always MEASURE against the original (librosa): tempo grid fit on onsets (don't trust
  the MIDI tempo: level.ogg is 137.5, its MIDI 140), MIDI↔audio chroma alignment,
  per-bar chroma correlation, octave-band dB per section, rms/peak. The MIDI vs the
  audio sets the ceiling of what "matching" can mean.
- Tuning/clash checks for arrangements: pyin f0 per mono stem (≈5 cents ok); power
  chord 5th only if in the half-bar harmony; never transpose notes to "darken" a
  recognizable song; never sustain noise channels under long notes (buzz = "audio
  destruction").
- Mixing: fit gains per INSTRUMENT GROUP (voices summed), bounded around musical base
  levels (per-voice fits give absurd gains). Keep a minimum for the lead. Don't chase
  the original's HPSS percussive ratio when it has crunch/distortion (buries the
  melody); instead a fixed drum push (×1.6 level, ×2 boss) + fixed kick/snare/cymbal
  split. User wants: balanced melody vs drums, energetic punchy drums (esp. boss).
- basic-pitch (polyphonic transcription) works from a separate venv (Python 3.11,
  `basic-pitch[onnx]`, setuptools<70): ~80 % melody / 77 % bass on Tentacle, octave
  errors common; vote notes across repeated bars. Without a score results were poor
  (user: "doesn't resemble") — prefer a MIDI.
- LOUDNESS: finish every track with `famicom.master(y, lufs)` (pyloudnorm; soft-knee
  limiter, ceiling 0.8 so the OGG encode stays < 1.0). The old `tanh(x·1.4)/1.4` capped
  peaks at 0.714 (~3 dB lost → "empty in game"). Targets: level −11, boss −10/−10.5 LUFS
  (originals ≈ −12); catalog `volume` 0.9 for boss tracks (default 0.7). In game the
  backing gets masked by the lead + SFX: keep lead ≈10-15 % of the energy, drums ≈40 %.
- "Calmer than the original" = timbre, not notes: compare spectral centroid, attacks/s,
  rms dynamics (p95/p20) and octave bands. tentacle_nes fix: 2A03 pulse layer on the
  melody (duty sweep 12.5→50 % + pitch drop on attack), brighter chord stabs, 16th
  shimmer arps in the scale section, stabs in the break, ghost 16th hats, bass not
  boosted (mud), mix EQ (−3.5 dB @180 Hz, +1.2 dB shelf @4.5 kHz) via `famicom.biquad`.
  MELODY PRIORITY: new layers must not mask the lead. `tentacle_nes.mix` caps every
  accompaniment/percussion stem at 45 % of the melody in 1-5 kHz, per section
  (`MAX_UNDER_MELODY`); check masking by band-limited stem ratios, not plain RMS.
- Boss vs level identity (melody_nes): boss = 148 BPM, lead on a clipped-sine N163 wave
  + thin pulse an octave up, organ with fast octave arp, harsh bass, INDUSTRIAL drums
  (short-mode 2A03 noise "metal" on offbeats and under snares, low tom on 1, crash every
  2 bars). Measured timbre distance to level_nes (MFCC): 14.9 → 55.
- Music tasks are verified by numbers only; always tell the user it wasn't listened to.
- TOOLS: `~/.venvs/fm-music` (Python 3.11, outside the repo): basic-pitch, demucs, librosa,
  pyloudnorm, mido, matplotlib. Finding wrong/missing MIDI notes vs the real recording (worked for
  winter): `python -m demucs -n htdemucs <ogg>` → the 'other' stem (melodic; 'vocals' was empty) →
  per-16th PITCH SALIENCE (`librosa.salience`, harmonics 1-4) vs a render of the chiptune's melodic
  stems only → (a) notes strong in the ogg and weak in ours, (b) per-bar pitch-class profile → best
  diatonic triad in each (shows wrong chords), (c) the top note per step (shows octave / harmony
  lines). basic-pitch on the full mix found few notes; images of CQTs were too busy to judge.
- Release: bump version.txt; audio-only changes need only `git pull` on the server
  (it republishes within 30 s); code/protocol changes need a server restart.

