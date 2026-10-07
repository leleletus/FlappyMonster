# FlappyMonster — entry point for Claude

LÖVE 11.x game (Lua / LuaJIT). Two games in one: the original **Flappy** mode and **Adventure**, a platformer with a
story mode (6 islands, 7 bosses), a Free Play hub, a level editor and an online mode backed by an **authoritative
server**. Targets: PC, Nintendo Switch (homebrew), Android.

This file holds the RULES and the MAP. Everything about how a system works lives in **`docs/`** — start at
[`docs/README.md`](docs/README.md) (index by task + glossary). Do not grow this file with implementation detail: put
it in the system's page.

```
love .                                   the game
love . --editor [assets/levels/x.json]   the level editor (Spanish UI)
love server [--headless]                 the server (port 22122); run it from the repo root
tools/tests/run.sh all                   the test battery (must end "TODO OK")
```

## Communication (user preference, IMPORTANT)

Chat replies to the user: **ENGLISH, as short as possible** — results, numbers, what is left. Explain in detail only
when asked. The user writes in Spanish. This does not apply to code, comments, commits, docs or game text.

## Languages of the project

| What | Language |
|---|---|
| Code comments, commit messages | Spanish |
| Level editor UI, `tools/tests/README.md` | Spanish (with accents) |
| Player-facing text | translated, never hardcoded: add the key to BOTH `assets/lang/es.lua` and `en.lua` |
| `docs/`, this file | English |

## Golden rules

1. **Gameplay runs identically in 3 places**: single player (`AdventureState`), the server (`server/main.lua`) and
   the online client (`OnlineAdventureState`, which only predicts the local player and draws the rest from
   snapshots). Shared simulation code never touches `love.graphics`, the real `Input` or the real `Sound` outside
   render functions; everything a client draws must come from what travels in snapshots.
2. **Base behaviours live in the BASE and a type only switches them on** (traits, tables, hooks). Never copy another
   entity's code; if a rule is missing, add it to the base, generic.
3. **Catalogs are data**: a new tile / entity / decoration / mode / track / world / difficulty modifier / language is
   a file plus one name in a list. Ids are stored in levels, saves and network messages: **never rename an id or a
   level file**.
4. **Every image and sound is a real asset file**, never only drawn or synthesised in code. Generators are fine when
   their output is committed. Pixel art, integer positions, hard rectangles (see `docs/art/style-rules.md`).
5. **Never overwrite a sprite the user hand-edited** (list in `docs/art/generators.md`). Originals of redesigned
   images and `.aseprite` sources live OUTSIDE the repo in `/home/mtvemo/FlappyMonster_originals/` (mirrors
   `assets/images/`); previews for the user go to `/home/mtvemo/FlappyMonster_pruebas/<thing>/vista_previa.png`.
6. **The monster has NO wings** — it flaps by magic. Never draw or mention wings on it.
7. **Nothing gained in a level is saved until the level is finished** (lives picked up, shards, points). Any new
   thing a level can give must follow this.
8. **The update contract is frozen**: root files `main.lua`, `conf.lua`, `game.lua`, `input.lua`, `settings.lua`,
   `version.txt` and the roots `src/`, `libs/`, `assets/` keep their names; the `upd_*` messages keep their shape.
   Inside those roots files may move freely.
9. Never compute layout from `WINDOW_W/H` at file load time (the logical width changes with the screen); no
   stencils (Switch / Android); clip with `src/ui/Clip.lua`.
10. Don't commit the many ` M` files in `git status` that are mode-only changes: use `git -c core.fileMode=false`.

## Workflow rules

- **Tests: only through `tools/tests/run.sh`** (`tools/tests/README.md` lists every harness). Gameplay / core change
  → `run.sh all`. Visual-only → syntax check + the targeted capture. A test that needs something new → extend the
  harness and its README row; never build an ad-hoc setup.
  - After moving / renaming / deleting files: `run.sh project_check` (modules, catalogs, asset paths, language keys,
    doc paths and links).
  - After adding or changing a type, a level or a track: `run.sh docs_reference` (regenerates `docs/reference/`; the
    battery fails when it is stale).
- **Docs: when you change a system, update its page in `docs/` in the same commit.** New system → new page from the
  usual skeleton (what · files · data · SP / server / client · how to extend · tests · decisions) + a line in
  `docs/README.md`. Record the user's verdicts and rejected attempts in the page's history section: they are the
  most expensive knowledge to lose.
