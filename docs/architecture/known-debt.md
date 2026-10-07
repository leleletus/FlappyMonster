# Known debt and open items (audit of 2026-10-07)

What the full-project audit found and did NOT fix, with a concrete way forward for each. Ordered by how much it
would help future work.

## Architecture

1. **`server/main.lua` (1687 lines) could not be split.** Its sections share 15 file-level locals that are
   reassigned from several places (`players`, the lazily loaded modules `Level / Entities / BossZones / …` set in
   `love.load`, the sound-stub state `_soundEvents / _currentSoundPlayerId / _emitX / _emitY`, `_currentSim`,
   `MSG_BURST`), and its banners do not match real seams (the "level catalog" section also holds `initRoomSim` and
   `pushEvent`). Way forward: first move that state into one table `S` (pure renaming, verifiable with the online
   harnesses), then split into server modules (catalog, lagcomp, sim, broadcast, lobby, console) with the same
   part pattern as the other files.
2. **The single-player loop and the server loop are two hand-kept copies of the same sequence**
   (`AdventureState:update` and `stepRoom` / `stepPlayer` / `checkPlayerEnemyCollisions`): player step → death /
   respawn (auto-scroll point, boss-zone point) → `Interactions.run` callbacks (pickup, checkpoint, score) →
   `level:update` → floods → entities (through `Difficulty.dt`, with the sound emitter set) → point zones → boss
   controller → queued tile changes. The RULES are shared (they live in `Interactions`, `PointAreas`, `BossZones`…)
   but the ORDER and the glue are duplicated, which is where "works offline, differs online" bugs come from. Way
   forward: one shared `Sim.step(sim, dt, hooks)` module under src/world used by both, the hooks being what differs
   (emit event vs play locally, lives bookkeeping).
3. **Large single-system files** that are long because the system is big, not tangled — left as they are:
   `snowboss.lua` (1841), `megacrabby.lua` (1613), `StoryMapState.lua` (1198), `mirror.lua` (1095), `megagummy.lua`
   (1078), `OnlineHubState.lua` (1033), `Particles.lua` (993, one long `elseif` chain per particle kind — a table of
   kinds would let a kind be added without touching the function).
4. **`Sound.load()` is one long list** of `load(...)` lines and a `GAIN` table: adding a sound means editing two
   places far apart. A data file (a sounds index next to the music one: name → file, gain, range) would make sounds a catalog
   like music.
5. **Two unrelated "difficulty" tables**: `DIFFICULTIES` in `settings.lua` (Flappy mode pacing) and
   `src/core/Difficulty.lua` (Adventure modifiers). Only the name is confusing.

## Naming that cannot change (ids are data) — see the glossary in docs/README.md

`miniboss1` = the Evil Ship; tile `danger` = lava; tile `solid` = stone; level key `foliage` = decorations; `snowboss`
(entity) vs `snowball_boss` (music); `EnemyTest.json` (the only CamelCase level file); levels `nivel01` and
`carrera01` (the two oldest levels, now story levels of the Caves and the Volcano).

## Small dead code left in place (public API nobody calls today)

`Sound.getEcho`, `Sound.getBaseLevelMusic`, `PlayerAdventure:blindLight` (documented as a hook for boss hits),
`Darkness.invalidate`, `NC:isBusy`, `View.isLocked`, `Level:isInWater`, `BombCore.isLit / isExploding`,
`Boss:inIntro`. Harmless; remove when touching those files.

## Generator intermediates that ship for no reason

`assets/images/bosses/snowboss/cracks-Sheet.png` and `assets/images/enemies/crabby_ice/hide-Sheet.png` are inputs /
by-products of generators, not loaded by the game (a few KB). Moving them out needs the generators to read them
from `FlappyMonster_originals`.

## Tools

- Art generators whose output is hand-edited were moved and re-pathed but not executed (see
  [art/generators](../art/generators.md)): treat their first run after 2026-10-07 with suspicion.
