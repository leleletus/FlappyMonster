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
  reason)` translates. Boss bar names: `boss.<type>`.
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
                    in Sound.load(), then Sound.play('name'). Folders: player/, enemies/,
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
                       crabbytramp (Crabby trampolín, subclass of crabby),
                       flood (editor-only placeholder for a Floods area),
                       bomb / bombobject (bombs, see Bombs), bossglass, bosswall
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
Spikes are images too: assets/images/spikes/spike.png (tile spikes, rotated/flipped
                       for the 4 directions; falling spike), crabby/spike.png and
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
- Trampolines: `solidFull` bodies with `bouncyFace`. The player's
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
  straight from the shell (`dropHidden`). A wall-walking one RELEASES the crawl when
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
  The `flyers` harness uses fixed random sequences: `SEED=n` tries others. Wings:
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
  v23: boss intro + Mega emotes; v24: subtiles, dirt/grass; v25: connected floods; v26: generic links `to`; v27: ON/OFF blocks; v28: generic boss intros; v29: Mirror arena attacks; v30: boss broken glass; v31: special enemy deaths; v32: bombs; v33: snow/ice/thin ice; v34: sand; v35: deep stone).
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
- **Ice drips** (`src/fx/IceDrips.lua`, render-only, per client): tiles with `iceDrip` and air
  below grow drops (`fx/ice_drop.png`) that fall and splash. **Snowfall** (`src/fx/Snowfall.lua`):
  level JSON `"snow": true` (editor Nivel → Clima → "Nieve cayendo"), 3 depth layers of
  `fx/snowflakes.png`, visual only. Decoration `icicle` (Carámbano, `decorations/ice/icicle.png`,
  hangs from the top of its cell). Test arena `tools/levelgen/arenas/hielo.json`.
- Harness: `tools/tests/run.sh mechanics` (also covers the Gummy helmet, the
  pufferfish and thin ice: `hielo_*`). Protocol v22 (ON/OFF + invisible blocks + helmet + pufferfish).

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

## Level themes (`tools/levelgen/retheme.py`)

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
- **Adding a boss**: `types/<name>.lua` with `Entity.extend(Boss, …)`, def fields
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
- **MegaCrabby** (`types/megacrabby.lua`, sprites `assets/images/MegaCrabby/`, sounds
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
Harnesses: flyers, crawler_drop, mechanics, sounds, boss_sim, sp_boss, boss_frames,
editor_open, free_play, update_boot, online_smoke, online_boss, online_helmet,
level_check, level_solve. `tools/` is not shipped (.love / updates).

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
  race+boss: ruta_del_espejo, fortaleza_malvada, guarida_cangrejo_rey). Each level
  whitelists its mode with `"modes"`. Ship = bump `version.txt`.
- Bots: send `in` only when there are new inputs, or the server kicks them
  for flooding.

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
- Release: bump version.txt; audio-only changes need only `git pull` on the server
  (it republishes within 30 s); code/protocol changes need a server restart.