- **Network**: any incompatible change (own state, an entity's packed fields, a new entity type) → `Protocol.VERSION`
  + 1 and bump `version.txt`.
- **Release**: bump `version.txt` → commit → `git fetch` and check `git log HEAD..origin/master` → push to master
  (work on master; push finished work without asking) → **`tools/deploy_server.sh` after EVERY push** and report the
  version and commit it prints. The script holds no secret; never type, print, copy or commit the SSH passphrase or
  read `~/.ssh/id_rsa_pass`. Restarting the server drops online players.
- Commit messages in Spanish, ending with the `Co-Authored-By` line given by the session.
- **Level tools are dangerous by default**: `tools/levelgen/build.py` ONLY with `--only <level>` (without it, and
  with `--show`, it rewrites every level and destroys the user's hand edits); `tools/levelgen/retheme.py` ONLY with
  level names (any unknown flag runs it over every level).
- **Music is verified by numbers only**: always tell the user it was not listened to; run `tools/music/levels.py`
  after any track change. Composition rules: `docs/audio/music-guide.md`.
- Untracked user files in the repo root are theirs: never commit them.
- What cannot be judged without a person (feel, sound, looks, real devices) must be stated at every hand-off.

## Map

```
main.lua conf.lua     bootstrap + window (never auto-updated)
game.lua              client entry: globals, state registry, callbacks, --editor
settings.lua input.lua  global constants (+ tile catalog) · the global Input
libs/                 third-party (baton, bitser, class, json, lovesize, sock, timer)
server/               authoritative server (main.lua) + update publisher (updates.lua)
src/core/             BaseState, StateMachine, Lang, Settings, Difficulty, PlayRecorder
src/audio/            Sound, Music
src/player/           PlayerAdventure (+ Collision, Air, GroundPound, Render parts), OnlinePlayer, DeadEyes
src/flappy/           Flappy mode objects
src/network/          Protocol, NetworkClient, Predictor, SnapshotBuffer, Resolver, NameFilter
src/world/level/      Level (+ Tiles, Water, Render parts), LevelCatalog, SubTiles, SpikeSkins, Lights
src/world/systems/    AutoScroll, Floods, BossZones, PhaseBlocks, XtraBosses, PointAreas, Noise, Explosions
src/world/tiles/      tile + material catalog
src/world/entities/   Entities (registry) · base/ (Entity, Interactions, Crawler, Boss…) · types/<category>/
src/world/decorations/ · src/world/modes/
src/states/           menu/ flappy/ adventure/ online/ story/
src/story/            Worlds, Save, Run, Score, Shards, BonusMatch, Film, Stage, films/
src/ai/ src/fx/ src/ui/ src/editor/ src/update/
assets/               images/ sounds/ music/ levels/ nav/ lang/ story/ fonts/ shaders/   (docs/art/asset-layout.md)
tools/                art/ sounds/ music/ levelgen/ tests/ video/ deploy_server.sh        (tools/README.md)
docs/                 the documentation
```

Globals used everywhere: `Sound`, `Input`, `gStateMachine`, `TILE_PX` (64), `PLAYER_SCALE` (6), `GUMMY_SCALE` (4),
`ADV_GRAVITY`, `ADV_JUMP_VEL`, `ADV_MOVE_SPD`, `WINDOW_W/H`, `FONT_SMALL/MED/BIG`, `DEBUG_HITBOX`, `TILE_<NAME>`.

Large files are split into parts that add methods to the same table (`Level`, `PlayerAdventure`,
`OnlineAdventureState`, `Editor`): the pattern and its rules are in `docs/architecture/project-structure.md`.

## Where the documentation is

| Topic | Page |
|---|---|
| Index by task, glossary of ids | `docs/README.md` |
| How it all fits, boot, states, globals, catalogs | `docs/architecture/overview.md`, `project-structure.md` |
| Online: server, protocol, prediction, version history | `docs/architecture/netcode.md` |
| Auto-updates, release, deploy | `docs/architecture/updates-and-release.md` |
| Screens, scaling, touch, Switch / Android | `docs/architecture/platforms.md` |
| Languages | `docs/architecture/i18n.md` |
| What is saved | `docs/architecture/save-data.md` |
| Audit findings, open items, **Google Play readiness** | `docs/architecture/known-debt.md` |
| Player | `docs/gameplay/player.md` |
| Tiles, terrain, special blocks, subtiles | `docs/gameplay/tiles-and-blocks.md` |
| Water, air, floods | `docs/gameplay/water-and-floods.md` |
| Dark levels, flashlight, noise, light moods, echo | `docs/gameplay/dark-levels.md` |
| Difficulty modifiers | `docs/gameplay/difficulty.md` |
| Online modes, King of the Hill, point zones | `docs/gameplay/game-modes.md` |
| Auto-scroll, spike rain | `docs/gameplay/autoscroll.md` |
| Pickups, food | `docs/gameplay/pickups.md` |
| Free Play · Flappy mode | `docs/gameplay/free-play.md` · `flappy-mode.md` |
| Entity base system · enemies · traps and mechanisms | `docs/entities/overview.md` · `enemies.md` · `traps-and-mechanisms.md` |
| **How to add an enemy / a boss** | `docs/entities/how-to-add-an-enemy.md` · `docs/bosses/how-to-add-a-boss.md` |
| Boss system + one page per boss | `docs/bosses/system.md`, `docs/bosses/<boss>.md` |
| Story (lore, films scene by scene) | `docs/story/story.md` |
| Story mode, world map, cinematics, bonus + bot | `docs/story/story-mode.md`, `world-map.md`, `cinematics.md`, `bonus-and-bot.md` |
| Level JSON, editor, generator + solver, retheme | `docs/levels/` |
| Art rules, asset layout, generators + **hand-edited list**, sky, decorations, particles | `docs/art/` |
| Sound, music catalog, composition guide, music history | `docs/audio/` |
| Testing | `docs/testing/harnesses.md`, `tools/tests/README.md` |
| Generated tables: entities, tiles, decorations + modes, levels, music | `docs/reference/` |
| Tools | `tools/README.md`, `docs/tools/ost-videos.md` |
