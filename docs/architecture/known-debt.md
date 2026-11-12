# Known debt and open items (audit of 2026-10-07)

What the full-project audit found and did NOT fix, with a concrete way forward for each. Ordered by how much it
would help future work.

## Architecture

1. (Fixed in 0.5.185: the single-player and server step order — see the history below.)
2. **Large single-system files** that are long because the system is big, not tangled — left as they are:
   `snowboss.lua` (1841), `megacrabby.lua` (1613), `StoryMapState.lua` (~1300), `mirror.lua` (1095), `megagummy.lua`
   (1078), `OnlineHubState.lua` (~750).
3. **Two unrelated "difficulty" tables**: `DIFFICULTIES` in `settings.lua` (Flappy mode pacing) and
   `src/core/Difficulty.lua` (Adventure modifiers). Only the name is confusing.

## Naming that cannot change (ids are data) — see the glossary in docs/README.md

`miniboss1` = the Evil Ship; tile `danger` = lava; tile `solid` = stone; level key `foliage` = decorations; `snowboss`
(entity) vs `snowball_boss` (music); `EnemyTest.json` (the only CamelCase level file); levels `nivel01` and
`carrera01` (the two oldest levels, now story levels of the Caves and the Volcano).

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

## Fixed (history)

- 0.5.185 (the user: "unify them, it is the right thing"): ONE step order, `Sim.step` in `src/world/systems/Sim.lua`,
  used by `AdventureState` and `server/srv/sim.lua`; each passes hooks for what is only its own. The order is the
  server's (the one the network imposes): floods → solid bodies → players (each, after moving: air bubble, 1st
  interactions pass — online against what that player SAW —, goals) → carry → level update → entities → point zones →
  boss zones → auto-scroll → 2nd interactions pass. What changed for single player: the level update, point zones and
  the boss controller now run after the player and the entities; the player's interactions run twice per frame (right
  after moving and after the entities), the air bubble and the goal are checked right after moving. The server only
  moved into hooks (point zones now advance their clock even in a level without zones).

- 0.5.182 (optimisation / modularisation round): `Particles.lua`'s `elseif` chain is a table of kinds (`EMIT`); the
  scene layer order is one module for single player and online (`SceneLayers`); duplicated helpers moved to the base
  (`Entity:nearestPlayer`, `Entity:oneLight`, `NetList.read`). Details in [performance](../testing/performance.md).

- 0.5.175: `bossdrops` built its food / lives reserves with `pairs(...)` over a table, so server and clients could
  create the Extreme / Xtra reserves in a different order (online nondeterminism); placements now walk an ordered
  `ipairs(KINDS)` list.

## Failing tests

- `mechanics` `puffer_concave` (found 0.5.208): it depends on the random state the cases before it leave — run alone (`ONLY=puffer_concave`) it fails even on older commits, in the full harness it passes. A new case that uses `math.random` before it broke it; `accesibilidad` now runs last. Proper fix: seed the RNG inside the case.
- `run.sh bot_nav`, bonus arena `la_cima` (0.5.199): the bot now holds the point zone less (47-78 % vs ~72 %) and fails `cebo` / `dentro` on some seeds. Cause found: the Snowball fix (it sees a player above a step and climbs it) lets the arena's two Snowballs reach the bot on the steps and shove it out — their intended job. Pushes into the avalanche no longer count against the bot (`avPushed`). The user (2026-11-13): accepted as it is — leave the arena and the bot unchanged.