- `tools/music/tentacle_nes.py` and `gloomy_nes.py` are imported as libraries by every live generator but still
  carry their own retired `main`; extracting the shared helpers into a module was avoided because it could alter
  approved tracks and cannot be verified by ear here.
- `tools/levelgen/build.py` and `retheme.py` are dangerous by default (they act on EVERY level without arguments).
  A guard that refuses to run without explicit level names would remove the trap.

## Product items still open

- Profanity word list for player names: importing a public list (LDNOOBW, es / en, pruned) into
  `src/network/NameFilter.lua` was deferred.
- Xbox pads have A / B swapped relative to the game's Nintendo layout; there is no remapping option.
- The Switch "overlay" update mode has never been verified on a real console (`update/boot.log` tells the mode).
- Hoppers are placed in no story level except `huida_del_espejo`.

## Google Play readiness (input for the next task; nothing here is done)

| Topic | State today | What it will need |
|---|---|---|
| Package | `resources/android/overlay/gradle.properties`: `app.application_id=com.mati.flappymonster`, `app.version_code=1`, `app.version_name=1.0.0` hard-coded | derive both from `version.txt` in `make android`; the application id is permanent once published — decide it first |
| Build | `make android` builds a DEBUG APK from the `love-android` submodule (11.5a) | a signed release **AAB**, an upload key kept outside the repo, a current `targetSdk` (Play raises the minimum every year), 64-bit native libs |
| Permissions | the manifest asks for INTERNET, VIBRATE and legacy WRITE_EXTERNAL_STORAGE (≤ SDK 18). BLUETOOTH and RECORD_AUDIO were removed on 2026-10-07 (user's decision) | `make android` already builds the `NoRecord` flavour of love-android (the `Record` flavour would add the microphone permission back from its own manifest) and confirm with `aapt dump permissions` on the built file |
| **In-game updater** | the game downloads its own Lua code and assets from the game server and restarts | **DECIDED by the user (2026-10-07): in the Play Store build the updater is limited to assets only, or disabled so Google Play handles updates.** To do with that build: a build flag read by `main.lua` / `UpdateState` (the `UPDATE_BLOCKED` path already skips updating); if assets-only, the server manifest must be filtered to `assets/` and code must stay compatible with newer assets |
| Online | plain ENet UDP to `SERVER_HOST`, a free-text player name, no accounts | a privacy policy URL, the Data-safety form (the name is user-generated content shown to others → needs the name filter finished, and ideally report / block), server location disclosure |
| Google Play Games Services (sign-in, achievements, leaderboards, cloud saves) | nothing; LÖVE has no built-in binding | a small Java / JNI bridge in the Android overlay + a Lua wrapper with a no-op fallback on PC / Switch. Natural hooks already exist: `src/story/Save.lua` (cloud save), `src/story/Run.lua` `complete` / `unlockAfter` / `addShard` (achievements), story points and Flappy best scores (leaderboards) |
| Store content | — | content rating questionnaire, store listing (the OST videos in `tools/video/` are ready-made material), screenshots at phone / tablet sizes (`story_flow` and `touch_layout` already capture them) |
| Music rights | the soundtrack is original compositions. The user's position (2026-10-07): under Peru's Copyright Law (Legislative Decree 822, arts. 5-6) a new, independent composition that uses only ideas or devices of another work, such as a leitmotif, is not a copy; no track is intended to copy a protected work. For reference, the places where another work is audible on purpose are listed in `docs/audio/music-history.md`: cells of "Tentacle Tantrum", the motif and gesture of "Winter Fallympics", the hook of "It's me, It's Verity" (quoted literally in `snowball_verity`), 8 bars of the old level tune in `mirror_boss` | nothing pending in code; if a store or rights holder ever objects, those are the bars to look at |
| Fonts / libs | Press Start 2P (OFL), baton / bitser / json / sock / lovesize (MIT-style), LÖVE (zlib) | list them in an in-game or store "licences" page |
| Screens | logical 720-high layout, letterboxed gameplay at 1280x720, touch controls in screen pixels | test edge-to-edge / cut-out insets and the Android back gesture (mapped to `back`) |