Fixed in 0.5.194 (the user asked to clear the old failures): `la_cima` (stale graph, rebuilt); `rush_arena` (a real bug: the Adventure Boss Rush included the Flappy stage `valle_redcoptero`, whose fight does not start alone; Flappy levels are out); `gloomy_rules` `parkour` (a real cost: `GloomyNav.path` took 75-100 ms per search; now about 22 ms mean, 30 ms worst, with a per-search memo, an early distance cut and `MAX_NODES` 350); `ciudadela_alterna` (the harness counted the bot's deliberate `Bot.SWITCH_CD` wait under an Activator as being stuck); `project_check` on the Mac (it no longer checks links into the git-ignored `tools/music/ref`).

## Product items still open

- The Switch "overlay" update mode has never been verified on a real console (`update/boot.log` tells the mode).

## Google Play readiness (input for the next task; nothing here is done)

| Topic | State today | What it will need |
|---|---|---|
| Package | `resources/android/overlay/gradle.properties`: `app.application_id=com.mati.flappymonster`, `app.version_code=1`, `app.version_name=0.4.0` hard-coded (must follow `version.txt`: 0.x in beta, 1.0.0 at release) | derive both from `version.txt` in `make android`; the application id is permanent once published — decide it first |
| Build | `make android` builds a DEBUG APK from the `love-android` submodule (11.5a) | a signed release **AAB**, an upload key kept outside the repo, a current `targetSdk` (Play raises the minimum every year), 64-bit native libs |
| Permissions | the manifest asks for INTERNET, VIBRATE and legacy WRITE_EXTERNAL_STORAGE (≤ SDK 18). BLUETOOTH and RECORD_AUDIO were removed on 2026-10-07 (user's decision) | `make android` already builds the `NoRecord` flavour of love-android (the `Record` flavour would add the microphone permission back from its own manifest) and confirm with `aapt dump permissions` on the built file |
| **In-game updater** | the game downloads its own Lua code and assets from the game server and restarts | **DECIDED by the user (2026-10-07): in the Play Store build the updater is limited to assets only, or disabled so Google Play handles updates.** To do with that build: a build flag read by `main.lua` / `UpdateState` (the `UPDATE_BLOCKED` path already skips updating); if assets-only, the server manifest must be filtered to `assets/` and code must stay compatible with newer assets |
| Online | plain ENet UDP to `SERVER_HOST`, a free-text player name, no accounts | a privacy policy URL, the Data-safety form (the name is user-generated content shown to others → needs the name filter finished, and ideally report / block), server location disclosure |
| Google Play Games Services (sign-in, achievements, leaderboards, cloud saves) | nothing; LÖVE has no built-in binding | a small Java / JNI bridge in the Android overlay + a Lua wrapper with a no-op fallback on PC / Switch. Natural hooks already exist: `src/story/Save.lua` (cloud save), `src/story/Run.lua` `complete` / `unlockAfter` / `addShard` (achievements), story points and Flappy best scores (leaderboards) |
| Store content | — | content rating questionnaire, store listing (the OST videos in `tools/video/` are ready-made material), screenshots at phone / tablet sizes (`story_flow` and `touch_layout` already capture them) |
| Music rights | the soundtrack is original compositions. The user's position (2026-10-07): under Peru's Copyright Law (Legislative Decree 822, arts. 5-6) a new, independent composition that uses only ideas or devices of another work, such as a leitmotif, is not a copy; no track is intended to copy a protected work. For reference, the places where another work is audible on purpose are listed in `docs/audio/music-history.md`: cells of "Tentacle Tantrum", the motif and gesture of "Winter Fallympics", the hook of "It's me, It's Verity" (quoted literally in `snowball_verity`), 8 bars of the old level tune in `mirror_boss` | nothing pending in code; if a store or rights holder ever objects, those are the bars to look at Since 3.105.0 the credits ([credits](../story/credits.md)) and `assets/legal/THIRD_PARTY_LICENSES.txt` name the quoted works and their authors; that is courtesy, not a licence. |
| Fonts / libs | Press Start 2P (OFL), baton / bitser / json / sock / lovesize (MIT-style), LÖVE (zlib) | list them in an in-game or store "licences" page |
| Screens | logical 720-high layout, letterboxed gameplay at 1280x720, touch controls in screen pixels | test edge-to-edge / cut-out insets and the Android back gesture (mapped to `back`) |
